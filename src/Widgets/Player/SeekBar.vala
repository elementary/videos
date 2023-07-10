/*-
 * Copyright 2017 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Videos.SeekBar : Gtk.Box {
    public Audience.Widgets.PreviewPopover preview_popover { get; private set; }

    private Gtk.Label progression_label;
    private Gtk.Label duration_label;
    private Gtk.Scale scale;
    private double playback_duration;
    private bool is_grabbing = false;

    construct {
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

        preview_popover = new Audience.Widgets.PreviewPopover ();
        preview_popover.set_parent (scale);

        hexpand = true;
        spacing = 6;
        append (progression_label);
        append (scale);
        append (duration_label);

        var playback_manager = Audience.PlaybackManager.get_default ();

        playback_manager.notify["position"].connect (() => {
            if (!is_grabbing) {
                progression_label.label = Granite.DateTime.seconds_to_time ((int)(playback_manager.position / 1000000000));
                scale.set_value (playback_manager.position);
            }
        });

        playback_manager.notify["duration"].connect (() => {
            playback_duration = playback_manager.duration;
            if (playback_duration < 0) {
                debug ("Duration value less than zero, duration set to 0.0");
                playback_duration = 0;
            }

            scale.set_range (0, playback_duration);
            duration_label.label = Granite.DateTime.seconds_to_time ((int)(playback_duration / 1000000000));

            if (!is_grabbing) {
                scale.set_value (playback_manager.position);
            }

            // Don't allow to change the time if there is none.
            sensitive = (playback_duration > 0);
            if (sensitive) {
                preview_popover.playback_uri = playback_manager.get_uri ();
            }
        });

        var scale_motion_controller = new Gtk.EventControllerMotion ();
        scale.add_controller (scale_motion_controller);

        scale_motion_controller.enter.connect (preview_popover.schedule_show);

        scale_motion_controller.leave.connect (preview_popover.schedule_hide);

        scale_motion_controller.motion.connect ((x, y) => {
            progression_label.label = Granite.DateTime.seconds_to_time (
                (int) (scale.get_value () / 1000000000)
            );

            preview_popover.update_pointing ((int) x);
            preview_popover.set_preview_position (
                (int64)(x / scale.get_range_rect ().width * playback_duration),
                !playback_manager.playing
            );
        });

        var scale_button_press_controller = new Gtk.GestureClick () {
            button = Gdk.BUTTON_PRIMARY
        };
        scale.add_controller (scale_button_press_controller);

        scale_button_press_controller.pressed.connect (() => {
            is_grabbing = true;
        });

        scale_button_press_controller.released.connect ((n_press, x, y) => {
            // Manually set the slider value using the click event
            // dimensions. The slider widget doesn't set itself
            // when clicked too much above/below the slider itself.
            // This isn't necessarily a bug with the slider widget,
            // but this is the desired behavior for this slider in
            // the video player. Also this makes sure the PreviewPopover
            // and the actual seek position are in sync.
            scale.set_value (x / scale.get_range_rect ().width * playback_duration);

            playback_manager.seek ((int64)scale.get_value ());

            is_grabbing = false;
        });

        scale_button_press_controller.stopped.connect (() => {
            is_grabbing = false;
        });
    }
}
