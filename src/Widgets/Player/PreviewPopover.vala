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
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

public class Audience.Widgets.PreviewPopover : Gtk.Popover {
    public string playback_uri { get; set; }

    private enum PlayFlags {
        VIDEO = (1 << 0),
        AUDIO = (1 << 1),
        TEXT = (1 << 2),
        VIS = (1 << 3),
        SOFT_VOLUME = (1 << 4),
        NATIVE_AUDIO = (1 << 5),
        NATIVE_VIDEO = (1 << 6),
        DOWNLOAD = (1 << 7),
        BUFFERING = (1 << 8),
        DEINTERLACE = (1 << 9),
        SOFT_COLORBALANCE = (1 << 10)
    }

    private dynamic Gst.Element playbin;
    private Gdk.Paintable paintable;
    private Adw.Clamp v_clamp;
    private Adw.Clamp h_clamp;

    uint loop_timer_id = 0;
    uint show_timer_id = 0;
    uint hide_timer_id = 0;
    uint idle_id = 0;
    int64 req_position = -1;
    bool req_loop = false;

    construct {
        var gtksink = Gst.ElementFactory.make ("gtk4paintablesink", "sink");
        gtksink.get ("paintable", out paintable);

        playbin = Gst.ElementFactory.make ("playbin", "bin");
        playbin.video_sink = gtksink;

        int flags;
        playbin.get ("flags", out flags);
        flags &= ~PlayFlags.TEXT;   //disable subtitle
        flags &= ~PlayFlags.AUDIO;  //disable audio sink
        playbin.set ("flags", flags);

        var picture = new Gtk.Picture.for_paintable (paintable) {
            hexpand = true,
            vexpand = true,
            margin_top = 3,
            margin_bottom = 3,
            margin_start = 3,
            margin_end = 3
        };

        v_clamp = new Adw.Clamp () {
            child = picture,
            maximum_size = 200,
            orientation = VERTICAL
        };

        h_clamp = new Adw.Clamp () {
            child = v_clamp,
            maximum_size = 200,
            orientation = HORIZONTAL
        };

        can_focus = false;
        sensitive = false;
        autohide = false;
        position = TOP;
        child = h_clamp;

        notify["playback-uri"].connect (() => {
            playbin.uri = playback_uri;
            print ("set uri");
        });

        closed.connect (() => {
            playbin.set_state (Gst.State.NULL);
            cancel_loop_timer ();
            cancel_timer (ref show_timer_id);
            cancel_timer (ref hide_timer_id);
        });
    }

    ~PreviewPopover () {
        playbin.set_state (Gst.State.NULL);
        cancel_loop_timer ();
    }

    public void set_preview_position (int64 position, bool loop = false) {
        req_position = position;
        req_loop = loop;

        if (!visible || idle_id > 0) {
            return;
        }

        if (loop) {
            cancel_loop_timer ();
        }

        idle_id = Idle.add_full (GLib.Priority.LOW, () => {
            playbin.set_state (Gst.State.PAUSED);
            playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE, position);
            if (loop) {
                playbin.set_state (Gst.State.PLAYING);
                loop_timer_id = Timeout.add_seconds (5, () => {
                    set_preview_position (position, true);
                    loop_timer_id = 0;
                    return false;
                });
            }
            idle_id = 0;
            return false;
        });
    }

    public void update_pointing (int x) {
        var pointing = pointing_to;
        pointing.x = x;

        // changing the width properly updates arrow position when popover hits the edge
        if (pointing.width == 0) {
            pointing.width = 2;
            pointing.x -= 1;
        } else {
            pointing.width = 0;
        }

        set_pointing_to (pointing);
    }

    public void schedule_show () {
        if (show_timer_id > 0) {
            return;
        }
        cancel_timer (ref hide_timer_id);

        show_timer_id = Timeout.add (300, () => {
            var width = paintable.get_intrinsic_width ();
            var height = paintable.get_intrinsic_height ();
            if (width > 0 && height > 0) {
                double diagonal = Math.sqrt ((width * width) + (height * height));
                double k = 230 / diagonal; // for 16:9 ratio it produces width of ~200px
                v_clamp.maximum_size = (int)(height * k);
                h_clamp.maximum_size = (int)(width * k);
                print ("Diagonal: %s\n", diagonal.to_string ());
            }

            popup ();

            if (req_position >= 0) {
                set_preview_position (req_position, req_loop);
            }
            show_timer_id = 0;
            return false;
        });
    }

    public void schedule_hide () {
        if (hide_timer_id > 0) {
            return;
        }
        cancel_timer (ref show_timer_id);

        hide_timer_id = Timeout.add (300, () => {
            popdown ();
            hide_timer_id = 0;
            return false;
        });
    }

    private void cancel_loop_timer () {
        cancel_timer (ref loop_timer_id);
    }

    private void cancel_timer (ref uint timer_id) {
        if (timer_id > 0) {
            Source.remove (timer_id);
            timer_id = 0;
        }
    }
}
