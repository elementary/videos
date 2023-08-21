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
            progression_label.label = Granite.DateTime.seconds_to_time ((int)(playback_manager.position / 1000000000));
            scale.set_value (playback_manager.position);
        });

        playback_manager.notify["duration"].connect (() => {
            playback_duration = playback_manager.duration;
            if (playback_duration < 0) {
                debug ("Duration value less than zero, duration set to 0.0");
                playback_duration = 0;
            }

            scale.set_range (0, playback_duration);
            duration_label.label = Granite.DateTime.seconds_to_time ((int)(playback_duration / 1000000000));

            scale.set_value (playback_manager.position);

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
            preview_popover.update_pointing ((int) x);
            preview_popover.set_preview_position (
                (int64)(x / scale.get_allocated_width () * playback_duration),
                !playback_manager.playing
            );
        });

        scale.change_value.connect ((scroll, new_value) => {
            playback_manager.seek ((int64)new_value);
            return true;
        });
    }
}
