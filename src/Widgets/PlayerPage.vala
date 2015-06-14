namespace Audience {
    private  const string[] SUBTITLE_EXTENSIONS = {
        "sub",
        "srt",
        "smi",
        "ssa",
        "ass",
        "asc"
    };
    public class PlayerPage : Gtk.Bin {
        public GtkClutter.Embed           clutter;
        public Audience.Widgets.VideoPlayer video_player;
        private Audience.Widgets.BottomBar bottom_bar;
        private Clutter.Stage stage;
        private Gtk.Revealer unfullscreen_bar;
        private GtkClutter.Actor unfullscreen_actor;
        private GtkClutter.Actor bottom_actor;
        private GnomeMediaKeys             mediakeys;

        private bool mouse_primary_down = false;
        private bool fullscreened = false;

        public bool repeat {
            get{
                return bottom_bar.get_repeat ();
            }

            set{
                bottom_bar.set_repeat (value);
            }
        }

        private int bottom_bar_size = 0;

        public signal void ended ();

        public PlayerPage () {
            /* video_player = Widgets.VideoPlayer.get_default (); */
            video_player = new Widgets.VideoPlayer();
            video_player.notify["playing"].connect (() => {bottom_bar.toggle_play_pause ();});

            clutter = new GtkClutter.Embed ();
            stage = (Clutter.Stage)clutter.get_stage ();
            stage.background_color = {0, 0, 0, 0};
            stage.use_alpha = true;

            video_player.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            video_player.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));

            stage.add_child (video_player);

            bottom_bar = new Widgets.BottomBar (video_player);
            bottom_bar.set_valign (Gtk.Align.END);
            bottom_bar.play_toggled.connect (() => { video_player.playing = !video_player.playing; });
            bottom_bar.seeked.connect ((val) => { video_player.progress = val; });
            bottom_bar.unfullscreen.connect (()=>{set_fullscreen (false);});
            bottom_bar.set_repeat (false);

            unfullscreen_bar = bottom_bar.get_unfullscreen_button ();

            bottom_actor = new GtkClutter.Actor.with_contents (bottom_bar);
            bottom_actor.opacity = GLOBAL_OPACITY;
            stage.add_child (bottom_actor);

            unfullscreen_actor = new GtkClutter.Actor.with_contents (unfullscreen_bar);
            unfullscreen_actor.opacity = GLOBAL_OPACITY;
            stage.add_child (unfullscreen_actor);

            this.size_allocate.connect (on_size_allocate);
            App.get_instance ().mainwindow.key_press_event.connect (on_key_press_event);
            App.get_instance ().mainwindow.window_state_event.connect (on_window_state_event);
            if (App.get_instance ().mainwindow.is_maximized)
                set_fullscreen (true);

            //media keys
            try {
                mediakeys = Bus.get_proxy_sync (BusType.SESSION,
                    "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                mediakeys.MediaPlayerKeyPressed.connect ((bus, app, key) => {
                    if (app != "audience")
                       return;
                    switch (key) {
                        case "Previous":
                            get_playlist_widget ().previous ();
                            break;
                        case "Next":
                            get_playlist_widget ().next ();
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

            App.get_instance ().mainwindow.motion_notify_event.connect ((event) => {
                if (mouse_primary_down && settings.move_window) {
                    mouse_primary_down = false;
                    App.get_instance ().mainwindow.begin_move_drag (Gdk.BUTTON_PRIMARY,
                        (int)event.x_root, (int)event.y_root, event.time);
                }

                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);
                return update_pointer_position (event.y, allocation.height);
            });

            this.button_press_event.connect ((event) => {
                if (event.button == Gdk.BUTTON_PRIMARY
                    && event.type == Gdk.EventType.2BUTTON_PRESS) // double left click
                    set_fullscreen(!fullscreened);

                if (event.button == Gdk.BUTTON_SECONDARY) // right click
                    bottom_bar.play_toggled ();

                if (event.button == Gdk.BUTTON_PRIMARY)
                    mouse_primary_down = true;

                return false;
            });

            this.button_release_event.connect ((event) => {
                if (event.button == Gdk.BUTTON_PRIMARY)
                    mouse_primary_down = false;

                return false;
            });

            this.leave_notify_event.connect ((event) => {
                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);

                if (event.x == event.window.get_width ())
                    return update_pointer_position (event.window.get_height (), allocation.height);
                else if (event.x == 0)
                    return update_pointer_position (event.window.get_height (), allocation.height);

                return update_pointer_position (event.y, allocation.height);
            });

            this.destroy.connect (() => {
                // FIXME:should find better way to decide if its end of playlist
                if (video_player.progress > 0.99)
                    settings.last_stopped = 0;
                else
                    settings.last_stopped = video_player.progress;

                get_playlist_widget ().save_playlist ();
            });

            /*events*/
            video_player.text_tags_changed.connect (bottom_bar.preferences_popover.setup_text);
            video_player.audio_tags_changed.connect (bottom_bar.preferences_popover.setup_audio);
            video_player.progression_changed.connect ((current_time, total_time) => {
                bottom_bar.set_progression_time (current_time, total_time);
            });

            //end
            video_player.ended.connect (() => {
                Idle.add (() => {
                    video_player.playing = false;
                    int last_played_index = get_playlist_widget ().get_current ();
                    if (!get_playlist_widget ().next ()) {

                        if (repeat) {
                            play_file (get_playlist_widget ().get_first_item ().get_uri ());
                            Idle.add (() => { video_player.progress = 0; return false; });
                            video_player.playing = true;
                        } else {
                            /* if (last_played_index > 0) { */
                            /*     button.description = _("Replay last playlist"); */
                            /* } else { App.get_instance ().*/
                            /*     button.description = _("Replay '%s'").printf (get_title (playlist.get_first_item ().get_basename ())); */
                            /* } */

                            ended ();
                        }
                    }
                    return false;
                });
            });

            video_player.error.connect (() => {
                App.get_instance ().page = Page.WELCOME;
            });

            video_player.plugin_install_done.connect (() => {
                App.get_instance ().page = Page.PLAYER;
            });

            video_player.notify["playing"].connect (() => {
                App.get_instance ().mainwindow.set_keep_above (video_player.playing && settings.stay_on_top);
            });

            video_player.configure_window.connect ((video_w, video_h) => {App.get_instance ().on_configure_window (video_w, video_h);});

            bottom_bar.time_widget.slider_motion_event.connect ((event) => {
                int x, y;
                bottom_bar.translate_coordinates (App.get_instance ().mainwindow, (int)event.x, (int)event.y, out x, out y);
                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);
                update_pointer_position (y, allocation.height);
            });

            //playlist wants us to open a file
            get_playlist_widget ().play.connect ((file) => {
                this.play_file (file.get_uri ());
            });

            bottom_bar.notify["child-revealed"].connect (() => {
                if (bottom_bar.child_revealed == true) {
                    App.get_instance ().mainwindow.get_window ().set_cursor (null);
                } else {
                    App.get_instance ().mainwindow.get_window ().set_cursor (new Gdk.Cursor (Gdk.CursorType.BLANK_CURSOR));
                }
            });

            stage.notify["allocation"].connect (() => {allocate_bottombar ();});

            add (clutter);

            show_all ();

        }

        ~PlayerPage () {
            video_player.playing = false;

            App.get_instance ().mainwindow.window_state_event.disconnect (on_window_state_event);
            App.get_instance ().mainwindow.key_press_event.disconnect (on_key_press_event);
            App.get_instance ().mainwindow.get_window ().set_cursor (null);

            App.get_instance ().mainwindow.unfullscreen ();
            if (fullscreened)
                App.get_instance ().mainwindow.maximize ();

            video_player.text_tags_changed.disconnect (bottom_bar.preferences_popover.setup_text);
            video_player.audio_tags_changed.disconnect (bottom_bar.preferences_popover.setup_audio);
        }

        public void play_file (string uri) {
            debug ("Opening %s", uri);
            video_player.uri = uri;
            get_playlist_widget ().set_current (uri);
            bottom_bar.set_preview_uri (uri);

            string? sub_uri = get_subtitle_for_uri (uri);
            if (sub_uri != null)
                video_player.set_subtitle_uri (sub_uri);

            App.get_instance ().set_window_title (get_title (uri));
            init_size_variable ();
            video_player.relayout ();
            update_aspect_ratio ();
            video_player.playing = !settings.playback_wait;

            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);

            /*subtitles/audio tracks*/
            bottom_bar.preferences_popover.setup_text ();
            bottom_bar.preferences_popover.setup_audio ();
        }

        public void next () {
            get_playlist_widget ().next ();
        }

        public void prev () {
            get_playlist_widget ().next ();
        }

        public void resume_last_videos () {
            play_file (settings.current_video);
            video_player.playing = false;
            Idle.add (() => {video_player.progress = settings.last_stopped; return false;});
            video_player.playing = true;
        }

        public void append_to_playlist (File file) {
            get_playlist_widget ().add_item (file);
        }

        public void play_first_in_playlist () {
            var file = get_playlist_widget ().get_first_item ();
            play_file (file.get_uri ());
        }

        private Widgets.Playlist get_playlist_widget () {
            return bottom_bar.playlist_popover.playlist;
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

        public static bool is_subtitle (string uri) {
            if (uri.length < 4 || uri.get_char (uri.length-4) != '.')
                return false;

            foreach (string ext in SUBTITLE_EXTENSIONS) {
                if (uri.down ().has_suffix (ext))
                    return true;
            }

            return false;
        }

        private void allocate_bottombar () {
            bottom_actor.width = stage.get_width ();
            bottom_bar.queue_resize ();
            bottom_actor.y = stage.get_height () - bottom_bar_size;
            unfullscreen_actor.y = 6;
            unfullscreen_actor.x = stage.get_width () - bottom_bar_size - 6;
        }

        public bool update_pointer_position (double y, int window_height) {
            allocate_bottombar ();
            App.get_instance ().mainwindow.get_window ().set_cursor (null);
            if (bottom_bar_size == 0) {
                int minimum = 0;
                bottom_bar.get_preferred_height (out minimum, out bottom_bar_size);
            }

            bottom_bar.reveal_control ();

            return false;
        }

        private bool on_key_press_event (Gdk.EventKey e) {
            switch (e.keyval) {
                case Gdk.Key.p:
                case Gdk.Key.space:
                    video_player.playing = !video_player.playing;
                    break;
                case Gdk.Key.Escape:
                    if (fullscreened) {
                        set_fullscreen (false);
                        return true;
                    }
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

            return false;
        }

        private bool on_window_state_event (Gdk.EventWindowState e){
            switch (e.changed_mask){
                case Gdk.WindowState.FULLSCREEN:
                fullscreened= ((e.new_window_state & Gdk.WindowState.FULLSCREEN)!=0);
                break;
                case Gdk.WindowState.MAXIMIZED:
                bool currently_maximixed = ((e.new_window_state & Gdk.WindowState.MAXIMIZED)!=0);
                set_fullscreen (currently_maximixed);
                break;
            }
            return false;
        }

        private void set_fullscreen (bool full){
            fullscreened = full;
            if (full) {
                App.get_instance ().mainwindow.unmaximize ();
                App.get_instance ().mainwindow.fullscreen ();
            } else {
                // unfullscreen shoulnd't be call from elsewhere other than here
                App.get_instance ().mainwindow.maximize ();
                App.get_instance ().mainwindow.unfullscreen ();
            }
            bottom_bar.fullscreen = full;
        }

        private uint update_aspect_ratio_timeout = 0;
        private bool update_aspect_ratio_locked = false;
        private int prev_width = 0;
        private int prev_height = 0;
        private int old_h = -1;
        private int old_w = -1;
        void init_size_variable () {
            update_aspect_ratio_timeout = 0;
            update_aspect_ratio_locked = false;
            prev_width = 0;
            prev_height = 0;
            old_h = -1;
            old_w = -1;
        }
        /**
         * Updates the window's aspect ratio locking if enabled.
         * Return type is just there to make it compatible with Idle.add()
         */
        private bool update_aspect_ratio () {
            if (!settings.keep_aspect
                || video_player.video_width < 1
                || video_player.height < 1
                || !clutter.visible)
                return false;

            if (update_aspect_ratio_timeout != 0)
                Source.remove (update_aspect_ratio_timeout);

            update_aspect_ratio_timeout = Timeout.add (200, () => {
                Gtk.Allocation a;
                clutter.get_allocation (out a);
                print ("%i %i %i,%i\n", a.x, a.y, (this.get_allocated_width () - this.clutter.get_allocated_width ()) / 2, (this.get_allocated_height () - this.clutter.get_allocated_height ()) / 2);
                double width = clutter.get_allocated_width ();
                double height = width * video_player.video_height / (double) video_player.video_width;

                App.get_instance ().set_content_size (width, height,clutter.get_allocated_height ());

                prev_width = this.get_allocated_width ();
                prev_height = this.get_allocated_height ();

                update_aspect_ratio_timeout = 0;

                return false;
            });

            return false;
        }
        private void on_size_allocate (Gtk.Allocation alloc) {
            if (alloc.width != old_w || alloc.height != old_h) {
                if (video_player.relayout ()) {
                    old_w = alloc.width;
                    old_h = alloc.height;
                }
            }

            if (prev_width != this.get_allocated_width () && prev_height != this.get_allocated_height ())
                Idle.add (update_aspect_ratio);
        }

    }
}
