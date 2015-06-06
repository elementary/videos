// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
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

        construct {
            program_name = "Audience";
            exec_name = "audience";

            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;

            app_years = "2011-2015";
            app_icon = "audience";
            app_launcher = "audience.desktop";
            application_id = "net.launchpad.audience";

            main_url = "https://code.launchpad.net/audience";
            bug_url = "https://bugs.launchpad.net/audience";
            help_url = "https://code.launchpad.net/audience";
            translate_url = "https://translations.launchpad.net/audience";

            about_authors = { "Cody Garver <cody@elementaryos.org>",
                              "Tom Beckmann <tom@elementaryos.org>" };
            /*about_documenters = {""};
            about_artists = {""};
            about_translators = "Launchpad Translators";
            about_comments = "To be determined"; */
            about_license_type = Gtk.License.GPL_3_0;
        }

        public Gtk.Window     mainwindow;
        private Gtk.HeaderBar header;

        public bool fullscreened { get; set; }
        private Page _page;
        public Page page {
            get {
                return _page;
            }
            set {
                switch (value) {
                    case Page.PLAYER:
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
        public static Widgets.Playlist playlist;

        private static App app; // global App instance
        private DiskManager disk_manager;
        public bool has_media_volumes () {
            //FIXME:why we cant resume with this?
            /* return disk_manager.has_media_volumes (); */
            return true;
        }

        public GLib.VolumeMonitor monitor;

        public signal void media_volumes_changed ();

        public App () {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;

            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;

        }

        public static App get_instance () {
            if (app == null)
                app = new App ();
            return app;
        }

        void build () {
            settings = new Settings ();
            mainwindow = new Gtk.Window ();

            if (settings.last_folder == "-1")
                settings.last_folder = Environment.get_home_dir ();

            header = new Gtk.HeaderBar ();
            header.set_show_close_button (true);
            header.get_style_context ().remove_class ("header-bar");

            disk_manager = DiskManager.get_default ();

            disk_manager.volume_found.connect ((vol) => {
                media_volumes_changed ();
            });

            disk_manager.volume_removed.connect ((vol) => {
                media_volumes_changed ();
            });

            page = Page.WELCOME;

            mainwindow.set_titlebar (header);

            mainwindow.events |= Gdk.EventMask.POINTER_MOTION_MASK;
            mainwindow.events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
            mainwindow.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
            mainwindow.window_position = Gtk.WindowPosition.CENTER;
            mainwindow.set_application (this);
            mainwindow.title = program_name;
            mainwindow.show_all ();
            if (!settings.show_window_decoration)
                mainwindow.decorated = false;

                        //fullscreen on maximize
            mainwindow.window_state_event.connect ((e) => {
                on_window_state_changed (e.window.get_state ());
                return false;
            });

            mainwindow.size_allocate.connect (on_size_allocate);
            mainwindow.key_press_event.connect (on_key_press_event);

            playlist = new Widgets.Playlist ();

            setup_drag_n_drop ();

            //save position in video when not finished playing
            mainwindow.destroy.connect (() => {on_destroy ();});
        }

        public void run_open_dvd () {
            read_first_disk.begin ();
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
            open_file (root.get_uri (), true);
            /* player_page.video_player.playing = !settings.playback_wait; */

        }

        public void on_configure_window (uint video_w, uint video_h) {
            Gdk.Rectangle monitor;
            var screen = Gdk.Screen.get_default ();
            screen.get_monitor_geometry (screen.get_monitor_at_window (mainwindow.get_window ()), out monitor);

            int width = 0, height = 0;
            if (monitor.width > video_w && monitor.height > video_h) {
                width = (int)video_w;
                height = (int)video_h;
            } else {
                width = (int)(monitor.width * 0.9);
                height = (int)((double)video_h / video_w * width);
            }

            mainwindow.get_window ().move_resize (monitor.width / 2 - width / 2 + monitor.x,
                monitor.height / 2 - height / 2 + monitor.y,
                width, height);
        }

        uint update_aspect_ratio_timeout = 0;
        bool update_aspect_ratio_locked = false;
        int prev_width = 0;
        int prev_height = 0;
        /**
         * Updates the window's aspect ratio locking if enabled.
         * Return type is just there to make it compatible with Idle.add()
         */
        private bool update_aspect_ratio ()
        {
            if (page != Page.PLAYER)
                return false;
            var player_page = mainwindow.get_child () as PlayerPage;
            if (!settings.keep_aspect || player_page.video_player.video_width < 1 || player_page.video_player.height < 1
                || !player_page.clutter.visible)
                return false;

            if (update_aspect_ratio_timeout != 0)
                Source.remove (update_aspect_ratio_timeout);

            update_aspect_ratio_timeout = Timeout.add (200, () => {
                Gtk.Allocation a;
                player_page.clutter.get_allocation (out a);
                print ("%i %i %i,%i\n", a.x, a.y, (mainwindow.get_allocated_width () - player_page.clutter.get_allocated_width ()) / 2, (mainwindow.get_allocated_height () - player_page.clutter.get_allocated_height ()) / 2);
                double width = player_page.clutter.get_allocated_width ();
                double height = width * player_page.video_player.video_height / (double) player_page.video_player.video_width;
                double width_offset = mainwindow.get_allocated_width () - width;
                double height_offset = mainwindow.get_allocated_height () - player_page.clutter.get_allocated_height ();

                print ("Width: %f, Height: %f, Offset: %f (%f, %f)\n", width, height, height_offset, player_page.video_player.video_width, player_page.video_player.video_height);

                var geom = Gdk.Geometry ();
                geom.min_aspect = geom.max_aspect = (width + width_offset) / (height + height_offset);

                var w = mainwindow.get_allocated_width ();
                var h = (int) (w * geom.max_aspect);
                int b, c;

                mainwindow.get_window ().set_geometry_hints (geom, Gdk.WindowHints.ASPECT);

                mainwindow.get_window ().constrain_size (geom, Gdk.WindowHints.ASPECT, w, h, out b, out c);
                print ("Result: %i %i == %i %i\n", w, h, b, c);
                mainwindow.get_window ().resize (b, c);

                update_aspect_ratio_timeout = 0;

                Idle.add (() => {
                    prev_width = mainwindow.get_allocated_width ();
                    prev_height = mainwindow.get_allocated_height ();

                    return false;
                });

                return false;
            });

            return false;
        }

        private void on_window_state_changed (Gdk.WindowState window_state) {
            bool currently_maximized = (window_state & Gdk.WindowState.MAXIMIZED) == 0;

            if (!currently_maximized && !fullscreened && page == Page.PLAYER) {
                mainwindow.fullscreen ();
                fullscreened = true;
            }
        }

        /*DnD*/
        private void setup_drag_n_drop () {
            Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (mainwindow, Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.MOVE);
            mainwindow.drag_data_received.connect ( (ctx, x, y, sel, info, time) => {
                foreach (var uri in sel.get_uris ()) {
                    open_file (uri);
                }

                page = Page.PLAYER;
            });
        }

        private void on_destroy () {
            /* if (video_player.uri.has_prefix ("dvd://")) { */
            /*     clear_video_settings (); */
            /*     return; */
            /* } */
            /*  */
            /* if (video_player.uri == null || video_player.uri == "") */
            /*     return; */
            /*  */
            save_last_played_videos ();
        }

        private int old_h = - 1;
        private int old_w = - 1;
        private void on_size_allocate (Gtk.Allocation alloc) {
            if (page != Page.PLAYER)
                return;
            var player_page = mainwindow.get_child() as PlayerPage;
            if (alloc.width != old_w || alloc.height != old_h) {
                if (player_page.video_player.relayout ()) {
                    old_w = alloc.width;
                    old_h = alloc.height;
                }
            }

            if (prev_width != mainwindow.get_allocated_width () && prev_height != mainwindow.get_allocated_height ())
                Idle.add (update_aspect_ratio);
        }

        private void on_player_ended () {
            message ("player ended");
            page = Page.WELCOME;
        }

        private inline void save_last_played_videos () {
            /* playlist.save_playlist_config (); */
            /*  */
            /* debug ("saving settings for: %s", playlist.get_first_item ().get_uri ()); */
            /*  */
            /* if (settings.current_video != "" && !video_player.at_end) */
            /*     settings.last_stopped = video_player.progress; */
            /* else if (settings.current_video != "" && video_player.at_end) { */
            /*     settings.current_video = playlist.get_first_item ().get_uri (); */
            /*     settings.last_stopped = 0; */
            /* } */
        }

        private inline void clear_video_settings () {
            settings.last_stopped = 0;
            settings.last_played_videos = null;
            settings.current_video = "";
        }


        public void run_open_file () {
            var file = new Gtk.FileChooserDialog (_("Open"), mainwindow, Gtk.FileChooserAction.OPEN,
                _("_Cancel"), Gtk.ResponseType.CANCEL, _("_Open"), Gtk.ResponseType.ACCEPT);
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
            /*     if (welcome_page.is_visible ()) { */
            /*         playlist.clear_items (); */
            /*     } */
            /*  */
                    message ("item.");
                File[] files = {};
                foreach (File item in file.get_files ()) {
                    files += item;
                    message ("item."+item.get_uri ());
                    /* player_page.playlist.add_item (item); */
                }
                open (files, "");
            /*  */
            /*     if (video_player.uri == null || welcome_page.is_visible ()) */
            /*         open_file (file.get_uri ()); */
            /*  */
            /*     welcome_page.hide (); */
            /*     clutter.show_all (); */
            /*  */
                /* settings.last_folder = file.get_current_folder (); */
            }

            file.destroy ();
        }

        public void resume_last_videos () {
            page = Page.PLAYER;

            var player = mainwindow.get_child () as PlayerPage;
            player.resume_last_videos ();
        }

        public void toggle_fullscreen () {
            if (fullscreened) {
                mainwindow.unmaximize ();
                mainwindow.unfullscreen ();
                fullscreened = false;
            } else {
                mainwindow.fullscreen ();
                fullscreened = true;
            }
        }

        internal void open_file (string filename, bool dont_modify = false) {
            var file = File.new_for_commandline_arg (filename);

            var player_page = mainwindow.get_child() as PlayerPage;
            if (file.query_file_type (0) == FileType.DIRECTORY) {
                Audience.recurse_over_dir (file, (file_ret) => {
                    playlist.add_item (file_ret);
                });

                file = playlist.get_first_item ();
                player_page.play_file (file.get_uri ());
            }
            //TODO:move to PlayerPage
            /* else if (is_subtitle (filename) && video_player.playing) {
                player_page.video_player.set_subtitle_uri (filename);
            }*/ else {
                playlist.add_item (file);
                player_page.play_file (file.get_uri ());
            }
        }
        public override void activate () {
            build ();
            if (settings.resume_videos == true
                && settings.last_played_videos.length > 0
                && settings.current_video != ""
                && file_exists (settings.current_video)) {
                /* restore_playlist (); */

                if (settings.last_stopped > 0) {
                    /* welcome_page.hide (); */
                    /* clutter.show_all (); */
                    open_file (settings.current_video);
                    /* video_player.playing = false; */
                    /* Idle.add (() => {video_player.progress = settings.last_stopped; return false;}); */
                    /* video_player.playing = !settings.playback_wait; */
                }
            }
        }

        //the application was requested to open some files
        public override void open (File[] files, string hint) {
            if (mainwindow == null)
                build ();

            page = Page.PLAYER;

            var player = (mainwindow.get_child () as PlayerPage);
            if (player == null)
                message ("player null");
            foreach (var file in files) {
                message (file.get_uri ());
                playlist.add_item (file);
            }
            player.play_file (files[0].get_uri ());

            //TODO:enable notification
            /* if (video_player.uri != null) { // we already play some file */
            /*     if (files.length == 1) */
            /*         show_notification (_("Video added to playlist"), files[0].get_basename ()); */
            /*     else */
            /*         show_notification (_("%i videos added to playlist").printf (files.length), ""); */
            /* } else */
            /*     open_file(files[0].get_uri ()); */
        }

        public bool on_key_press_event (Gdk.EventKey e) {
            switch (e.keyval) {
                case Gdk.Key.Escape:
                    App.get_instance ().mainwindow.destroy ();
                    break;
                case Gdk.Key.o:
                    App.get_instance ().run_open_file ();
                    break;
                case Gdk.Key.f:
                case Gdk.Key.F11:
                    App.get_instance ().toggle_fullscreen ();
                    break;
                case Gdk.Key.q:
                    App.get_instance ().mainwindow.destroy ();
                    break;
                default:
                    break;
            }
            return false;
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
