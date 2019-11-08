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
        public signal void unfullscreen_clicked ();
        public signal void ended ();

        private GtkClutter.Actor bottom_actor;
        private GtkClutter.Embed clutter;
        private GnomeMediaKeys mediakeys;
        private ClutterGst.Playback playback;
        private Clutter.Stage stage;
        private Gtk.Revealer unfullscreen_bar;
        private GtkClutter.Actor unfullscreen_actor;
        private Clutter.Actor video_actor;

        public Audience.Widgets.BottomBar bottom_bar {get; private set;}

        private bool mouse_primary_down = false;

        public bool repeat {
            get {
                return bottom_bar.repeat;
            }
            set {
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
                mediakeys.media_player_key_pressed.connect ((bus, app, key) => {
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

                mediakeys.grab_media_player_keys ("audience", 0);
            } catch (Error e) {
                warning (e.message);
            }

            motion_notify_event.connect (event => {
                if (mouse_primary_down && settings.get_boolean ("move-window")) {
                    mouse_primary_down = false;
                    App.get_instance ().mainwindow.begin_move_drag (Gdk.BUTTON_PRIMARY,
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
                } else {
                    settings.set_double ("last-stopped", playback.progress);
                }

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
                            settings.set_double ("last-stopped", 0);
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

            get_playlist_widget ().stop_video.connect (() => {
                playback.playing = false;
                playback.progress = 1.0;

                settings.set_double ("last-stopped", 0);
                settings.set_strv ("last-played-videos", {});
                settings.set_string ("current-video", "");

                ended ();
            });

            bottom_bar.notify["child-revealed"].connect (() => {
                if (bottom_bar.child_revealed == true) {
                    App.get_instance ().mainwindow.show_mouse_cursor ();
                } else {
                    App.get_instance ().mainwindow.hide_mouse_cursor ();
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

            string? sub_uri = get_subtitle_for_uri (uri);
            if (sub_uri != null && sub_uri != uri)
                playback.set_subtitle_uri (sub_uri);

            App.get_instance ().mainwindow.title = get_title (uri);

            if (from_beginning) {
                playback.progress = 0.0;
            } else {
                playback.progress = settings.get_double ("last-stopped");
            }

            playback.playing = !settings.get_boolean ("playback-wait");
            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);

            bottom_bar.preferences_popover.is_setup = false;

            Audience.Services.Inhibitor.get_instance ().inhibit ();
            settings.set_string ("current-video", uri);
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
            play_file (settings.get_string ("current-video"));
            playback.playing = false;
            if (settings.get_boolean ("resume-videos")) {
                playback.progress = settings.get_double ("last-stopped");
            } else {
                playback.progress = 0.0;
            }

            playback.playing = !settings.get_boolean ("playback-wait");
        }

        public void append_to_playlist (File file) {
            if (is_subtitle (file.get_uri ())) {
                set_subtitle (file.get_uri ());
            } else {
                get_playlist_widget ().add_item (file);
            }
        }

        public void play_first_in_playlist () {
            var file = get_playlist_widget ().get_first_item ();
            play_file (file.get_uri ());
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

        public Widgets.Playlist get_playlist_widget () {
            return bottom_bar.playlist_popover.playlist;
        }

        public void hide_preview_popover () {
            var popover = bottom_bar.time_widget.preview_popover;
            if (popover != null) {
                popover.schedule_hide ();
            }
        }

        private string? get_subtitle_for_uri (string uri) {
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
            return null;
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

        public void set_subtitle (string uri) {
            var progress = playback.progress;
            var is_playing = playback.playing;

            unowned Gst.Pipeline pipeline = playback.get_pipeline () as Gst.Pipeline;
            pipeline.set_state (Gst.State.NULL);
            pipeline.set ("suburi", uri, null);
            pipeline.set_state (Gst.State.PLAYING);
            Timeout.add (200, () => {
                playback.progress = progress;
                // Doesn't do anything but set value for FileChooserButton
                // without need for passing another property around.
                playback.subtitle_uri = uri;
                return false;
            });

            // Pause video if it was in Paused state before adding the subtitle
            if (!is_playing) {
                pipeline.set_state (Gst.State.PAUSED);
            }
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
