/*-
 * Copyright 2017 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Videos.SeekBar : Gtk.Box {
    public Audience.Widgets.PreviewPopover preview_popover { get; private set; }
    public ClutterGst.Playback main_playback { get; construct; }

    private Gtk.Label progression_label;
    private Gtk.Label duration_label;
    private Gtk.Scale scale;
    private double playback_duration;
    private bool is_grabbing = false;

    public SeekBar (ClutterGst.Playback main_playback) {
        Object (main_playback: main_playback);
    }

    construct {
        get_style_context ().add_class (Granite.STYLE_CLASS_SEEKBAR);

        progression_label = new Gtk.Label (null) {
            margin_start = 3
        };

        duration_label = new Gtk.Label (null) {
            margin_end = 3
        };

        scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1) {
            hexpand = true,
            vexpand = true,
            draw_value = false,
            can_focus = false
        };
        scale.events |= Gdk.EventMask.POINTER_MOTION_MASK;
        scale.events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        scale.events |= Gdk.EventMask.ENTER_NOTIFY_MASK;

        spacing = 6;
        add (progression_label);
        add (scale);
        add (duration_label);

        progression_label.label = Granite.DateTime.seconds_to_time (0);
        scale.set_value (0.0);

        main_playback.notify["progress"].connect (() => {
            if (!is_grabbing) {
                progression_label.label = Granite.DateTime.seconds_to_time ((int) main_playback.get_position ());
                set_scale_progress (main_playback.progress);
            }
        });

        main_playback.notify["duration"].connect (() => {
            if (preview_popover != null) {
                preview_popover.destroy ();
            }

            playback_duration = main_playback.duration;
            if (playback_duration < 0.0) {
                debug ("Duration value less than zero, duration set to 0.0");
                playback_duration = 0.0;
            }

            duration_label.label = Granite.DateTime.seconds_to_time ((int) playback_duration);

            if (!is_grabbing) {
                set_scale_progress (main_playback.progress);
            }

            // Don't allow to change the time if there is none.
            sensitive = (main_playback.duration != 0);
            if (sensitive) {
                preview_popover = new Audience.Widgets.PreviewPopover (main_playback.uri);
                preview_popover.relative_to = scale;
            }
        });

        /* signal property setting */
        scale.button_press_event.connect (() => {
            is_grabbing = true;
            return false;
        });

        scale.button_release_event.connect (() => {
            is_grabbing = false;
            progression_label.label = Granite.DateTime.seconds_to_time ((int) main_playback.get_position ());
            set_scale_progress (main_playback.progress);
            return false;
        });

        scale.enter_notify_event.connect (() => {
            preview_popover.schedule_show ();
            return false;
        });

        scale.leave_notify_event.connect (() => {
            preview_popover.schedule_hide ();
            return false;
        });

        scale.motion_notify_event.connect ((event) => {
            progression_label.label = Granite.DateTime.seconds_to_time (
                (int) (scale.get_value () * playback_duration)
            );

            preview_popover.update_pointing ((int) event.x);
            preview_popover.set_preview_progress (event.x / ((double) event.window.get_width ()), !main_playback.playing);
            return false;
        });

        scale.size_allocate.connect ((alloc_rect) => {
            if (preview_popover != null)
                preview_popover.realign_pointing (alloc_rect.width);
        });

        button_release_event.connect ((event) => {
            // Manually set the slider value using the click event
            // dimensions. The slider widget doesn't set itself
            // when clicked too much above/below the slider itself.
            // This isn't necessarily a bug with the slider widget,
            // but this is the desired behavior for this slider in
            // the video player
            scale.set_value (event.x / scale.get_range_rect ().width);

            main_playback.progress = scale.get_value ();
            return false;
        });
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);

        if (parent == null) {
            return;
        }

        var window = parent.get_window ();
        if (window == null) {
            return;
        }

        var width = parent.get_window ().get_width ();
        if (width > 0 && width >= minimum_width) {
            natural_width = width;
        }
    }

    private void set_scale_progress (double progress) {
        if (progress < 0.0) {
            debug ("Progress value less than 0.0, progress set to 0.0");
            progress = 0.0;
        } else if (progress > 1.0) {
            debug ("Progress value greater than 1.0, progress set to 1.0");
            progress = 1.0;
        }

        scale.set_value (progress);
    }
}
