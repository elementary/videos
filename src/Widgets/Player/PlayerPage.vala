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
        private Audience.Widgets.BottomBar bottom_bar;
        private Gtk.Revealer unfullscreen_revealer;

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

        construct {
            var playback_manager = PlaybackManager.get_default ();

            events |= Gdk.EventMask.POINTER_MOTION_MASK;
            events |= Gdk.EventMask.KEY_PRESS_MASK;
            events |= Gdk.EventMask.KEY_RELEASE_MASK;

            bottom_bar = new Widgets.BottomBar () {
                valign = END
            };

            var unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Unfullscreen")
            };

            unfullscreen_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,
                valign = START
            };
            unfullscreen_revealer.add (unfullscreen_button);
            unfullscreen_revealer.show_all ();

            var overlay = new Gtk.Overlay () {
                child = playback_manager.gst_video_widget
            };
            overlay.add_overlay (unfullscreen_revealer);
            overlay.add_overlay (bottom_bar);

            add (overlay);

            motion_notify_event.connect (event => {
                if (mouse_primary_down) {
                    mouse_primary_down = false;
                    App.get_instance ().active_window.begin_move_drag (Gdk.BUTTON_PRIMARY,
                        (int)event.x_root, (int)event.y_root, event.time);
                }

                Gtk.Allocation allocation;
                get_allocation (out allocation);
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
                get_allocation (out allocation);

                if (event.x == event.window.get_width ()) {
                    return update_pointer_position (event.window.get_height (), allocation.height);
                } else if (event.x == 0) {
                    return update_pointer_position (event.window.get_height (), allocation.height);
                }

                return update_pointer_position (event.y, allocation.height);
            });

            bottom_bar.notify["child-revealed"].connect (() => {
                if (bottom_bar.child_revealed == true) {
                    ((Audience.Window) App.get_instance ().active_window).show_mouse_cursor ();
                } else {
                    ((Audience.Window) App.get_instance ().active_window).hide_mouse_cursor ();
                }
            });

            show_all ();
        }

        public void seek_jump_seconds (int seconds) {
            var playback_manager = PlaybackManager.get_default ();
            playback_manager.seek (playback_manager.position + (seconds * 1000000000));
            bottom_bar.reveal_control ();
        }

        public void hide_popovers () {
            bottom_bar.playlist_popover.popdown ();

            var popover = bottom_bar.time_widget.preview_popover;
            if (popover != null) {
                popover.schedule_hide ();
            }
        }

        private bool update_pointer_position (double y, int window_height) {
            App.get_instance ().active_window.get_window ().set_cursor (null);

            bottom_bar.reveal_control ();

            return false;
        }
    }
}
