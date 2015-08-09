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

        public bool repeat { get; set; }

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
            help_url = "https://answers.launchpad.net/audience";
            translate_url = "https://translations.launchpad.net/audience";

            about_authors = { "Cody Garver <cody@elementaryos.org>",
                              "Tom Beckmann <tom@elementaryos.org>" };
            /*about_documenters = {""};
            about_artists = {""};
            about_translators = "Launchpad Translators";
            about_comments = "To be determined"; */
            about_license_type = Gtk.License.GPL_3_0;
        }

        public Gtk.Window                 mainwindow;
        public GnomeMediaKeys             mediakeys;
        public Audience.Widgets.Playlist  playlist;
        public GtkClutter.Embed           clutter;
        public Granite.Widgets.Welcome    welcome;

        public bool fullscreened { get; set; }

        private static App app; // global App instance
        private Audience.Widgets.VideoPlayer video_player;
        private Audience.Widgets.BottomBar bottom_bar;
        private Gtk.HeaderBar header;
        private Clutter.Stage stage;
        private Gtk.Revealer unfullscreen_bar;
        private GtkClutter.Actor bottom_actor;
        private GtkClutter.Actor unfullscreen_actor;
        private bool mouse_primary_down = false;
        private int bottom_bar_size = 0;

        public GLib.VolumeMonitor monitor;

        private  const string[] SUBTITLE_EXTENSIONS = {
            "sub",
            "srt",
            "smi",
            "ssa",
            "ass",
            "asc"
        };

        public App () {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;

            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;

            repeat = false;
        }

        public static App get_instance () {
            if (app == null)
                app = new App ();
            return app;
        }

        void build () {
            playlist = new Widgets.Playlist ();
            settings = new Settings ();
            mainwindow = new Gtk.Window ();
            video_player = Widgets.VideoPlayer.get_default ();
            video_player.notify["playing"].connect (() => {bottom_bar.toggle_play_pause ();});

            clutter = new GtkClutter.Embed ();

            if (settings.last_folder == "-1")
                settings.last_folder = Environment.get_home_dir ();

            stage = (Clutter.Stage)clutter.get_stage ();
            stage.background_color = {0, 0, 0, 0};
            stage.use_alpha = true;

            video_player.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            video_player.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));

            stage.add_child (video_player);

            bottom_bar = new Widgets.BottomBar ();
            bottom_bar.set_valign (Gtk.Align.END);
            bottom_bar.play_toggled.connect (() => { video_player.playing = !video_player.playing; });
            bottom_bar.seeked.connect ((val) => { video_player.progress = val; });
            bottom_bar.unfullscreen.connect (() => { toggle_fullscreen (); });

            //tagview.select_external_subtitle.connect (video_player.set_subtitle_uri);

            unfullscreen_bar = bottom_bar.get_unfullscreen_button ();

            bottom_actor = new GtkClutter.Actor.with_contents (bottom_bar);
            bottom_actor.opacity = GLOBAL_OPACITY;
            stage.add_child (bottom_actor);

            unfullscreen_actor = new GtkClutter.Actor.with_contents (unfullscreen_bar);
            unfullscreen_actor.opacity = GLOBAL_OPACITY;
            stage.add_child (unfullscreen_actor);

            setup_welcome_screen ();

            var mainbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            mainbox.pack_start (clutter);
            mainbox.pack_start (welcome);

            header = new Gtk.HeaderBar ();
            header.set_show_close_button (true);
            header.get_style_context ().remove_class ("header-bar");

            mainwindow.set_titlebar (header);

            mainwindow.events |= Gdk.EventMask.POINTER_MOTION_MASK;
            mainwindow.events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
            mainwindow.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
            mainwindow.title = program_name;
            mainwindow.window_position = Gtk.WindowPosition.CENTER;
            mainwindow.set_application (this);
            mainwindow.add (mainbox);
            mainwindow.set_default_size (960, 640);
            mainwindow.set_size_request (350, 300);
            mainwindow.show_all ();
            if (!settings.show_window_decoration)
                mainwindow.decorated = false;

            clutter.hide ();

            //media keys
            try {
                mediakeys = Bus.get_proxy_sync (BusType.SESSION,
                    "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                mediakeys.MediaPlayerKeyPressed.connect ((bus, app, key) => {
                    if (app != "audience")
                       return;
                    switch (key) {
                        case "Previous":
                            playlist.previous ();
                            break;
                        case "Next":
                            playlist.next ();
                            break;
                        case "Play":
                            video_player.playing = !video_player.playing;
                            break;
                        default:
                            break;
                    }
                });

                mediakeys.GrabMediaPlayerKeys("audience", 0);
            } catch (Error e) {
                warning (e.message);
            }

            /*events*/
            video_player.text_tags_changed.connect (bottom_bar.preferences_popover.setup_text);
            video_player.audio_tags_changed.connect (bottom_bar.preferences_popover.setup_audio);
            video_player.progression_changed.connect ((current_time, total_time) => {
                bottom_bar.set_progression_time (current_time, total_time);
            });

            //end
            video_player.ended.connect (() => {
                Idle.add (() => {
                    int last_played_index = playlist.get_current ();
                    if (!playlist.next ()) {

                        if (repeat) {
                            open_file (playlist.get_first_item ().get_path ());
                            Idle.add (() => { video_player.progress = 0; return false; });
                            video_player.playing = true;
                        } else {
                            var button = welcome.get_button_from_index (2);
                            welcome.set_item_visible (1, false);
                            welcome.set_item_visible (2, true);
                            if (last_played_index > 0) {
                                button.description = _("Replay last playlist");
                            } else {
                                button.description = _("Replay '%s'").printf (get_title (playlist.get_first_item ().get_basename ()));
                            }

                            welcome.show_all ();
                            clutter.hide ();
                        }
                    }
                    return false;
                });
            });

            video_player.error.connect (() => {
                welcome.show_all ();
                clutter.hide ();
            });

            video_player.plugin_install_done.connect (() => {
                clutter.show ();
                welcome.hide ();
            });

            video_player.notify["playing"].connect (() => {
                mainwindow.set_keep_above (video_player.playing && settings.stay_on_top);
            });

            notify["fullscreened"].connect (() => {bottom_bar.fullscreen = fullscreened;});

            setup_drag_n_drop ();
            video_player.configure_window.connect ((video_w, video_h) => {on_configure_window (video_w, video_h);});

            //fullscreen on maximize
            mainwindow.window_state_event.connect ((e) => {
                on_window_state_changed (e.window.get_state ());
                return false;
            });

            mainwindow.size_allocate.connect (on_size_allocate);
            mainwindow.motion_notify_event.connect ((event) => {
                if (event.window == null)
                    return false;

                if (mouse_primary_down && settings.move_window) {
                    mouse_primary_down = false;
                    mainwindow.begin_move_drag (Gdk.BUTTON_PRIMARY,
                        (int)event.x_root, (int)event.y_root, event.time);
                }

                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);
                return update_pointer_position (event.y, allocation.height);
            });

            bottom_bar.time_widget.slider_motion_event.connect ((event) => {
                int x, y;
                bottom_bar.translate_coordinates (mainwindow, (int)event.x, (int)event.y, out x, out y);
                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);
                update_pointer_position (y, allocation.height);
            });

            mainwindow.button_press_event.connect ((event) => {
                if (event.button == Gdk.BUTTON_PRIMARY
                    && event.type == Gdk.EventType.2BUTTON_PRESS) // double left click
                    toggle_fullscreen ();

                if (event.button == Gdk.BUTTON_SECONDARY) // right click
                    bottom_bar.play_toggled ();

                if (event.button == Gdk.BUTTON_PRIMARY)
                    mouse_primary_down = true;

                return false;
            });

            mainwindow.button_release_event.connect ((event) => {
                if (event.button == Gdk.BUTTON_PRIMARY)
                    mouse_primary_down = false;

                return false;
            });

            mainwindow.leave_notify_event.connect ((event) => {
                if (event.window == null)
                    return false;

                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);
                if (event.x == event.window.get_width ())
                    return update_pointer_position (event.window.get_height (), allocation.height);
                else if (event.x == 0)
                    return update_pointer_position (event.window.get_height (), allocation.height);
                return update_pointer_position (event.y, allocation.height);
            });
            //shortcuts
            this.mainwindow.key_press_event.connect ((e) => {
                return on_key_press_event (e);
            });

            //save position in video when not finished playing
            mainwindow.destroy.connect (() => {on_destroy ();});

            //playlist wants us to open a file
            playlist.play.connect ((file) => {
                this.play_file (file.get_uri ());
            });

            bottom_bar.notify["child-revealed"].connect (() => {
                if (bottom_bar.child_revealed == true) {
                    mainwindow.get_window ().set_cursor (null);
                } else {
                    mainwindow.get_window ().set_cursor (new Gdk.Cursor (Gdk.CursorType.BLANK_CURSOR));
                }
            });

            stage.notify["allocation"].connect (() => {allocate_bottombar ();});
        }

        private void allocate_bottombar () {
            bottom_actor.width = stage.get_width ();
            bottom_bar.queue_resize ();
            bottom_actor.y = stage.get_height () - bottom_bar_size;
            unfullscreen_actor.y = 6;
            unfullscreen_actor.x = stage.get_width () - bottom_bar_size - 6;
        }

        private void setup_welcome_screen () {
            welcome = new Granite.Widgets.Welcome (_("No Videos Open"), _("Select a source to begin playing."));
            welcome.append ("document-open", _("Open file"), _("Open a saved file."));

            //welcome.append ("internet-web-browser", _("Open a location"), _("Watch something from the infinity of the internet"));
            var filename = settings.current_video;
            var last_file = File.new_for_uri (filename);
            welcome.append ("media-playback-start", _("Resume last video"), get_title (last_file.get_basename ()));
            bool show_last_file = settings.current_video != "";
            if (last_file.query_exists () == false) {
                show_last_file = false;
            }

            welcome.set_item_visible (1, show_last_file);

            welcome.append ("media-playlist-repeat", _("Replay"), _("Replay last video"));
            welcome.set_item_visible (2, false);

            welcome.append ("media-cdrom", _("Play from Disc"), _("Watch a DVD or open a file from disc"));
            welcome.set_item_visible (3, false);

            //look for dvd
            var disk_manager = DiskManager.get_default ();
            welcome.set_item_visible (3, disk_manager.has_media_volumes ());

            disk_manager.volume_found.connect ((vol) => {
                welcome.set_item_visible (3, disk_manager.has_media_volumes ());
            });

            disk_manager.volume_removed.connect ((vol) => {
                welcome.set_item_visible (3, disk_manager.has_media_volumes ());
            });



            //handle welcome
            welcome.activated.connect ((index) => {
                switch (index) {
                    case 0:
                        run_open_file ();
                        break;
                    case 1:
                        welcome.hide ();
                        clutter.show_all ();
                        restore_playlist ();
                        open_file (filename);
                        video_player.playing = false;
                        Idle.add (() => {video_player.progress = settings.last_stopped; return false;});
                        video_player.playing = true;
                        break;
                    case 2:
                        welcome.hide ();
                        clutter.show_all ();
                        open_file (playlist.get_first_item ().get_path ());
                        video_player.playing = false;
                        Idle.add (() => {video_player.progress = 0; return false;});
                        video_player.playing = true;
                        break;
                    case 3:
                        run_open_dvd ();
                        break;
                    default:
                        var d = new Gtk.Dialog.with_buttons (_("Open location"),
                            this.mainwindow, Gtk.DialogFlags.MODAL,
                            _("Cancel"), Gtk.ResponseType.CANCEL,
                            _("OK"),     Gtk.ResponseType.OK);

                        var grid  = new Gtk.Grid ();
                        var entry = new Gtk.Entry ();

                        grid.attach (new Gtk.Image.from_icon_name ("internet-web-browser",
                            Gtk.IconSize.DIALOG), 0, 0, 1, 2);
                        grid.attach (new Gtk.Label (_("Choose location")), 1, 0, 1, 1);
                        grid.attach (entry, 1, 1, 1, 1);

                        ((Gtk.Container)d.get_content_area ()).add (grid);
                        grid.show_all ();

                        if (d.run () == Gtk.ResponseType.OK) {
                            open_file (entry.text, true);
                            video_player.playing = !settings.playback_wait;
                            welcome.hide ();
                            clutter.show_all ();
                        }

                        d.destroy ();
                        break;
                    }

                int current_state = mainwindow.get_window ().get_state ();
                bool currently_maximized = (current_state & Gdk.WindowState.MAXIMIZED) != 0;

                // video is playing and we are maximized, go fullscreen
                if (video_player.playing && currently_maximized) {
                    mainwindow.fullscreen ();
                    fullscreened = true;
                }
            });
        }

        private bool on_key_press_event (Gdk.EventKey e) {
            switch (e.keyval) {
                case Gdk.Key.p:
                case Gdk.Key.space:
                    video_player.playing = !video_player.playing;
                    break;
                case Gdk.Key.Escape:
                    if (fullscreened)
                        toggle_fullscreen ();
                    else
                        mainwindow.destroy ();
                    break;
                case Gdk.Key.o:
                    run_open_file ();
                    break;
                case Gdk.Key.f:
                case Gdk.Key.F11:
                    toggle_fullscreen ();
                    break;
                case Gdk.Key.q:
                    mainwindow.destroy ();
                    break;
                case Gdk.Key.Down:
                    if (modifier_is_pressed (e, Gdk.ModifierType.SHIFT_MASK)) {
                        video_player.seek_jump_seconds (-5); // 5 secs
                    } else {
                        video_player.seek_jump_seconds (-60); // 1 min
                    }
                    bottom_bar.reveal_control ();
                    break;
                case Gdk.Key.Left:
                    if (modifier_is_pressed (e, Gdk.ModifierType.SHIFT_MASK)) {
                        video_player.seek_jump_seconds (-1); // 1 sec
                    } else {
                        video_player.seek_jump_seconds (-10); // 10 secs
                    }
                    bottom_bar.reveal_control ();
                    break;
                case Gdk.Key.Right:
                    if (modifier_is_pressed (e, Gdk.ModifierType.SHIFT_MASK)) {
                        video_player.seek_jump_seconds (1); // 1 sec
                    } else {
                        video_player.seek_jump_seconds (10); // 10 secs
                    }
                    bottom_bar.reveal_control ();
                    break;
                case Gdk.Key.Up:
                    if (modifier_is_pressed (e, Gdk.ModifierType.SHIFT_MASK)) {
                        video_player.seek_jump_seconds (5); // 5 secs
                    } else {
                        video_player.seek_jump_seconds (60); // 1 min
                    }
                    bottom_bar.reveal_control ();
                    break;
                case Gdk.Key.Page_Down:
                    video_player.seek_jump_seconds (-600); // 10 mins
                    bottom_bar.reveal_control ();
                    break;
                case Gdk.Key.Page_Up:
                    video_player.seek_jump_seconds (600); // 10 mins
                    bottom_bar.reveal_control ();
                    break;
                case Gdk.Key.a:
                    bottom_bar.preferences_popover.next_audio ();
                    break;
                case Gdk.Key.s:
                    bottom_bar.preferences_popover.next_text ();
                    break;
                default:
                    break;
            }

            return true;
        }

        private void on_configure_window (uint video_w, uint video_h) {
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
            if (!settings.keep_aspect || video_player.video_width < 1 || video_player.height < 1
                || !clutter.visible)
                return false;

            if (update_aspect_ratio_timeout != 0)
                Source.remove (update_aspect_ratio_timeout);

            update_aspect_ratio_timeout = Timeout.add (200, () => {
                Gtk.Allocation a;
                clutter.get_allocation (out a);
                print ("%i %i %i,%i\n", a.x, a.y, (mainwindow.get_allocated_width () - clutter.get_allocated_width ()) / 2, (mainwindow.get_allocated_height () - clutter.get_allocated_height ()) / 2);
                double width = clutter.get_allocated_width ();
                double height = width * video_player.video_height / (double) video_player.video_width;
                double width_offset = mainwindow.get_allocated_width () - width;
                double height_offset = mainwindow.get_allocated_height () - clutter.get_allocated_height ();

                print ("Width: %f, Height: %f, Offset: %f (%f, %f)\n", width, height, height_offset, video_player.video_width, video_player.video_height);

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

            if (!currently_maximized && !fullscreened && !welcome.is_visible ()) {
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

                welcome.hide ();
                clutter.show_all ();
            });
        }

        private void on_destroy () {
            if (video_player.uri.has_prefix ("dvd://")) {
                clear_video_settings ();
                return;
            }

            if (video_player.uri == null || video_player.uri == "")
                return;

            save_last_played_videos ();
        }

        private int old_h = - 1;
        private int old_w = - 1;
        private void on_size_allocate (Gtk.Allocation alloc) {
            if (alloc.width != old_w || alloc.height != old_h) {
                if (video_player.relayout ()) {
                    old_w = alloc.width;
                    old_h = alloc.height;
                }
            }

            if (prev_width != mainwindow.get_allocated_width () && prev_height != mainwindow.get_allocated_height ())
                Idle.add (update_aspect_ratio);
        }

        private bool update_pointer_position (double y, int window_height) {
            allocate_bottombar ();
            mainwindow.get_window ().set_cursor (null);
            if (bottom_bar_size == 0) {
                int minimum = 0;
                bottom_bar.get_preferred_height (out minimum, out bottom_bar_size);
            }

            bottom_bar.reveal_control ();

            return false;
        }

        private inline void save_last_played_videos () {
            playlist.save_playlist_config ();

            debug ("saving settings for: %s", playlist.get_first_item ().get_uri ());

            if (settings.current_video != "" && !video_player.at_end)
                settings.last_stopped = video_player.progress;
            else if (settings.current_video != "" && video_player.at_end) {
                settings.current_video = playlist.get_first_item ().get_uri ();
                settings.last_stopped = 0;
            }
        }

        private inline void clear_video_settings () {
            settings.last_stopped = 0;
            settings.last_played_videos = null;
            settings.current_video = "";
        }


        private void restore_playlist () {
            foreach (var filename in settings.last_played_videos) {
                playlist.add_item (File.new_for_uri (filename));
            }
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
                if (welcome.is_visible ()) {
                    playlist.clear_items ();
                }

                foreach (File item in file.get_files ()) {
                    playlist.add_item (item);
                }

                if (video_player.uri == null || welcome.is_visible ())
                    open_file (file.get_uri ());

                welcome.hide ();
                clutter.show_all ();

                settings.last_folder = file.get_current_folder ();
            }

            file.destroy ();
        }

        public void run_open_dvd () {
            read_first_disk.begin ();
        }

        private async void read_first_disk () {
            var disk_manager = DiskManager.get_default ();
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

            var root = volume.get_mount ().get_default_location ();
            open_file (root.get_uri (), true);
            video_player.playing = !settings.playback_wait;

            welcome.hide ();
            clutter.show_all ();
        }

        private void toggle_fullscreen () {
            if (fullscreened) {
                mainwindow.unmaximize ();
                mainwindow.unfullscreen ();
                fullscreened = false;
            } else {
                mainwindow.fullscreen ();
                fullscreened = true;
            }
        }

        private bool modifier_is_pressed (Gdk.EventKey event, Gdk.ModifierType modifier)
        {
            return (event.state & modifier) == modifier;
        }

        internal void open_file (string filename, bool dont_modify = false) {
            var file = File.new_for_commandline_arg (filename);

            if (file.query_file_type (0) == FileType.DIRECTORY) {
                Audience.recurse_over_dir (file, (file_ret) => {
                    playlist.add_item (file_ret);
                });

                file = playlist.get_first_item ();
                play_file (file.get_uri ());
            } else if (is_subtitle (filename) && video_player.playing) {
                video_player.set_subtitle_uri (filename);
            } else {
                playlist.add_item (file);
                play_file (file.get_uri ());
            }
        }

        private string? get_subtitle_for_uri (string uri) {
            string without_ext;
            int last_dot = uri.last_index_of (".", 0);
            int last_slash = uri.last_index_of ("/", 0);

            if (last_dot < last_slash) //we dont have extension
                without_ext = uri;
            else
                without_ext = uri.slice (0, last_dot);

            foreach (string ext in SUBTITLE_EXTENSIONS){
                string sub_uri = without_ext + "." + ext;
                if (File.new_for_uri (sub_uri).query_exists ())
                    return sub_uri;
            }
            return null;
        }

        private bool is_subtitle (string uri) {
            if (uri.length < 4 || uri.get_char (uri.length-4) != '.')
                return false;

            foreach (string ext in SUBTITLE_EXTENSIONS) {
                if (uri.down ().has_suffix (ext))
                    return true;
            }

            return false;
        }

        public void play_file (string uri) {
            debug ("Opening %s", uri);
            video_player.uri = uri;
            playlist.set_current (uri);
            bottom_bar.set_preview_uri (uri);

            string? sub_uri = get_subtitle_for_uri (uri);
            if (sub_uri != null)
                video_player.set_subtitle_uri (sub_uri);

            mainwindow.title = get_title (uri);
            video_player.playing = !settings.playback_wait;

            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);

            /*subtitles/audio tracks*/
            bottom_bar.preferences_popover.setup_text ();
            bottom_bar.preferences_popover.setup_audio ();
        }

        //the application started
        public override void activate () {
            build ();
            if (settings.resume_videos == true
                && settings.last_played_videos.length > 0
                && settings.current_video != ""
                && file_exists (settings.current_video)) {
                restore_playlist ();

                if (settings.last_stopped > 0) {
                    welcome.hide ();
                    clutter.show_all ();
                    open_file (settings.current_video);
                    video_player.playing = false;
                    Idle.add (() => {video_player.progress = settings.last_stopped; return false;});
                    video_player.playing = !settings.playback_wait;
                }
            }
        }

        //the application was requested to open some files
        public override void open (File[] files, string hint) {
            if (mainwindow == null)
                build ();

            welcome.hide ();
            clutter.show_all ();
            foreach (var file in files) {
                playlist.add_item (file);
            }

            if (video_player.uri != null) { // we already play some file
                if (files.length == 1)
                    show_notification (_("Video added to playlist"), files[0].get_basename ());
                else
                    show_notification (_("%i videos added to playlist").printf (files.length), "");
            } else
                open_file(files[0].get_uri ());
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
