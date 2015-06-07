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
    public Clutter.Actor preview_actor;
    dynamic Gst.Element preview_playbin;
    Clutter.Texture video;
    double ratio = 0;
    uint? timer_id = null;
    public PreviewPopover () {
        opacity = GLOBAL_OPACITY;
        can_focus = false;
        sensitive = false;
        modal = false;

        // connect gstreamer stuff
        preview_playbin = Gst.ElementFactory.make ("playbin", "play");
        preview_playbin.get_bus ().add_signal_watch ();
        preview_playbin.get_bus ().message.connect ((msg) => {
            switch (msg.type) {
                case Gst.MessageType.STATE_CHANGED:
                    break;
                case Gst.MessageType.ASYNC_DONE:
                    break;
            }
        });
        video = new Clutter.Texture ();

        dynamic Gst.Element video_sink = Gst.ElementFactory.make ("cluttersink", "source");
        video_sink.texture = video;
        preview_playbin.video_sink = video_sink;
        var clutter = new GtkClutter.Embed ();
        clutter.margin = 6;
        var stage = (Clutter.Stage)clutter.get_stage ();
        stage.background_color = {0, 0, 0, 0};
        stage.use_alpha = true;

        video.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
        video.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));

        stage.add_child (video);
        add (clutter);
        //show_all ();
        closed.connect (() => {
            preview_playbin.set_state (Gst.State.PAUSED);
            cancel_loop_timer ();
        });
    }
    ~PreviewPopover () {
        preview_playbin.set_state (Gst.State.NULL);
    }

    public void set_preview_uri (string uri) {
        preview_playbin.set_state (Gst.State.READY);
        preview_playbin.uri = uri;
        int flags;
        preview_playbin.get ("flags", out flags);
        flags &= ~PlayFlags.TEXT;   //disable subtitle
        flags &= ~PlayFlags.AUDIO;  //disable audio sink
        preview_playbin.set ("flags", flags);

        try {
            var info = new Gst.PbUtils.Discoverer (10 * Gst.SECOND).discover_uri (uri);
            var video = info.get_video_streams ();
            if (video != null && video.data != null) {
                var video_info = (Gst.PbUtils.DiscovererVideoInfo)video.data;
                uint video_width = video_info.get_width ();
                uint video_height = video_info.get_height ();
                ratio = ((double) video_height) / ((double) video_width);
                set_size_request (200, (int) (ratio*200));
            }
        } catch (Error e) {
            warning (e.message);
            return;
        }
    }

    public void set_preview_progress (double progress) {
        cancel_loop_timer ();
        int64 length;
        preview_playbin.query_duration (Gst.Format.TIME, out length);
        preview_playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE, (int64)(double.max (progress, 0.0) * length));
        preview_playbin.set_state (Gst.State.PLAYING);
        timer_id = Timeout.add_seconds (5, () => {
            set_preview_progress (progress);
            return false;
        });
    }

    private void cancel_loop_timer () {
        if (timer_id != null) {
            Source.remove (timer_id);
            timer_id = null;
        }
    }
}
