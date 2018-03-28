namespace Audience {
    private  const string[] SUBTITLE_EXTENSIONS = {
        "sub",
        "srt",
        "smi",
        "ssa",
        "ass",
        "asc"
    };

    public class PlayerPage : Gtk.EventBox {
        public signal void unfullscreen_clicked ();
        public signal void ended ();

        public GtkClutter.Embed clutter;
        private Clutter.Actor video_actor;
        private Audience.Widgets.BottomBar bottom_bar;
        private Clutter.Stage stage;
        private Gtk.Revealer unfullscreen_bar;
        private GtkClutter.Actor unfullscreen_actor;
        private GtkClutter.Actor bottom_actor;
        private GnomeMediaKeys mediakeys;
        private ClutterGst.Playback playback;

        private bool mouse_primary_down = false;

        public bool repeat {
            get{
                return bottom_bar.repeat;
            }

            set{
                bottom_bar.repeat = value;
            }
        }

        public bool playing {
            get {
                return playback.playing;
            }
            set {
                if (playback.playing == value)
                    return;

                playback.playing = value;
            }
        }

        private bool _fullscreened = false;
        public bool fullscreened {
            get {
                return _fullscreened;
            }
            set {
                _fullscreened = value;
                bottom_bar.fullscreen = value;
            }
        }

        public PlayerPage () {
        }

        construct {
            events |= Gdk.EventMask.POINTER_MOTION_MASK;
            events |= Gdk.EventMask.KEY_PRESS_MASK;
            events |= Gdk.EventMask.KEY_RELEASE_MASK;
            playback = new ClutterGst.Playback ();
            playback.set_seek_flags (ClutterGst.SeekFlags.ACCURATE);

            clutter = new GtkClutter.Embed ();
            stage = (Clutter.Stage)clutter.get_stage ();
            stage.background_color = {0, 0, 0, 0};

            video_actor = new Clutter.Actor ();
#if VALA_0_34
            var aspect_ratio = new ClutterGst.Aspectratio ();
#else
            var aspect_ratio = ClutterGst.Aspectratio.@new ();
#endif
            ((ClutterGst.Aspectratio) aspect_ratio).paint_borders = false;
            ((ClutterGst.Content) aspect_ratio).player = playback;
            /* Commented because of a bug in the compositor
            ((ClutterGst.Content) aspect_ratio).size_change.connect ((width, height) => {
                double aspect = ((double) width)/((double) height);
                var geometry = Gdk.Geometry ();
                geometry.min_aspect = aspect;
                geometry.max_aspect = aspect;
                ((Gtk.Window) get_toplevel ()).set_geometry_hints (get_toplevel (), geometry, Gdk.WindowHints.ASPECT);
            });
            */
            video_actor.content = aspect_ratio;

            video_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            video_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));

            Signal.connect (clutter, "button-press-event", (GLib.Callback) navigation_event, this);
            Signal.connect (clutter, "button-release-event", (GLib.Callback) navigation_event, this);
            Signal.connect (clutter, "key-press-event", (GLib.Callback) navigation_event, this);
            Signal.connect (clutter, "key-release-event", (GLib.Callback) navigation_event, this);
            Signal.connect (clutter, "motion-notify-event", (GLib.Callback) navigation_event, this);

            stage.add_child (video_actor);

            bottom_bar = new Widgets.BottomBar (playback);
            bottom_bar.bind_property ("playing", playback, "playing", BindingFlags.BIDIRECTIONAL);
            bottom_bar.unfullscreen.connect (() => unfullscreen_clicked ());

            unfullscreen_bar = bottom_bar.get_unfullscreen_button ();

            bottom_actor = new GtkClutter.Actor.with_contents (bottom_bar);
            bottom_actor.opacity = GLOBAL_OPACITY;
            bottom_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            bottom_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.Y_AXIS, 1));
            stage.add_child (bottom_actor);

            unfullscreen_actor = new GtkClutter.Actor.with_contents (unfullscreen_bar);
            unfullscreen_actor.opacity = GLOBAL_OPACITY;
            unfullscreen_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.X_AXIS, 1));
            unfullscreen_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.Y_AXIS, 0));
            stage.add_child (unfullscreen_actor);

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
                            playback.playing = !playback.playing;
                            break;
                        default:
                            break;
                    }
                });

                mediakeys.GrabMediaPlayerKeys("audience", 0);
            } catch (Error e) {
                warning (e.message);
            }

            this.motion_notify_event.connect ((event) => {
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
                if (playback.progress > 0.99)
                    settings.last_stopped = 0;
                else
                    settings.last_stopped = playback.progress;

                get_playlist_widget ().save_playlist ();
                Audience.Services.Inhibitor.get_instance ().uninhibit ();
            });

            //end
            playback.eos.connect (() => {
                Idle.add (() => {
                    playback.progress = 0;
                    if (!get_playlist_widget ().next ()) {
                        if (repeat) {
                            string file = get_playlist_widget ().get_first_item ().get_uri ();
                            App.get_instance ().mainwindow.open_files ({ File.new_for_uri (file) });
                        } else {
                            playback.playing = false;
                            settings.last_stopped = 0;
                            ended ();
                        }
                    }
                    return false;
                });
            });

            //playlist wants us to open a file
            get_playlist_widget ().play.connect ((file) => {
                App.get_instance ().mainwindow.open_files ({ File.new_for_uri (file.get_uri ()) });
            });

            bottom_bar.notify["child-revealed"].connect (() => {
                if (bottom_bar.child_revealed == true) {
                    App.get_instance ().mainwindow.get_window ().set_cursor (null);
                } else {
                    var window = App.get_instance ().mainwindow.get_window ();
                    var display = window.get_display ();
                    var cursor = new Gdk.Cursor.for_display (display, Gdk.CursorType.BLANK_CURSOR);
                    window.set_cursor (cursor);
                }
            });

            notify["playing"].connect (() => {
                if (playing) {
                    Audience.Services.Inhibitor.get_instance ().inhibit ();
                } else {
                    Audience.Services.Inhibitor.get_instance ().uninhibit ();
                }
            });

            add (clutter);
            show_all ();
        }

        public void play_file (string uri, bool from_beginning = true) {
            debug ("Opening %s", uri);
            get_playlist_widget ().set_current (uri);
            playback.uri = uri;

            string? sub_uri = get_subtitle_for_uri (uri);
            if (sub_uri != null && sub_uri != uri)
                playback.set_subtitle_uri (sub_uri);

            App.get_instance ().mainwindow.title = get_title (uri);

            if (from_beginning) {
                playback.progress = 0.0;
            } else {
                playback.progress = settings.last_stopped;
            }

            playback.playing = !settings.playback_wait;
            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);

            bottom_bar.preferences_popover.is_setup = false;

            Audience.Services.Inhibitor.get_instance ().inhibit ();
            settings.current_video = uri;
        }

        public double get_progress () {
            return playback.progress;
        }

        public string get_played_uri () {
            return playback.uri;
        }
        
        public void reset_played_uri () {
            playback.uri = "";
        }

        public void next () {
            get_playlist_widget ().next ();
        }

        public void prev () {
            get_playlist_widget ().next ();
        }

        public void resume_last_videos () {
            play_file (settings.current_video);
            playback.playing = false;
            if (settings.resume_videos) {
                playback.progress = settings.last_stopped;
            } else {
                playback.progress = 0.0;
            }

            playback.playing = !settings.playback_wait;
        }

        public void append_to_playlist (File file) {
            if (playback.playing && is_subtitle (file.get_uri ())) {
                playback.set_subtitle_uri (file.get_uri ());
            } else {
                get_playlist_widget ().add_item (file);
            }
        }

        public void play_first_in_playlist () {
            var file = get_playlist_widget ().get_first_item ();
            play_file (file.get_uri ());
        }

        public void reveal_control () {
            bottom_bar.reveal_control ();
        }

        public void next_audio () {
            bottom_bar.preferences_popover.next_audio ();
        }

        public void next_text () {
            bottom_bar.preferences_popover.next_text ();
        }

        public void seek_jump_seconds (int seconds) {
            var duration = playback.duration;
            var progress = playback.progress;
            var new_progress = ((duration * progress) + (double)seconds)/duration;
            playback.progress = new_progress.clamp (0.0, 1.0);
        }

        public Widgets.Playlist get_playlist_widget () {
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

        private bool is_subtitle (string uri) {
            if (uri.length < 4 || uri.get_char (uri.length-4) != '.')
                return false;

            foreach (string ext in SUBTITLE_EXTENSIONS) {
                if (uri.down ().has_suffix (ext))
                    return true;
            }

            return false;
        }

        public bool update_pointer_position (double y, int window_height) {
            App.get_instance ().mainwindow.get_window ().set_cursor (null);

            bottom_bar.reveal_control ();

            return false;
        }

        [CCode (instance_pos = -1)]
        private bool navigation_event (GtkClutter.Embed embed, Clutter.Event event) {
            var video_sink = playback.get_video_sink ();
            var frame = video_sink.get_frame ();

            if (frame == null)
                return true;

            float x, y;
            event.get_coords (out x, out y);
            // Transform event coordinates into the actor's coordinates
            video_actor.transform_stage_point (x, y, out x, out y);
            float actor_width, actor_height;
            video_actor.get_size (out actor_width, out actor_height);

            /* Convert event's coordinates into the frame's coordinates. */
            x = x * frame.resolution.width / actor_width;
            y = y * frame.resolution.height / actor_height;

            switch (event.type) {
                case Clutter.EventType.MOTION:
                    ((Gst.Video.Navigation) video_sink).send_mouse_event ("mouse-move", 0, x, y);
                    break;
                case Clutter.EventType.BUTTON_PRESS:
                    ((Gst.Video.Navigation) video_sink).send_mouse_event ("mouse-button-press", (int)event.button.button, x, y);
                    break;
                case Clutter.EventType.KEY_PRESS:
                    warning (X.keysym_to_string (event.key.keyval));
                    ((Gst.Video.Navigation) video_sink).send_key_event ("key-press", X.keysym_to_string (event.key.keyval));
                    break;
                case Clutter.EventType.KEY_RELEASE:
                    ((Gst.Video.Navigation) video_sink).send_key_event ("key-release", X.keysym_to_string (event.key.keyval));
                    break;
            }

            return false;
        }
    }
}
