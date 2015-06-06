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
        public GnomeMediaKeys             mediakeys;
        public GtkClutter.Embed           clutter;
        public Audience.Widgets.VideoPlayer video_player;
        public Audience.Widgets.BottomBar bottom_bar;
        private Clutter.Stage stage;
        private Gtk.Revealer unfullscreen_bar;
        private GtkClutter.Actor unfullscreen_actor;
        private GtkClutter.Actor bottom_actor;
        public bool repeat {
            get{
                return bottom_bar.get_repeat ();
            }
            set{
                bottom_bar.set_repeat (value);
            }
        }
        public int bottom_bar_size = 0;

        public signal void ended ();

        public PlayerPage () {
            message("PlayerPage created");

            video_player = Widgets.VideoPlayer.get_default ();
            video_player.notify["playing"].connect (() => {bottom_bar.toggle_play_pause ();});

            clutter = new GtkClutter.Embed ();
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
            bottom_bar.unfullscreen.connect (() => { App.get_instance ().toggle_fullscreen (); });
            bottom_bar.set_repeat (false);

            //tagview.select_external_subtitle.connect (video_player.set_subtitle_uri);

            unfullscreen_bar = bottom_bar.get_unfullscreen_button ();

            bottom_actor = new GtkClutter.Actor.with_contents (bottom_bar);
            bottom_actor.opacity = GLOBAL_OPACITY;
            stage.add_child (bottom_actor);

            unfullscreen_actor = new GtkClutter.Actor.with_contents (unfullscreen_bar);
            unfullscreen_actor.opacity = GLOBAL_OPACITY;
            stage.add_child (unfullscreen_actor);

            App.get_instance ().mainwindow.key_press_event.connect (on_key_press_event);

            //media keys
            try {
                mediakeys = Bus.get_proxy_sync (BusType.SESSION,
                    "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                mediakeys.MediaPlayerKeyPressed.connect ((bus, app, key) => {
                    if (app != "audience")
                       return;
                    switch (key) {
                        case "Previous":
                            App.playlist.previous ();
                            break;
                        case "Next":
                            App.playlist.next ();
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
                message ("video_player ended");
                Idle.add (() => {
                    video_player.playing = false;
                    int last_played_index = App.playlist.get_current ();
                    if (!App.playlist.next ()) {

                        if (repeat) {
                            play_file (App.playlist.get_first_item ().get_uri ());
                            Idle.add (() => { video_player.progress = 0; return false; });
                            video_player.playing = true;
                        } else {
                            /* var button = welcome_page.get_button_from_index (2); */
                            /* welcome_page.set_item_visible (1, false); */
                            /* welcome_page.set_item_visible (2, true); */
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

            App.get_instance ().notify["fullscreened"].connect (() => {bottom_bar.fullscreen = App.get_instance ().fullscreened;});

            /* setup_drag_n_drop (); */
            video_player.configure_window.connect ((video_w, video_h) => {App.get_instance ().on_configure_window (video_w, video_h);});

            bottom_bar.time_widget.slider_motion_event.connect ((event) => {
                int x, y;
                bottom_bar.translate_coordinates (App.get_instance ().mainwindow, (int)event.x, (int)event.y, out x, out y);
                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);
                App.get_instance ().update_pointer_position (y, allocation.height);
            });

            //playlist wants us to open a file
            App.playlist.play.connect ((file) => {
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
            message ("PlayerPage destroying"+this.ref_count.to_string ());

            App.get_instance ().mainwindow.key_press_event.disconnect (on_key_press_event);

            video_player.text_tags_changed.disconnect (bottom_bar.preferences_popover.setup_text);
            video_player.audio_tags_changed.disconnect (bottom_bar.preferences_popover.setup_audio);
        }

        public void play_file (string uri) {
            debug ("Opening %s", uri);
            video_player.uri = uri;
            App.playlist.set_current (uri);
            bottom_bar.set_preview_uri (uri);

            string? sub_uri = get_subtitle_for_uri (uri);
            if (sub_uri != null)
                video_player.set_subtitle_uri (sub_uri);

            App.get_instance ().mainwindow.title = get_title (uri);
            video_player.playing = !settings.playback_wait;

            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);

            /*subtitles/audio tracks*/
            bottom_bar.preferences_popover.setup_text ();
            bottom_bar.preferences_popover.setup_audio ();
        }

        public void resume_last_videos () {
            /* restore_playlist (); */
            message (settings.current_video);
            play_file (settings.current_video);
            video_player.playing = false;
            Idle.add (() => {video_player.progress = settings.last_stopped; return false;});
            video_player.playing = true;
        }

        private void restore_playlist () {
            foreach (var filename in settings.last_played_videos) {
                App.playlist.add_item (File.new_for_uri (filename));
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

        public void allocate_bottombar () {
            bottom_actor.width = stage.get_width ();
            bottom_bar.queue_resize ();
            bottom_actor.y = stage.get_height () - bottom_bar_size;
            unfullscreen_actor.y = 6;
            unfullscreen_actor.x = stage.get_width () - bottom_bar_size - 6;
        }

        public bool on_key_press_event (Gdk.EventKey e) {
            switch (e.keyval) {
                case Gdk.Key.p:
                case Gdk.Key.space:
                    video_player.playing = !video_player.playing;
                    break;
                case Gdk.Key.Escape:
                    if (App.get_instance ().fullscreened) {
                        App.get_instance ().toggle_fullscreen ();
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
    }
}
