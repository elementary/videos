/*
 * Copyright 2013-2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Audience {
    private const string[] SUBTITLE_EXTENSIONS = {
        "sub",
        "srt",
        "smi",
        "ssa",
        "ass",
        "asc"
    };

    public class PlayerPage : Gtk.EventBox {
        public signal void ended ();

        private Audience.Widgets.BottomBar bottom_bar;
        private GtkClutter.Actor bottom_actor;
        private GtkClutter.Embed clutter;
        private ClutterGst.Playback playback;
        private unowned Gst.Pipeline pipeline;
        private Clutter.Stage stage;
        private Gtk.Revealer unfullscreen_revealer;
        private GtkClutter.Actor unfullscreen_actor;
        private Clutter.Actor video_actor;
        private uint inhibit_token = 0;

        private bool mouse_primary_down = false;

        private bool _fullscreened = false;
        public bool fullscreened {
            get {
                return _fullscreened;
            }
            set {
                _fullscreened = value;

                if (value && bottom_bar.child_revealed) {
                    unfullscreen_revealer.reveal_child = true;
                } else if (!value && bottom_bar.child_revealed) {
                    unfullscreen_revealer.reveal_child = false;
                }
            }
        }

        public PlayerPage () {
        }

        construct {
            events |= Gdk.EventMask.POINTER_MOTION_MASK;
            events |= Gdk.EventMask.KEY_PRESS_MASK;
            events |= Gdk.EventMask.KEY_RELEASE_MASK;
            playback = new ClutterGst.Playback ();
            pipeline = (Gst.Pipeline)(playback.get_pipeline ());

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

            var unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Unfullscreen")
            };

            unfullscreen_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN
            };
            unfullscreen_revealer.add (unfullscreen_button);
            unfullscreen_revealer.show_all ();

            bottom_actor = new GtkClutter.Actor.with_contents (bottom_bar);
            bottom_actor.opacity = GLOBAL_OPACITY;
            bottom_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            bottom_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.Y_AXIS, 1));
            stage.add_child (bottom_actor);

            unfullscreen_actor = new GtkClutter.Actor.with_contents (unfullscreen_revealer);
            unfullscreen_actor.opacity = GLOBAL_OPACITY;
            unfullscreen_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.X_AXIS, 1));
            unfullscreen_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.Y_AXIS, 0));
            stage.add_child (unfullscreen_actor);

            motion_notify_event.connect (event => {
                if (mouse_primary_down) {
                    mouse_primary_down = false;
                    App.get_instance ().active_window.begin_move_drag (Gdk.BUTTON_PRIMARY,
                        (int)event.x_root, (int)event.y_root, event.time);
                }

                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);
                return update_pointer_position (event.y, allocation.height);
            });

            button_press_event.connect (event => {
                if (event.button == Gdk.BUTTON_PRIMARY) {
                    mouse_primary_down = true;
                }

                return false;
            });

            button_release_event.connect (event => {
                if (event.button == Gdk.BUTTON_PRIMARY) {
                    mouse_primary_down = false;
                }

                return false;
            });

            bottom_bar.notify["child-revealed"].connect (() => {
                if (bottom_bar.child_revealed && fullscreened) {
                    unfullscreen_revealer.reveal_child = bottom_bar.child_revealed;
                } else if (!bottom_bar.child_revealed) {
                    unfullscreen_revealer.reveal_child = bottom_bar.child_revealed;
                }
            });

            unfullscreen_button.clicked.connect (() => {
                ((Gtk.Window) get_toplevel ()).unfullscreen ();
            });

            leave_notify_event.connect (event => {
                Gtk.Allocation allocation;
                clutter.get_allocation (out allocation);

                if (event.x == event.window.get_width ()) {
                    return update_pointer_position (event.window.get_height (), allocation.height);
                } else if (event.x == 0) {
                    return update_pointer_position (event.window.get_height (), allocation.height);
                }

                return update_pointer_position (event.y, allocation.height);
            });

            destroy.connect (() => {
                // FIXME:should find better way to decide if its end of playlist
                if (playback.progress > 0.99) {
                    settings.set_double ("last-stopped", 0);
                } else if (playback.uri != "") {
                    /* The progress is only valid if the uri has not been reset as the current video setting is not
                     * updated.  The playback.uri has been reset when the window is destroyed from the Welcome page */
                    settings.set_double ("last-stopped", playback.progress);
                }

                get_playlist_widget ().save_playlist ();

                if (inhibit_token != 0) {
                    ((Gtk.Application) GLib.Application.get_default ()).uninhibit (inhibit_token);
                    inhibit_token = 0;
                }
            });

            //end
            playback.eos.connect (() => {
                Idle.add (() => {
                    playback.progress = 0;
                    if (!get_playlist_widget ().next ()) {
                        if (bottom_bar.repeat) {
                            string file = get_playlist_widget ().get_first_item ().get_uri ();
                            ((Audience.Window) App.get_instance ().active_window).open_files ({ File.new_for_uri (file) });
                        } else {
                            playback.playing = false;
                            settings.set_double ("last-stopped", 0);
                            ended ();
                        }
                    }
                    return false;
                });
            });

            var playback_manager = PlaybackManager.get_default ();

            playback_manager.stop.connect (() => {
                settings.set_double ("last-stopped", 0);
                settings.set_strv ("last-played-videos", {});
                settings.set_string ("current-video", "");

                /* We do not want to emit an "ended" signal if already ended - it can cause premature
                 * ending of next video and other side-effects
                 */
                if (playback.playing) {
                    playback.playing = false;
                    playback.progress = 1.0;
                    ended ();
                }
            });

            playback_manager.set_subtitle.connect (set_subtitle);

            bottom_bar.notify["child-revealed"].connect (() => {
                if (bottom_bar.child_revealed == true) {
                    ((Audience.Window) App.get_instance ().active_window).show_mouse_cursor ();
                } else {
                    ((Audience.Window) App.get_instance ().active_window).hide_mouse_cursor ();
                }
            });

            GLib.Application.get_default ().action_state_changed.connect ((name, new_state) => {
                if (name == Audience.App.ACTION_PLAY_PAUSE) {
                    playback.playing = new_state.get_boolean ();
                }
            });

            playback.notify["playing"].connect (() => {
                unowned var app = (Gtk.Application) Application.get_default ();

                var play_pause_action = app.lookup_action (Audience.App.ACTION_PLAY_PAUSE);
                ((SimpleAction) play_pause_action).set_state (playback.playing);

                if (playback.playing) {
                    if (inhibit_token != 0) {
                        app.uninhibit (inhibit_token);
                    }

                    inhibit_token = app.inhibit (
                        app.get_active_window (),
                        Gtk.ApplicationInhibitFlags.IDLE | Gtk.ApplicationInhibitFlags.SUSPEND,
                        _("A video is playing")
                    );
                } else if (inhibit_token != 0) {
                    app.uninhibit (inhibit_token);
                    inhibit_token = 0;
                }
            });

            add (clutter);
            show_all ();
        }

        public void play_file (string uri, bool from_beginning = true) {
            debug ("Opening %s", uri);
            pipeline.set_state (Gst.State.NULL);
            var file = File.new_for_uri (uri);
            try {
                FileInfo info = file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," + GLib.FileAttribute.STANDARD_NAME, 0);
                unowned string content_type = info.get_content_type ();

                if (!GLib.ContentType.is_a (content_type, "video/*")) {
                    debug ("Unrecognized file format: %s", content_type);
                    var unsupported_file_dialog = new UnsupportedFileDialog (uri, info.get_name (), content_type);
                    unsupported_file_dialog.present ();

                    unsupported_file_dialog.response.connect (type => {
                        if (type == Gtk.ResponseType.CANCEL) {
                            // Play next video if available or else go to welcome page
                            if (!get_playlist_widget ().next ()) {
                                ended ();
                            }
                        }

                        unsupported_file_dialog.destroy ();
                    });
                }
            } catch (Error e) {
                debug (e.message);
            }

            get_playlist_widget ().set_current (uri);
            playback.uri = uri;


            App.get_instance ().active_window.title = get_title (uri);

            /* Set progress before subtitle uri else it gets reset to zero */
            if (from_beginning) {
                playback.progress = 0.0;
            } else {
                playback.progress = settings.get_double ("last-stopped");
            }

            string sub_uri = "";
            if (!from_beginning) { //We are resuming the current video - fetch the current subtitles
                /* Should not bind to this setting else may cause loop */
                sub_uri = settings.get_string ("current-external-subtitles-uri");
            } else {
                sub_uri = get_subtitle_for_uri (uri);
            }

            set_subtitle (sub_uri);

            playback.playing = true;
            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);

            bottom_bar.preferences_popover.is_setup = false;

            settings.set_string ("current-video", uri);
        }

        public double get_progress () {
            return playback.progress;
        }

        public void append_to_playlist (File file) {
            if (is_subtitle (file.get_uri ())) {
                set_subtitle (file.get_uri ());
            } else {
                get_playlist_widget ().add_item (file);
            }
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
            var new_progress = ((duration * progress) + (double)seconds) / duration;
            playback.progress = new_progress.clamp (0.0, 1.0);
            bottom_bar.reveal_control ();
        }

        private Widgets.Playlist get_playlist_widget () {
            return bottom_bar.playlist_popover.playlist;
        }

        public void hide_popovers () {
            bottom_bar.playlist_popover.popdown ();

            var popover = bottom_bar.time_widget.preview_popover;
            if (popover != null) {
                popover.schedule_hide ();
            }
        }

        private string get_subtitle_for_uri (string uri) {
            /* This assumes that the subtitle file has the same basename as the video file but with
             * one of the subtitle extensions, and is in the same folder. */
            string without_ext;
            int last_dot = uri.last_index_of (".", 0);
            int last_slash = uri.last_index_of ("/", 0);

            if (last_dot < last_slash) {//we dont have extension
                without_ext = uri;
            } else {
                without_ext = uri.slice (0, last_dot);
            }

            foreach (string ext in SUBTITLE_EXTENSIONS) {
                string sub_uri = without_ext + "." + ext;
                if (File.new_for_uri (sub_uri).query_exists ()) {
                    return sub_uri;
                }
            }

            return "";
        }

        private bool is_subtitle (string uri) {
            if (uri.length < 4 || uri.get_char (uri.length - 4) != '.') {
                return false;
            }

            foreach (string ext in SUBTITLE_EXTENSIONS) {
                if (uri.down ().has_suffix (ext)) {
                    return true;
                }
            }

            return false;
        }

        private ulong ready_handler_id = 0;
        public void set_subtitle (string uri) {
            var progress = playback.progress;
            var is_playing = playback.playing;

            /* Temporarily connect to the ready signal so that we can restore the progress setting
             * after resetting the pipeline in order to set the subtitle uri */
            ready_handler_id = playback.ready.connect (() => {
                playback.progress = progress;
                // Pause video if it was in Paused state before adding the subtitle
                if (!is_playing) {
                    pipeline.set_state (Gst.State.PAUSED);
                }

                playback.disconnect (ready_handler_id);
            });

            pipeline.set_state (Gst.State.NULL); // Does not work otherwise
            playback.set_subtitle_uri (uri);
            pipeline.set_state (Gst.State.PLAYING);

            settings.set_string ("current-external-subtitles-uri", uri);
        }

        private bool update_pointer_position (double y, int window_height) {
            App.get_instance ().active_window.get_window ().set_cursor (null);

            bottom_bar.reveal_control ();

            return false;
        }

        [CCode (instance_pos = -1)]
        private bool navigation_event (GtkClutter.Embed embed, Clutter.Event event) {
            var video_sink = playback.get_video_sink ();
            var frame = video_sink.get_frame ();
            if (frame == null) {
                return true;
            }

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
