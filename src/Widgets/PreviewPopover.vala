
public class Audience.Widgets.PreviewPopover : Gtk.Popover {
    public Clutter.Actor preview_actor;
    dynamic Gst.Element preview_playbin;
    Clutter.Texture video;
    double ratio = 0;
    public PreviewPopover () {
        opacity = global_opacity;
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
        closed.connect (() => {preview_playbin.set_state (Gst.State.PAUSED);});
    }

    public void set_preview_uri (string uri) {
        preview_playbin.set_state (Gst.State.READY);
        preview_playbin.uri = uri;
        preview_playbin.volume = 0.0;
        
        try {
            var info = new Gst.PbUtils.Discoverer (10 * Gst.SECOND).discover_uri (uri);
            var video = info.get_video_streams ();
            if (video.data != null) {
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
        int64 length;
        preview_playbin.query_duration (Gst.Format.TIME, out length);
        preview_playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE, (int64)(double.max (progress, 0.0) * length));
        preview_playbin.set_state (Gst.State.PLAYING);
    }
}