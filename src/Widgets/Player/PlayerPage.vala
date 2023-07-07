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
        private Hdy.HeaderBar header_bar;
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

                if (value) {
                    header_bar.hide ();
                } else {
                    header_bar.show ();
                }

                if (value && bottom_bar.child_revealed) {
                    unfullscreen_revealer.reveal_child = true;
                } else if (!value && bottom_bar.child_revealed) {
                    unfullscreen_revealer.reveal_child = false;
                }
            }
        }

        construct {
            var playback_manager = PlaybackManager.get_default ();

            var navigation_button = new Gtk.Button.with_label ("") {
                valign = Gtk.Align.CENTER
            };
            navigation_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

            var autoqueue_next = new Granite.ModeSwitch.from_icon_name (
                "media-playlist-repeat-one-symbolic",
                "media-playlist-consecutive-symbolic"
            ) {
                primary_icon_tooltip_text = _("Play one video"),
                secondary_icon_tooltip_text = _("Automatically play next videos"),
                valign = Gtk.Align.CENTER
            };
            settings.bind ("autoqueue-next", autoqueue_next, "active", SettingsBindFlags.DEFAULT);

            header_bar = new Hdy.HeaderBar () {
                show_close_button = true,
                title = _("Library")
            };
            header_bar.pack_start (navigation_button);
            header_bar.pack_end (autoqueue_next);
            header_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

            bottom_bar = new Widgets.BottomBar () {
                valign = END
            };

            var unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_text = _("Unfullscreen")
            };

            unfullscreen_revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,
                valign = START,
                halign = END
            };
            unfullscreen_revealer.add (unfullscreen_button);
            unfullscreen_revealer.show_all ();

            var overlay = new Gtk.Overlay () {
                child = playback_manager.gst_video_widget
            };
            overlay.add_overlay (unfullscreen_revealer);
            overlay.add_overlay (bottom_bar);

            var event_box = new Gtk.EventBox () {
                child = overlay,
                hexpand = true,
                vexpand = true
            };
            event_box.events |= Gdk.EventMask.POINTER_MOTION_MASK;
            event_box.events |= Gdk.EventMask.KEY_PRESS_MASK;
            event_box.events |= Gdk.EventMask.KEY_RELEASE_MASK;

            orientation = VERTICAL;
            add (header_bar);
            add (event_box);
            show_all ();

            map.connect (() => {
                navigation_button.label = ((Window)get_toplevel ()).get_adjacent_page_name ();
            });

            navigation_button.clicked.connect (() => {
                ((Hdy.Deck)get_ancestor (typeof (Hdy.Deck))).navigate (Hdy.NavigationDirection.BACK);
            });

            event_box.motion_notify_event.connect (event => {
                if (mouse_primary_down) {
                    mouse_primary_down = false;
                    App.get_instance ().active_window.begin_move_drag (Gdk.BUTTON_PRIMARY,
                        (int)event.x_root, (int)event.y_root, event.time);
                }

                Gtk.Allocation allocation;
                get_allocation (out allocation);
                return update_pointer_position (event.y, allocation.height);
            });

            event_box.button_press_event.connect (event => {
                if (event.button == Gdk.BUTTON_PRIMARY) {
                    mouse_primary_down = true;
                }

                return false;
            });

            event_box.button_release_event.connect (event => {
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

            event_box.leave_notify_event.connect (event => {
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
        }

        public void seek_jump_seconds (int seconds) {
            var playback_manager = PlaybackManager.get_default ();
            int64 new_position = playback_manager.position + (int64)seconds * (int64)1000000000;
            if (new_position < 0) {
                new_position = 0;
            }
            playback_manager.seek (new_position);
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
