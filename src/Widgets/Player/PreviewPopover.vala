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
    uint loop_timer_id = 0;
    uint show_timer_id = 0;
    uint hide_timer_id = 0;
    uint idle_id = 0;
    double req_progress = -1;
    bool req_loop = false;

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
#if VALA_0_34
        var aspect_ratio = new ClutterGst.Aspectratio ();
#else
        var aspect_ratio = ClutterGst.Aspectratio.@new ();
#endif
        ((ClutterGst.Aspectratio) aspect_ratio).paint_borders = false;
        ((ClutterGst.Content) aspect_ratio).player = playback;
        video_actor.content = aspect_ratio;
        ((ClutterGst.Content) aspect_ratio).size_change.connect ((width, height) => {
            clutter.set_size_request (200, (int)(((double) (height*200))/((double) width)));
        });

        video_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
        video_actor.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));

        stage.add_child (video_actor);
        add (clutter);

        closed.connect (() => {
            playback.playing = false;
            cancel_loop_timer ();
            cancel_timer (ref show_timer_id);
            cancel_timer (ref hide_timer_id);
        });

        hide.connect (() => {
            playback.playing = false;
            cancel_loop_timer ();
        });
    }

    ~PreviewPopover () {
        playback.playing = false;
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
            playback.playing = true;
            playback.progress = progress;
            playback.playing = loop;
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
