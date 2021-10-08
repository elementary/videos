/*-
 * Copyright 2013-2021 elementary, Inc. (https://elementary.io)
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
    public string playback_uri { get; construct; }

    private dynamic Gst.Element playbin;
    private Gtk.Widget gst_video_widget;

    private uint loop_timer_id = 0;
    private uint show_timer_id = 0;
    private uint hide_timer_id = 0;
    private uint idle_id = 0;
    private double req_progress = -1;
    private bool req_loop = false;

    public PreviewPopover (string playback_uri) {
        Object (playback_uri: playback_uri);
    }

    construct {
        can_focus = false;
        sensitive = false;
        modal = false;

        var gtksink = Gst.ElementFactory.make ("gtksink", "sink");
        gtksink.get ("widget", out gst_video_widget);

        var sink_pad = gtksink.get_static_pad ("sink");

        playbin = Gst.ElementFactory.make ("playbin", "bin");
        playbin.uri = playback_uri;
        playbin.video_sink = gtksink;

        gst_video_widget.margin = 3;

        add (gst_video_widget);

        closed.connect (() => {
            playbin.set_state (Gst.State.NULL);
            cancel_loop_timer ();
            cancel_timer (ref show_timer_id);
            cancel_timer (ref hide_timer_id);
        });

        hide.connect (() => {
            playbin.set_state (Gst.State.NULL);
            cancel_loop_timer ();
        });

        sink_pad.notify["caps"].connect (() => {
            var caps = sink_pad.get_current_caps ();
            if (caps == null) {
                return;
            }

            for (uint i = 0; i < caps.get_size (); i++) {
                unowned var structure = caps.get_structure (i);

                /* Ignore if not video */
                if (!("video" in structure.get_name ())) {
                    continue;
                }

                int width, height;
                structure.get_int ("width", out width);
                structure.get_int ("height", out height);
                double ratio = double.min (width/height, height/width);

                var vheight = Value (typeof (int));
                vheight.set_int (32);

                var vwidth = Value (typeof (int));
                vwidth.set_int ((int) (32 * ratio));

                structure.set_value ("height", vheight);
                structure.set_value ("width", vwidth);
            }
        });
    }

    ~PreviewPopover () {
        playbin.set_state (Gst.State.NULL);
        cancel_loop_timer ();
    }

    public void set_preview_progress (double progress, bool loop = false) {
        req_progress = progress;
        req_loop = loop;

        if (!visible || idle_id > 0) {
            return;
        }

        if (loop) {
            cancel_loop_timer ();
        }

        idle_id = Idle.add_full (GLib.Priority.LOW, () => {
            int64 duration = 0;
            playbin.query_duration (Gst.Format.TIME, out duration);
            playbin.set_state (Gst.State.PLAYING);
            playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH, (int64)(progress * duration));
            // playback.playing = loop;
            if (loop) {
                loop_timer_id = Timeout.add_seconds (5, () => {
                    set_preview_progress (progress, true);
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

    public void realign_pointing (int parent_width) {
        if (visible) {
            update_pointing ((int)(req_progress * parent_width));
        }
    }

    public void schedule_show () {
        if (show_timer_id > 0) {
            return;
        }
        cancel_timer (ref hide_timer_id);

        show_timer_id = Timeout.add (300, () => {
            show_all ();
            if (req_progress >= 0) {
                set_preview_progress (req_progress, req_loop);
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
            hide ();
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
