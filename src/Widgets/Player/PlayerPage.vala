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

    public class PlayerPage : Gtk.Box {
        private Audience.Widgets.BottomBar bottom_bar;
        private Gtk.Revealer windowcontrols_revealer;
        private Gtk.Revealer bottom_bar_revealer;

        private uint hiding_timer = 0;

        construct {
            var playback_manager = PlaybackManager.get_default ();

            var header_bar = new HeaderBar (false);

            windowcontrols_revealer = new Gtk.Revealer () {
                transition_type = SLIDE_DOWN,
                valign = START,
                child = header_bar
            };

            bottom_bar = new Widgets.BottomBar ();

            bottom_bar_revealer = new Gtk.Revealer () {
                transition_type = SLIDE_UP,
                valign = END,
                child = bottom_bar,
                hexpand = true
            };

            var picture = new Gtk.Picture.for_paintable (playback_manager.gst_video_widget) {
                hexpand = true,
                vexpand = true,
                keep_aspect_ratio = false
            };

            var overlay = new Gtk.Overlay () {
                child = picture
            };
            overlay.add_overlay (windowcontrols_revealer);
            overlay.add_overlay (bottom_bar_revealer);

            append (overlay);

            map.connect (() => update_actions_enabled (true));

            unmap.connect (() => update_actions_enabled (false));

            var motion_controller = new Gtk.EventControllerMotion ();
            add_controller (motion_controller);

            double prev_x, prev_y;
            motion_controller.motion.connect ((x, y) => {
                if (x != prev_x || y != prev_y) {
                    prev_x = x;
                    prev_y = y;
                    reveal_control ();
                }
            });

            bottom_bar.notify["should-stay-revealed"].connect (reveal_control);

            var primary_gesture_click = new Gtk.GestureClick () {
                button = Gdk.BUTTON_PRIMARY
            };
            add_controller (primary_gesture_click);
            primary_gesture_click.pressed.connect ((n_press) => {
                if (n_press == 2) {
                    activate_action (Window.ACTION_PREFIX + Window.ACTION_FULLSCREEN, null);
                }
            });

            var secondary_gesture_click = new Gtk.GestureClick () {
                button = Gdk.BUTTON_SECONDARY
            };
            add_controller (secondary_gesture_click);
            secondary_gesture_click.pressed.connect (() => {
                var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);
                ((SimpleAction) play_pause_action).activate (null);
            });
        }

        private void update_actions_enabled (bool enabled) {
            unowned var application = Application.get_default ();
            ((SimpleAction) application.lookup_action (Audience.App.ACTION_NEXT)).set_enabled (enabled);
            ((SimpleAction) application.lookup_action (Audience.App.ACTION_PLAY_PAUSE)).set_enabled (enabled);
            ((SimpleAction) application.lookup_action (Audience.App.ACTION_PREVIOUS)).set_enabled (enabled);
        }

        public void seek_jump_seconds (int seconds) {
            var playback_manager = PlaybackManager.get_default ();
            int64 new_position = playback_manager.position + (int64)seconds * (int64)1000000000;
            if (new_position < 0) {
                new_position = 0;
            }
            playback_manager.seek (new_position);
            reveal_control ();
        }

        public void hide_popovers () {
            bottom_bar.hide_popovers ();
        }

        private void reveal_control () {
            if (hiding_timer != 0) {
                Source.remove (hiding_timer);
                hiding_timer = 0;
            }

            bottom_bar_revealer.reveal_child = true;
            windowcontrols_revealer.reveal_child = true;
            set_cursor (null);

            if (bottom_bar.should_stay_revealed) {
                return;
            }

            hiding_timer = Timeout.add (2000, () => {
                hiding_timer = 0;

                windowcontrols_revealer.reveal_child = false;
                bottom_bar_revealer.reveal_child = false;
                set_cursor (new Gdk.Cursor.from_name ("none", null));

                return Source.REMOVE;
            });
        }
    }
}
