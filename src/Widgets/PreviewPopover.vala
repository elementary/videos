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
    private enum PlayFlags {
        VIDEO         = (1 << 0),
        AUDIO         = (1 << 1),
        TEXT          = (1 << 2),
        VIS           = (1 << 3),
        SOFT_VOLUME   = (1 << 4),
        NATIVE_AUDIO  = (1 << 5),
        NATIVE_VIDEO  = (1 << 6),
        DOWNLOAD      = (1 << 7),
        BUFFERING     = (1 << 8),
        DEINTERLACE   = (1 << 9),
        SOFT_COLORBALANCE = (1 << 10)
    }

    ClutterGst.Playback playback;
    GtkClutter.Embed clutter;
    uint? timer_id = null;

    public PreviewPopover (ClutterGst.Playback main_playback) {
        opacity = GLOBAL_OPACITY;
        can_focus = false;
        sensitive = false;
        modal = false;

        playback = new ClutterGst.Playback ();
        playback.ready.connect (() => {
            unowned Gst.Element pipeline = playback.get_pipeline ();
            int flags;
            pipeline.get ("flags", out flags);
            flags &= ~PlayFlags.TEXT;   //disable subtitle
            flags &= ~PlayFlags.AUDIO;  //disable audio sink
            pipeline.set ("flags", flags);
        });

        playback.set_seek_flags (ClutterGst.SeekFlags.ACCURATE);
        playback.uri = main_playback.uri;
        playback.playing = false;
        clutter = new GtkClutter.Embed ();
        clutter.margin = 3;
        var stage = (Clutter.Stage)clutter.get_stage ();
        stage.background_color = {0, 0, 0, 0};

        var video_actor = new Clutter.Actor ();
        var aspect_ratio = ClutterGst.Aspectratio.@new ();
        ((ClutterGst.Content) aspect_ratio).player = playback;
        video_actor.content = aspect_ratio;

        video_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
        video_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));

        stage.add_child (video_actor);
        add (clutter);

        closed.connect (() => {
            playback.playing = false;
            cancel_loop_timer ();
        });
    }

    ~PreviewPopover () {
        playback.playing = false;
        cancel_loop_timer ();
    }

    public void set_preview_progress (double progress) {
        cancel_loop_timer ();
        playback.progress = progress;
        playback.playing = true;
        var frame = playback.get_frame ();
        double aspect = ((double) frame.resolution.width)/((double) frame.resolution.height);
        set_size_request (200, (int) (200.0/aspect));

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
