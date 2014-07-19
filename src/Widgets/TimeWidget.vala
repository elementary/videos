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
    public signal void slider_motion_event (Gdk.EventMotion event);

    public Gtk.Label progression_label;
    public Gtk.Label time_label;
    public Gtk.Scale scale;
    public signal void seeked (double val);
    private Audience.Widgets.PreviewPopover preview_popover;
    private bool is_seeking = false;
    private bool released = true;
    private uint timeout_id = 0;
    private int original = 0;

    public TimeWidget () {
        orientation = Gtk.Orientation.HORIZONTAL;
        column_spacing = 12;
        halign = Gtk.Align.CENTER;
        progression_label = new Gtk.Label ("");
        time_label = new Gtk.Label ("");

        scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1);
        scale.expand = true;
        scale.draw_value = false;
        scale.can_focus = false;
        scale.events |= Gdk.EventMask.POINTER_MOTION_MASK;
        scale.events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        scale.events |= Gdk.EventMask.ENTER_NOTIFY_MASK;
        scale.button_press_event.connect ((event) => {
            is_seeking = true;
            released = false;

            if (timeout_id != 0)
                Source.remove (timeout_id);

            timeout_id = Timeout.add (300, () => {
                if (released == false)
                    return true;
                seeked (scale.get_value ());
                is_seeking = false;

                timeout_id = 0;

                return false;
            });

            return false;
        });

        scale.enter_notify_event.connect ((event) => {
            preview_popover.show_all ();
            return false;
        });

        scale.leave_notify_event.connect ((event) => {
            preview_popover.hide ();
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

            slider_motion_event (event);

            return false;
        });

        scale.button_release_event.connect ((event) => {released = true; return false;});
        preview_popover = new Audience.Widgets.PreviewPopover ();
        preview_popover.relative_to = this;

        add (progression_label);
        add (scale);
        add (time_label);
    }

    public void set_preview_uri (string uri) {
        preview_popover.set_preview_uri (uri);
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

    public void set_progression_time (double current_time, double total_time) {
        if (is_seeking == true)
            return;
        scale.set_value (current_time/total_time);
        progression_label.label = seconds_to_time ((int)(current_time / 1000000000));
        time_label.label = seconds_to_time ((int)((total_time - current_time) / 1000000000));
    }
}