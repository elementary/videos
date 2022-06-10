/*-
 * Copyright 2017 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Videos.SeekBar : Gtk.Grid {
    private double _playback_duration;
    private double _playback_progress;

    /*
     * The time of the full duration of the playback.
     */
    public double playback_duration {
        get {
            return _playback_duration;
        }
        set {
            double duration = value;
            if (duration < 0.0) {
                debug ("Duration value less than zero, duration set to 0.0");
                duration = 0.0;
            }

            _playback_duration = duration;
            duration_label.label = Granite.DateTime.seconds_to_time ((int) duration);
        }
    }

    /*
     * The progression of the playback as a decimal from 0.0 to 1.0.
     */
    public double playback_progress {
        get {
            return _playback_progress;
        }
        set {
            double progress = value;
            if (progress < 0.0) {
                debug ("Progress value less than 0.0, progress set to 0.0");
                progress = 0.0;
            } else if (progress > 1.0) {
                debug ("Progress value greater than 1.0, progress set to 1.0");
                progress = 1.0;
            }

            _playback_progress = progress;
            scale.set_value (progress);
            progression_label.label = Granite.DateTime.seconds_to_time ((int) (progress * playback_duration));
        }
    }

    /*
     * If the pointer is grabbing the scale button.
     */
    public bool is_grabbing { get; private set; default = false; }

    /*
     * If the pointer is hovering over the scale.
     */
    public bool is_hovering { get; private set; default = false; }

    /*
     * The left label that displays the time progressed.
     */
    public Gtk.Label progression_label { get; construct set; }

    /*
     * The right label that displays the total duration time.
     */
    public Gtk.Label duration_label { get; construct set; }

    /*
     * The time of the full duration of the playback.
     */
    public Gtk.Scale scale { get; construct set; }

    /*
     * Creates a new SeekBar with a fixed playback duration.
     * */
    public SeekBar (double playback_duration) {
        Object (playback_duration: playback_duration);
    }

    construct {
        column_spacing = 6;
        get_style_context ().add_class (Granite.STYLE_CLASS_SEEKBAR);

        progression_label = new Gtk.Label (null);
        duration_label = new Gtk.Label (null);
        progression_label.margin_start = duration_label.margin_end = 3;

        scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1);
        scale.hexpand = true;
        scale.draw_value = false;
        scale.can_focus = false;
        scale.events |= Gdk.EventMask.POINTER_MOTION_MASK;
        scale.events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        scale.events |= Gdk.EventMask.ENTER_NOTIFY_MASK;

        /* signal property setting */
        scale.button_press_event.connect (() => {
            is_grabbing = true;
            return false;
        });

        scale.button_release_event.connect (() => {
            is_grabbing = false;
            playback_progress = scale.get_value ();
            return false;
        });

        scale.enter_notify_event.connect (() => {
            is_hovering = true;
            return false;
        });

        scale.leave_notify_event.connect (() => {
            is_hovering = false;
            return false;
        });

        scale.motion_notify_event.connect (() => {
            playback_progress = scale.get_value ();
            return false;
        });

        add (progression_label);
        add (scale);
        add (duration_label);

        playback_progress = 0.0;
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
}
