// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013-2014 Audience Developers (http://launchpad.net/pantheon-chat)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Tom Beckmann <tomjonabc@gmail.com>
 *              Corentin Noël <corentin@elementaryos.org>
 */

public class Audience.Widgets.TimeWidget : Gtk.Grid {
    unowned ClutterGst.Playback main_playback;
    public Gtk.Label progression_label;
    public Gtk.Label time_label;
    public Gtk.Scale scale;
    private Audience.Widgets.PreviewPopover preview_popover;
    private bool released = true;
    private uint timeout_id = 0;
    private int original = 0;

    public TimeWidget (ClutterGst.Playback main_playback) {
        this.main_playback = main_playback;
        orientation = Gtk.Orientation.HORIZONTAL;
        column_spacing = 12;
        halign = Gtk.Align.CENTER;
        progression_label = new Gtk.Label ("");
        time_label = new Gtk.Label ("");

        main_playback.notify["progress"].connect (progress_callback);

        main_playback.notify["duration"].connect (() => {
            if (preview_popover != null) {
                preview_popover.destroy ();
            }
            time_label.label = seconds_to_time ((int) main_playback.duration);
            progress_callback ();
            // Don't allow to change the time if there is none.
            sensitive = (main_playback.duration != 0);
            if (sensitive) {
                preview_popover = new Audience.Widgets.PreviewPopover (main_playback);
                preview_popover.relative_to = this;
            }
        });

        scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1);
        scale.expand = true;
        scale.draw_value = false;
        scale.can_focus = false;
        scale.events |= Gdk.EventMask.POINTER_MOTION_MASK;
        scale.events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        scale.events |= Gdk.EventMask.ENTER_NOTIFY_MASK;
        scale.button_press_event.connect ((event) => {
            released = false;
            main_playback.notify["progress"].disconnect (progress_callback);

            if (timeout_id != 0)
                Source.remove (timeout_id);

            timeout_id = Timeout.add (300, () => {
                if (released == false)
                    return true;

                main_playback.progress = scale.get_value ();
                timeout_id = 0;

                return false;
            });

            return false;
        });

        scale.enter_notify_event.connect ((event) => {
            if (event.detail != Gdk.NotifyType.INFERIOR && event.detail != Gdk.NotifyType.NONLINEAR) {
                preview_popover.show_all ();
                return false;
            }

            return false;
        });

        scale.leave_notify_event.connect ((event) => {
            if (event.detail != Gdk.NotifyType.INFERIOR && event.detail != Gdk.NotifyType.NONLINEAR) {
                preview_popover.hide ();
                return false;
            }

            return false;
        });

        // XXX: Store the original size because the popover doesn't update his x=0 position when resizing.
        scale.motion_notify_event.connect ((event) => {
            if (original == 0)
                original = event.window.get_width ();

            var pointing = preview_popover.pointing_to;
            var distance = original - event.window.get_width ();
            pointing.x = (int)(event.x) - event.window.get_width ()/2 - distance/2;
            preview_popover.set_pointing_to ((Gdk.Rectangle)pointing);
            preview_popover.set_preview_progress (((double)event.x)/((double)event.window.get_width ()));
            return false;
        });

        scale.button_release_event.connect ((event) => {
            released = true;
            main_playback.notify["progress"].connect (progress_callback);
            return false;
        });

        add (progression_label);
        add (scale);
        add (time_label);
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);

        if (parent.get_window () == null)
            return;
        var width = parent.get_window ().get_width ();
        if (width > 0 && width >= minimum_width) {
            natural_width = width;
        }
    }

    private void progress_callback () {
        scale.set_value (main_playback.progress);
        progression_label.label = seconds_to_time ((int) (main_playback.duration * main_playback.progress));
    }
}
