/*-
 * Copyright 2017 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Videos.SeekBar : Gtk.Box {
    // public Audience.Widgets.PreviewPopover preview_popover { get; private set; }

    private Gtk.Label progression_label;
    private Gtk.Label duration_label;
    private Gtk.Scale scale;
    private bool is_grabbing = false;

    construct {
        // add_css_class (Granite.STYLE_CLASS_SEEKBAR);

        progression_label = new Gtk.Label (Granite.DateTime.seconds_to_time (0)) {
            margin_start = 3
        };

        duration_label = new Gtk.Label (null) {
            margin_end = 3
        };

        scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null) {
            hexpand = true,
            draw_value = false,
            can_focus = false
        };

        spacing = 6;
        append (progression_label);
        append (scale);
        append (duration_label);

        var playback_manager = Audience.PlaybackManager.get_default ();

        Timeout.add (100, () => {
            if (!playback_manager.get_playing ()) {
                return Source.CONTINUE;
            }

            duration_label.label = Granite.DateTime.seconds_to_time ((int)(playback_manager.get_duration () / 1000000000));
            scale.set_range (0, (double)playback_manager.get_duration ());

            if (!is_grabbing) {
                progression_label.label = Granite.DateTime.seconds_to_time ((int)(playback_manager.get_position () / 1000000000));
                scale.set_value (playback_manager.get_position ());
            }

            return Source.CONTINUE;
        });

        scale.change_value.connect ((scroll, new_value) => {
            playback_manager.set_position ((int64)new_value);
        });

        var scale_gesture_click = new Gtk.GestureClick ();
        scale.add_controller (scale_gesture_click);

        scale_gesture_click.pressed.connect (() => {
            is_grabbing = true;
        });

        scale_gesture_click.released.connect (() => {
            is_grabbing = false;
        });

        scale_gesture_click.stopped.connect (() => {
            is_grabbing = false;
        });

        var scale_motion_controller = new Gtk.EventControllerMotion ();
        scale.add_controller (scale_motion_controller);

        // scale_motion_controller.enter.connect (() => preview_popover.schedule_show ());

        // scale_motion_controller.leave.connect (() => preview_popover.schedule_hide ());

        scale_motion_controller.motion.connect ((x, y) => {
            progression_label.label = Granite.DateTime.seconds_to_time (
                (int) (scale.get_value () / 1000000000)
            );

            // preview_popover.update_pointing ((int) x);
            // preview_popover.set_preview_progress (x / ((double) ((Gtk.Window)get_toplevel ()).get_width ()), !playback_manager.get_playing ());
        });

        // playback_manager.playback.notify["duration"].connect (() => {
        //     if (preview_popover != null) {
        //         preview_popover.destroy ();
        //     }

        //     playback_duration = playback_manager.playback.duration;
        //     if (playback_duration < 0.0) {
        //         debug ("Duration value less than zero, duration set to 0.0");
        //         playback_duration = 0.0;
        //     }

        //     duration_label.label = Granite.DateTime.seconds_to_time ((int) playback_duration);

        //     if (!is_grabbing) {
        //         scale.set_value (playback_manager.get_progress ());
        //     }

        //     // Don't allow to change the time if there is none.
        //     sensitive = (playback_manager.playback.duration != 0);
        //     if (sensitive) {
        //         preview_popover = new Audience.Widgets.PreviewPopover (playback_manager.playback.uri);
        //         preview_popover.relative_to = scale;
        //     }
        // });

        // scale.motion_notify_event.connect ((event) => {
            // progression_label.label = Granite.DateTime.seconds_to_time (
            //     (int) (scale.get_value () * playback_duration)
            // );

            // preview_popover.update_pointing ((int) event.x);
            // preview_popover.set_preview_progress (event.x / ((double) event.window.get_width ()), !playback_manager.get_playing ());
            // return false;
        // });

        // scale.size_allocate.connect ((alloc_rect) => {
        //     if (preview_popover != null)
        //         preview_popover.realign_pointing (alloc_rect.width);
        // });

        // button_release_event.connect ((event) => {
        //     // Manually set the slider value using the click event
        //     // dimensions. The slider widget doesn't set itself
        //     // when clicked too much above/below the slider itself.
        //     // This isn't necessarily a bug with the slider widget,
        //     // but this is the desired behavior for this slider in
        //     // the video player
        //     scale.set_value (event.x / scale.get_range_rect ().width);

        //     playback_manager.set_progress (scale.get_value ());
        //     return false;
        // });
    }
}
