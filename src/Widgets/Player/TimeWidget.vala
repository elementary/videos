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

public class Audience.Widgets.TimeWidget : Granite.SeekBar {
    unowned ClutterGst.Playback main_playback;
    public Audience.Widgets.PreviewPopover preview_popover {get; private set;}

    public const string trough_css = """
        scale trough {
            border-radius: 12px;
            background-color: alpha (#000, 0.05);
            box-shadow: none;
            margin: 0px 0px;
            padding: 6px 6px;
            min-height: 6px;
            min-width: 5px;
        }
    """;

    public TimeWidget (ClutterGst.Playback main_playback) {
        Object (playback_duration: 0.0);

        this.main_playback = main_playback;
        main_playback.notify["progress"].connect (progress_callback);
        main_playback.notify["duration"].connect (() => {
            if (preview_popover != null) {
                preview_popover.destroy ();
            }
            playback_duration = main_playback.duration;
            progress_callback ();
            // Don't allow to change the time if there is none.
            sensitive = (main_playback.duration != 0);
            if (sensitive) {
                preview_popover = new Audience.Widgets.PreviewPopover (main_playback);
                preview_popover.relative_to = scale;
            }
        });

        var scale_css_provider = new Gtk.CssProvider ();
        try {
            scale_css_provider.load_from_data (trough_css);
            scale.get_style_context ().add_provider (scale_css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        } catch (GLib.Error e) {
            warning ("Failed to load css %s", e.message);
        }

        scale.vexpand = true;

        scale.enter_notify_event.connect ((event) => {
            preview_popover.schedule_show ();
            return false;
        });
        scale.leave_notify_event.connect ((event) => {
            preview_popover.schedule_hide ();
            return false;
        });
        scale.motion_notify_event.connect ((event) => {
            preview_popover.update_pointing ((int) event.x);
            preview_popover.set_preview_progress (event.x / ((double) event.window.get_width ()), !main_playback.playing);
            return false;
        });

        scale.button_release_event.connect ((event) => {
            main_playback.progress = scale.get_value ();
            return false;
        });

        scale.size_allocate.connect ((alloc_rect) => {
            if (preview_popover != null)
                preview_popover.realign_pointing (alloc_rect.width);
        });
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
        if (!is_grabbing) {
            playback_progress = main_playback.progress;
        }
    }
}
