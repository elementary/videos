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

        private dynamic Gst.Element playbin;
        private Gtk.Widget gst_video_widget;
        private Gst.Bus bus;

        private GnomeMediaKeys mediakeys;
        private ClutterGst.Playback playback;
        private Gtk.Revealer unfullscreen_revealer;
        private uint inhibit_token = 0;

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

        private bool _playing = false;
        public bool playing {
            get {
                return _playing;
            }
            set {
                _playing = value;
                if (value) {
                    playbin.set_state (Gst.State.PLAYING);
                } else {
                    playbin.set_state (Gst.State.NULL);
                }
            }
        }

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

            var gtksink = Gst.ElementFactory.make ("gtksink", "sink");
            gtksink.get ("widget", out gst_video_widget);

            playbin = Gst.ElementFactory.make ("playbin", "bin");
            playbin.video_sink = gtksink;

            bus = playbin.get_bus ();
            bus.add_watch (0, bus_callback);
            bus.enable_sync_message_emission ();

            bottom_bar = new Widgets.BottomBar (playback) {
                //FIXME: This should use CSS
                opacity = GLOBAL_OPACITY,
                valign = Gtk.Align.END
            };
            bottom_bar.bind_property ("playing", this, "playing", BindingFlags.BIDIRECTIONAL);

            var unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Unfullscreen")
            };

            unfullscreen_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN
            };
            unfullscreen_revealer.add (unfullscreen_button);
            unfullscreen_revealer.show_all ();

            var overlay = new Gtk.Overlay ();
            overlay.add (gst_video_widget);
            overlay.add_overlay (bottom_bar);

            add (overlay);
            show_all ();

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
                            playing = !playing;
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
                    App.get_instance ().active_window.begin_move_drag (Gdk.BUTTON_PRIMARY,
                        (int)event.x_root, (int)event.y_root, event.time);
                }

                Gtk.Allocation allocation;
                // clutter.get_allocation (out allocation);
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
                unfullscreen_clicked ();
            });

            leave_notify_event.connect (event => {
                Gtk.Allocation allocation;
                // clutter.get_allocation (out allocation);

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

            //playlist wants us to open a file
            get_playlist_widget ().play.connect ((file) => {
                ((Audience.Window) App.get_instance ().active_window).open_files ({ File.new_for_uri (file.get_uri ()) });
            });

            get_playlist_widget ().stop_video.connect (() => {
                settings.set_double ("last-stopped", 0);
                settings.set_strv ("last-played-videos", {});
                settings.set_string ("current-video", "");

                /* We do not want to emit an "ended" signal if already ended - it can cause premature
                 * ending of next video and other side-effects
                 */
                if (playing) {
                    playing = false;
                    playback.progress = 1.0;
                    ended ();
                }
            });

            bottom_bar.notify["child-revealed"].connect (() => {
                if (bottom_bar.child_revealed == true) {
                    ((Audience.Window) App.get_instance ().active_window).show_mouse_cursor ();
                } else {
                    ((Audience.Window) App.get_instance ().active_window).hide_mouse_cursor ();
                }
            });

            this.notify["playing"].connect (() => {
                unowned Gtk.Application app = (Gtk.Application) GLib.Application.get_default ();
                if (playing) {
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
        }

        private bool bus_callback (Gst.Bus bus, Gst.Message message) {
            if (message.type == Gst.MessageType.EOS) {
                Idle.add (() => {
                    playback.progress = 0;
                    if (!get_playlist_widget ().next ()) {
                        if (repeat) {
                            string file = get_playlist_widget ().get_first_item ().get_uri ();
                            App.get_instance ().mainwindow.open_files ({ File.new_for_uri (file) });
                        } else {
                            playing = false;
                            settings.set_double ("last-stopped", 0);
                            ended ();
                        }
                    }
                    return false;
                });
            }

            return true;
        }

        public void play_file (string uri, bool from_beginning = true) {
            debug ("Opening %s", uri);

            playing = false;
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
            playbin.uri = uri;

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

            playing = !(settings.get_boolean ("playback-wait"));

            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);

            bottom_bar.preferences_popover.is_setup = false;

            settings.set_string ("current-video", uri);
        }

        public double get_progress () {
            return playback.progress;
        }

        public string get_played_uri () {
            return playbin.uri;
        }

        public void reset_played_uri () {
            playbin.uri = "";
        }

        public void next () {
            get_playlist_widget ().next ();
        }

        public void prev () {
            get_playlist_widget ().next (); //Is this right??
        }

        public void resume_last_videos () {
            play_file (settings.get_string ("current-video"));
            playing = false;
            if (settings.get_boolean ("resume-videos")) {
                playback.progress = settings.get_double ("last-stopped");
            } else {
                playback.progress = 0.0;
            }

            playing = !(settings.get_boolean ("playback-wait"));
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

            /* Temporarily connect to the ready signal so that we can restore the progress setting
             * after resetting the playbin in order to set the subtitle uri */
            ready_handler_id = playback.ready.connect (() => {
                playback.progress = progress;
                // Pause video if it was in Paused state before adding the subtitle
                if (!playing) {
                    playbin.set_state (Gst.State.PAUSED);
                }

                playback.disconnect (ready_handler_id);
            });

            playing = false; // Does not work otherwise
            playback.set_subtitle_uri (uri);
            playing = true;;

            settings.set_string ("current-external-subtitles-uri", uri);
        }

        public bool update_pointer_position (double y, int window_height) {
            App.get_instance ().active_window.get_window ().set_cursor (null);

            bottom_bar.reveal_control ();

            return false;
        }
    }
}
