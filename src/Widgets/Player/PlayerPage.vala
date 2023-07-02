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
        // private Audience.Widgets.BottomBar bottom_bar;
        private Gtk.Revealer unfullscreen_revealer;
        private Gtk.Picture picture;

        private bool mouse_primary_down = false;

        private bool _fullscreened = false;
        // public bool fullscreened {
        //     get {
        //         return _fullscreened;
        //     }
        //     set {
        //         _fullscreened = value;

        //         if (value && bottom_bar.child_revealed) {
        //             unfullscreen_revealer.reveal_child = true;
        //         } else if (!value && bottom_bar.child_revealed) {
        //             unfullscreen_revealer.reveal_child = false;
        //         }
        //     }
        // }

        public PlayerPage () {
        }

        construct {
            var playback_manager = PlaybackManager.get_default ();
            var picture = new Gtk.Picture.for_paintable (playback_manager.playback);
            append (picture);

            // bottom_bar = new Widgets.BottomBar ();

            // var unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic", Gtk.IconSize.BUTTON) {
            //     tooltip_text = _("Unfullscreen")
            // };

            // unfullscreen_revealer = new Gtk.Revealer () {
            //     transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN
            // };
            // unfullscreen_revealer.set_child (unfullscreen_button);

            // bottom_actor = new GtkClutter.Actor.with_contents (bottom_bar);
            // bottom_actor.opacity = GLOBAL_OPACITY;
            // bottom_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            // bottom_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.Y_AXIS, 1));
            // stage.add_child (bottom_actor);

            // unfullscreen_actor = new GtkClutter.Actor.with_contents (unfullscreen_revealer);
            // unfullscreen_actor.opacity = GLOBAL_OPACITY;
            // unfullscreen_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.X_AXIS, 1));
            // unfullscreen_actor.add_constraint (new Clutter.AlignConstraint (stage, Clutter.AlignAxis.Y_AXIS, 0));
            // stage.add_child (unfullscreen_actor);

            // motion_notify_event.connect (event => {
            //     if (mouse_primary_down) {
            //         mouse_primary_down = false;
            //         App.get_instance ().active_window.begin_move_drag (Gdk.BUTTON_PRIMARY,
            //             (int)event.x_root, (int)event.y_root, event.time);
            //     }

            //     Gtk.Allocation allocation;
            //     clutter.get_allocation (out allocation);
            //     return update_pointer_position (event.y, allocation.height);
            // });

            // button_press_event.connect (event => {
            //     if (event.button == Gdk.BUTTON_PRIMARY) {
            //         mouse_primary_down = true;
            //     }

            //     return false;
            // });

            // button_release_event.connect (event => {
            //     if (event.button == Gdk.BUTTON_PRIMARY) {
            //         mouse_primary_down = false;
            //     }

            //     return false;
            // });

            // bottom_bar.notify["child-revealed"].connect (() => {
            //     if (bottom_bar.child_revealed && fullscreened) {
            //         unfullscreen_revealer.reveal_child = bottom_bar.child_revealed;
            //     } else if (!bottom_bar.child_revealed) {
            //         unfullscreen_revealer.reveal_child = bottom_bar.child_revealed;
            //     }
            // });

            // unfullscreen_button.clicked.connect (() => {
            //     ((Gtk.Window) get_toplevel ()).unfullscreen ();
            // });

            // leave_notify_event.connect (event => {
            //     Gtk.Allocation allocation;
            //     clutter.get_allocation (out allocation);

            //     if (event.x == event.window.get_width ()) {
            //         return update_pointer_position (event.window.get_height (), allocation.height);
            //     } else if (event.x == 0) {
            //         return update_pointer_position (event.window.get_height (), allocation.height);
            //     }

            //     return update_pointer_position (event.y, allocation.height);
            // });

            // bottom_bar.notify["child-revealed"].connect (() => {
            //     if (bottom_bar.child_revealed == true) {
            //         ((Audience.Window) App.get_instance ().active_window).show_mouse_cursor ();
            //     } else {
            //         ((Audience.Window) App.get_instance ().active_window).hide_mouse_cursor ();
            //     }
            // });

            // add (clutter);
            // show_all ();
        }

        // public void seek_jump_seconds (int seconds) {
            // var playback_manager = PlaybackManager.get_default ();
            // var duration = playback_manager.get_duration ();
            // var progress = playback_manager.get_progress ();
            // var new_progress = ((duration * progress) + (int64)seconds) / duration;
            // playback_manager.set_progress (new_progress.clamp (0.0, 1.0));
            // bottom_bar.reveal_control ();
        // }

        // public void hide_popovers () {
            // bottom_bar.playlist_popover.popdown ();

            // var popover = bottom_bar.time_widget.preview_popover;
            // if (popover != null) {
            //     popover.schedule_hide ();
            // }
        // }

        // private bool update_pointer_position (double y, int window_height) {
        //     App.get_instance ().active_window.get_window ().set_cursor (null);

        //     bottom_bar.reveal_control ();

        //     return false;
        // }

        // [CCode (instance_pos = -1)]
        // private bool navigation_event (GtkClutter.Embed embed, Clutter.Event event) {
        //     var video_sink = PlaybackManager.get_default ().playback.get_video_sink ();
        //     var frame = video_sink.get_frame ();
        //     if (frame == null) {
        //         return true;
        //     }

        //     float x, y;
        //     event.get_coords (out x, out y);
        //     // Transform event coordinates into the actor's coordinates
        //     video_actor.transform_stage_point (x, y, out x, out y);
        //     float actor_width, actor_height;
        //     video_actor.get_size (out actor_width, out actor_height);

        //     /* Convert event's coordinates into the frame's coordinates. */
        //     x = x * frame.resolution.width / actor_width;
        //     y = y * frame.resolution.height / actor_height;

        //     switch (event.type) {
        //         case Clutter.EventType.MOTION:
        //             ((Gst.Video.Navigation) video_sink).send_mouse_event ("mouse-move", 0, x, y);
        //             break;
        //         case Clutter.EventType.BUTTON_PRESS:
        //             ((Gst.Video.Navigation) video_sink).send_mouse_event ("mouse-button-press", (int)event.button.button, x, y);
        //             break;
        //         case Clutter.EventType.KEY_PRESS:
        //             warning (X.keysym_to_string (event.key.keyval));
        //             ((Gst.Video.Navigation) video_sink).send_key_event ("key-press", X.keysym_to_string (event.key.keyval));
        //             break;
        //         case Clutter.EventType.KEY_RELEASE:
        //             ((Gst.Video.Navigation) video_sink).send_key_event ("key-release", X.keysym_to_string (event.key.keyval));
        //             break;
        //     }

        //     return false;
        // }
    }
}
