/*-
 * Copyright (c) 2013-2014 Audience Developers (http://launchpad.net/pantheon-chat)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Tom Beckmann <tomjonabc@gmail.com>
 *              Cody Garver <cody@elementaryos.org>
 *              Artem Anufrij <artem.anufrij@live.de>
 */

/*
[CCode (cname="gst_navigation_query_parse_commands_length")]
public extern bool gst_navigation_query_parse_commands_length (Gst.Query q, out uint n);
[CCode (cname="gst_navigation_query_parse_commands_nth")]
public extern bool gst_navigation_query_parse_commands_nth (Gst.Query q, uint n, out Gst.NavigationCommand cmd);
*/
namespace Audience {

    public enum Page {
        WELCOME,
        PLAYER
    }

    public Audience.Settings settings; //global space for easier access...

    public class App : Granite.Application {

        /**
         * Translatable launcher (.desktop) strings to be added to template (.pot) file.
         * These strings should reflect any changes in these launcher keys in .desktop file
         */
        /// TRANSLATORS: This is the name of the application shown in the application launcher. Some distributors (e.g. elementary OS) choose to display it instead of the brand name "Audience".
        public const string VIDEOS = N_("Videos");
        /// TRANSLATORS: These are the keywords used when searching for this application in an application store or launcher.
        public const string KEYWORDS = N_("Audience;Video;Player;Movies;");
        public const string COMMENT = N_("Watch videos and movies");
        public const string GENERIC_NAME = N_("Video Player");
        /// TRANSLATORS: This is the shortcut used to view information about the application itself when its displayed name is branded "Audience".
        public const string ABOUT_STOCK = N_("About Audience");
        /// TRANSLATORS: This is the shortcut used to view information about the application itself when its displayed name is the localized equivalent of "Videos".
        public const string ABOUT_GENERIC = N_("About Videos");
	public const string ABOUT_TRANSLATORS = N_("translator-credits");
	
        construct {
            program_name = "Audience";
            exec_name = "audience";

            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;

            app_years = "2011-2015";
            app_icon = "multimedia-video-player";
            app_launcher = "audience.desktop";
            application_id = "net.launchpad.audience";

            main_url = "https://code.launchpad.net/audience";
            bug_url = "https://bugs.launchpad.net/audience";
            help_url = "https://elementary.io/help/audience";
            translate_url = "https://translations.launchpad.net/audience";

            about_authors = { "Cody Garver <cody@elementaryos.org>",
                              "Tom Beckmann <tom@elementaryos.org>" };
            /*about_documenters = {""};
            about_artists = {""};
            about_translators = Constants.ABOUT_TRANSLATORS;
            about_comments = "To be determined"; */
            about_license_type = Gtk.License.GPL_3_0;
        }

        private ZeitgeistManager    zeitgeist_manager;
        private Gtk.HeaderBar       header;

        public Gtk.Window           mainwindow;

        private Page _page;
        public Page page {
            get {
                return _page;
            }
            set {
                switch (value) {
                    case Page.PLAYER:
                        if (page == Page.PLAYER)
                            break;

                        if (mainwindow.get_child()!=null)
                            mainwindow.get_child().destroy ();

                        var new_widget = new PlayerPage ();
                        new_widget.ended.connect (on_player_ended);
                        mainwindow.add (new_widget);
                        mainwindow.show_all ();

                        _page = Page.PLAYER;
                        break;
                    case Page.WELCOME:
                        var pl = mainwindow.get_child () as PlayerPage;
                        if (pl!=null) {
                            pl.ended.disconnect (on_player_ended);
                            pl.destroy ();
                        }

                        var new_widget = new WelcomePage ();
                        mainwindow.add (new_widget);
                        mainwindow.show_all ();

                        _page = Page.WELCOME;
                        break;
                }
            }
        }

        private static App app; // global App instance
        public DiskManager disk_manager;

        public GLib.VolumeMonitor monitor;

        public signal void media_volumes_changed ();

        public App () {

            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;

            zeitgeist_manager = new ZeitgeistManager ();
        }

        public static App get_instance () {
            if (app == null)
                app = new App ();
            return app;
        }

        void build () {
            settings = new Settings ();
            if (is_privacy_mode_enabled ()) {
                clear_video_settings ();
            }

            mainwindow = new Gtk.Window ();

            if (settings.last_folder == "-1")
                settings.last_folder = Environment.get_home_dir ();

            header = new Gtk.HeaderBar ();
            header.set_show_close_button (true);
            header.get_style_context ().add_class ("compact");

            disk_manager = DiskManager.get_default ();

            disk_manager.volume_found.connect ((vol) => {
                media_volumes_changed ();
            });

            disk_manager.volume_removed.connect ((vol) => {
                media_volumes_changed ();
            });

            page = Page.WELCOME;

            mainwindow.set_application (this);
            mainwindow.set_titlebar (header);
            mainwindow.window_position = Gtk.WindowPosition.CENTER;
            mainwindow.gravity = Gdk.Gravity.CENTER;
            mainwindow.show_all ();
            if (!settings.show_window_decoration)
                mainwindow.decorated = false;
            set_window_title (program_name);

            mainwindow.key_press_event.connect (on_key_press_event);

            mainwindow.destroy.connect (() => {
                if (is_privacy_mode_enabled ()) {
                    clear_video_settings ();
                }
            });

            setup_drag_n_drop ();
        }

        public bool has_media_volumes () {
            return disk_manager.has_media_volumes ();
        }

        private async void read_first_disk () {
            if (disk_manager.get_volumes ().length () <= 0)
                return;
            var volume = disk_manager.get_volumes ().nth_data (0);
            if (volume.can_mount () == true && volume.get_mount ().can_unmount () == false) {
                try {
                    yield volume.mount (MountMountFlags.NONE, null);
                } catch (Error e) {
                    critical (e.message);
                }
            }

            page = Page.PLAYER;
            var root = volume.get_mount ().get_default_location ();
            play_file (root.get_uri (), true);
        }

        public void set_content_size (double width, double height, double content_height){
            var geom = Gdk.Geometry ();

            if (width == 0
                && height == 0
                && content_height == 0) {
                geom.min_aspect = geom.max_aspect = 0;
            } else {
                double width_offset = mainwindow.get_allocated_width () - width;
                double height_offset = mainwindow.get_allocated_height () - content_height;

                debug ("Width: %f, Height: %f, Offset: %f )\n", width, height, content_height);

                geom.min_aspect = geom.max_aspect = (width + width_offset) / (height + height_offset);
            }

            mainwindow.set_geometry_hints (mainwindow, geom, Gdk.WindowHints.ASPECT);
        }

        private void on_player_ended () {
            page = Page.WELCOME;
        }

        public bool on_key_press_event (Gdk.EventKey e) {
            switch (e.keyval) {
                case Gdk.Key.o:
                    App.get_instance ().run_open_file ();
                    break;
                case Gdk.Key.q:
                    App.get_instance ().mainwindow.destroy ();
                    break;
                default:
                    break;
            }
            return false;
        }

        private inline void clear_video_settings () {
            settings.last_stopped = 0;
            settings.last_played_videos = null;
            settings.current_video = "";
            settings.last_folder = "";
        }

        public void run_open_file () {
            var file = new Gtk.FileChooserDialog (_("Open"), mainwindow, Gtk.FileChooserAction.OPEN,
                _("_Cancel"), Gtk.ResponseType.CANCEL, _("_Open"), Gtk.ResponseType.ACCEPT);
            file.set_transient_for (mainwindow);
            file.select_multiple = true;

            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.set_filter_name (_("All files"));
            all_files_filter.add_pattern ("*");

            var video_filter = new Gtk.FileFilter ();
            video_filter.set_filter_name (_("Video files"));
            video_filter.add_mime_type ("video/*");

            file.add_filter (video_filter);
            file.add_filter (all_files_filter);

            file.set_current_folder (settings.last_folder);
            if (file.run () == Gtk.ResponseType.ACCEPT) {
                if (page == Page.WELCOME)
                    clear_video_settings ();

                File[] files = {};
                foreach (File item in file.get_files ()) {
                    files += item;
                }

                open (files, "");
                settings.last_folder = file.get_current_folder ();
            }

            file.destroy ();
        }

        public void run_open_dvd () {
            read_first_disk.begin ();
        }

        /*DnD*/
        private void setup_drag_n_drop () {
            Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (mainwindow, Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.MOVE);
            mainwindow.drag_data_received.connect ( (ctx, x, y, sel, info, time) => {
                page = Page.PLAYER;
                File[] files = {};
                foreach (var uri in sel.get_uris ()) {
                    var file = File.new_for_uri (uri);
                    files += file;
                }
                open (files,"");
            });
        }

        public void resume_last_videos () {
            page = Page.PLAYER;

            var player = mainwindow.get_child () as PlayerPage;
            player.resume_last_videos ();
        }

        public void set_window_title (string title) {
            mainwindow.title = title;
        }

        /*
           make sure we are in player page and play file
        */
        internal void play_file (string uri, bool dont_modify = false) {
            if (page != Page.PLAYER)
                page = Page.PLAYER;

            PlayerPage player_page = mainwindow.get_child() as PlayerPage;
            player_page.play_file (uri);

        }

        public override void activate () {
            if (mainwindow == null) {
                build ();
            }
        }

        //the application was requested to open some files
        public override void open (File[] files, string hint) {
            if (mainwindow == null)
                build ();

            if (page != Page.PLAYER)
                clear_video_settings ();

            page = Page.PLAYER;
            var player_page = (mainwindow.get_child () as PlayerPage);
            string[] videos = {};
            foreach (var file in files) {

                if (file.query_file_type (0) == FileType.DIRECTORY) {
                    Audience.recurse_over_dir (file, (file_ret) => {
                        player_page.append_to_playlist (file);
                        videos += file_ret.get_uri ();
                    });
                } else if (player_page.video_player.playing &&
                        PlayerPage.is_subtitle (file.get_uri ())) {
                    message ("is subtitle");
                    player_page.video_player.set_subtitle_uri (file.get_uri ());
                } else {
                    player_page.append_to_playlist (file);
                    videos += file.get_uri ();
                }
            }

            if (videos.length == 0)
                return;

            // notification when adding video to playlist
            if (!player_page.video_player.playing // we are paused
                && (mainwindow.get_window ().get_state () & Gdk.WindowState.FOCUSED) == 0) {
                if (videos.length == 1)
                    show_notification (_("Video added to playlist"), get_title (videos[0]));
                else
                    show_notification (_("%i videos added to playlist").printf (videos.length), "");
            }

            play_file (videos [0]);


        }

        internal bool is_privacy_mode_enabled () {
            var privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");
            bool privacy_mode = !privacy_settings.get_boolean ("remember-recent-files") || !privacy_settings.get_boolean ("remember-app-usage");

            if (privacy_mode) {
                return true;
            }

            return zeitgeist_manager.app_into_blacklist (exec_name);
        }

    }
}

public static void main (string [] args) {
    X.init_threads ();

    var err = GtkClutter.init (ref args);
    if (err != Clutter.InitError.SUCCESS) {
        error ("Could not initalize clutter! "+err.to_string ());
    }

    Gst.init (ref args);

    var app = Audience.App.get_instance ();

    app.run (args);
}
