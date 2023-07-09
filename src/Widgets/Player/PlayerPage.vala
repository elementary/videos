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
        private Gtk.Revealer bottom_bar_revealer;

        private uint hiding_timer = 0;

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

                if (bottom_bar_revealer.child_revealed) {
                    reveal_control ();
                }
            }
        }

        construct {
            var playback_manager = PlaybackManager.get_default ();

            var navigation_button = new Gtk.Button.with_label ("") {
                valign = Gtk.Align.CENTER
            };
            navigation_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

            header_bar = new Hdy.HeaderBar () {
                show_close_button = true,
                title = _("Library")
            };
            header_bar.pack_start (navigation_button);
            header_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

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

            bottom_bar = new Widgets.BottomBar ();

            bottom_bar_revealer = new Gtk.Revealer () {
                transition_type = SLIDE_UP,
                valign = END,
                child = bottom_bar
            };

            var overlay = new Gtk.Overlay () {
                child = playback_manager.gst_video_widget
            };
            overlay.add_overlay (unfullscreen_revealer);
            overlay.add_overlay (bottom_bar_revealer);

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
                reveal_control ();

                return false;
            });

            bottom_bar.notify["should-stay-revealed"].connect (reveal_control);

            unfullscreen_button.clicked.connect (() => {
                ((Gtk.Window) get_toplevel ()).unfullscreen ();
            });
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
            ((Audience.Window) App.get_instance ().active_window).show_mouse_cursor ();
            if (fullscreened) {
                unfullscreen_revealer.reveal_child = true;
            }

            if (bottom_bar.should_stay_revealed) {
                return;
            }

            hiding_timer = Timeout.add (2000, () => {
                hiding_timer = 0;

                unfullscreen_revealer.reveal_child = false;
                bottom_bar_revealer.reveal_child = false;
                ((Audience.Window) App.get_instance ().active_window).hide_mouse_cursor ();

                return Source.REMOVE;
            });
        }
    }
}
