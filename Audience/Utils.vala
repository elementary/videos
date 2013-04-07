
[DBus (name = "org.gnome.SettingsDaemon.MediaKeys")]
public interface GnomeMediaKeys : GLib.Object {
    public abstract void GrabMediaPlayerKeys (string application, uint32 time) throws GLib.IOError;
    public abstract void ReleaseMediaPlayerKeys (string application) throws GLib.IOError;
    public signal void MediaPlayerKeyPressed (string application, string key);
}

namespace Audience {
    public delegate void FuncOverDir (File file_under_dir);
    public static void recurse_over_dir (File file_to_process, FuncOverDir func) {
        if (file_to_process.query_file_type (0) == FileType.DIRECTORY) {
            try {
                var files = file_to_process.enumerate_children (FileAttribute.STANDARD_NAME, 0);
                FileInfo info;
                while ((info = files.next_file ()) != null) {
                    var file = GLib.File.new_for_uri (
                        file_to_process.get_uri ()  +"/"+info.get_name ());
                    recurse_over_dir (file,func);
                }
            } catch (Error e) { warning (e.message); }
        }
        else {
            func (file_to_process);
        }
    }
    public static string get_title (string filename) {
        var title = get_basename (filename);
        title = title.replace ("%20", " ").
            replace ("%3B", ";").
            replace ("%5B", "[").replace ("%5D", "]").replace ("%7B", "{").
            replace ("%7D", "}").replace ("_", " ").replace (".", " ").
            replace ("  ", " ").replace ("%60", "\'");
        return title;
    }

    public static string get_extension (string filename) {
        int i=0;
        for (i=filename.length;i!=0;i--) {
            if (filename [i] == '.')
                break;       
        }
        return filename.substring (i+1);
    }

    public static string get_basename (string filename) {
        int start = 0, end = 0;
        for (start=filename.length; start != 0; start--) {
            if (filename[start] == '/') {
                start ++;
                break;
            }
            if (filename[start] == '.' && end == 0)
                end = start;
        }
        return filename.substring (start, end - start);
    }

    public static string seconds_to_time (int seconds) {
        int hours = seconds / 3600;
        int minutes = (seconds % 3600) / 60;
        seconds = seconds % 60;

        string time = (hours > 0) ? hours.to_string() + ":" : "";
        time += (((hours > 0) && (minutes < 10)) ? "0" : "") + minutes.to_string() + ":";
        time += ((seconds < 10) ? "0" : "") + seconds.to_string();
        return time;
    }

    public static bool has_dvd () {
        var volume_monitor = GLib.VolumeMonitor.get ();
        var volumes = volume_monitor.get_connected_drives ();

        for (var i=0; i < volumes.length ();i++) {
            if (volumes.nth_data (i).get_name ().index_of ("DVD") != -1 &&
                volumes.nth_data (i).has_media ())
                return true;
        }

        return false;
    }

	public static dynamic Gst.Element get_clutter_sink ()
	{
#if HAS_CLUTTER_GST_1
		var sink = Gst.ElementFactory.make ("autocluttersink", "videosink");
		if (sink == null) {
			warning ("autocluttersink not available");
			sink = Gst.ElementFactory.make ("cluttersink", "videosink");
		}
#else
		var sink = Gst.ElementFactory.make ("cluttersink", "videosink");
#endif

		return sink;
	}

    /*
     * get a thumbnail from a file
     * @param file the file
     * @param position the position in the video or -1 for 5%
     * @param pixbuf gtkclutter texture to put the pixbuf in once it's ready
     * TODO appears not to load thumbs for bigger files
     **/
    /* NOT NEEDED CURRENTLY
	public static void get_thumb (File file, int64 position, GtkClutter.Texture tex) {
        //pipeline
        bool got_video = false;
        var pipe = new Gst.Pipeline ("pipeline");
        var src  = Gst.ElementFactory.make ("filesrc", "file");
        dynamic Gst.Element dec  = Gst.ElementFactory.make ("decodebin2", "dec");

        pipe.add_many (src, dec);
        src.link (dec);
        src.set ("location", file.get_path ());
        dynamic Gst.Element sink = null;
        dec.pad_added.connect ( (new_pad) => {
            if (got_video)
                return;

            var csp    = Gst.ElementFactory.make ("ffmpegcolorspace", "f");
            var scale  = Gst.ElementFactory.make ("videoscale", "s");
            var filter = Gst.ElementFactory.make ("capsfilter", "c");
                sink   = Gst.ElementFactory.make ("gdkpixbufsink", "sink");

            pipe.add_many (csp, scale, filter, sink);

            var sinkpad = csp.get_static_pad ("sink");
            new_pad.link (sinkpad);

            csp.link (scale);
            scale.link (filter);
            filter.link (sink);

            sink.set_state (Gst.State.PAUSED);
            filter.set_state (Gst.State.PAUSED);
            scale.set_state (Gst.State.PAUSED);
            csp.set_state (Gst.State.PAUSED);

            got_video = true;
        });

        pipe.get_bus ().add_signal_watch ();

        pipe.set_state (Gst.State.PAUSED);

        bool ready = false;
        pipe.get_bus ().message.connect ( (bus, msg) => {
            switch (msg.type) {
                case Gst.MessageType.ASYNC_DONE:
                    if (msg.src != pipe)
                        break;
                    var fmt = Gst.Format.TIME;
                    int64 pos;
                    pipe.query_position (fmt, out pos);
                    if (pos > 1)
                        ready = true;
                    else
                        break;
                    if (position == -1) {
                        int64 dur;
                        pipe.query_duration (fmt, out dur);
                        pipe.seek_simple (Gst.Format.TIME, Gst.SeekFlags.ACCURATE |
                            Gst.SeekFlags.FLUSH, (int64)(dur*0.5));
                    }else {
                        pipe.seek_simple (Gst.Format.TIME, Gst.SeekFlags.ACCURATE |
                            Gst.SeekFlags.FLUSH, position);
                    }
                    break;
                case Gst.MessageType.ELEMENT:
                    if (!ready)
                        break;
                    if (msg.src != sink)
                        break;
                    if (!msg.get_structure ().has_name ("prerollpixbuf") &&
                        !msg.get_structure ().has_name ("pixbuf"))
                        break;
                    var val = msg.get_structure ().get_value ("pixbuf");
                    var pixbuf = (Gdk.Pixbuf)val.dup_object ();
                    if (pixbuf == null)
                        return;
                    try {
                        tex.set_from_pixbuf (pixbuf);
                    } catch (Error e) {warning (e.message);}
                    pipe.set_state (Gst.State.NULL);
                    break;
                default:
                    break;
            }
        });

        pipe.set_state (Gst.State.PLAYING);
    }*/

    namespace Drawing {

        /**
         * Draws a popover shape
         */
        public static void cairo_popover (Cairo.Context cr, double x, double y, double width, double height,
                                          double radius, double arrow_height, double arrow_width)
        {
            double edge_width = (width - radius * 2);
            double arrow_offset = (edge_width - arrow_width) / 2;


            cr.arc (x + width - radius, y + radius, radius, Math.PI * 1.5, Math.PI * 2);
            cr.arc (x + width - radius, y + height - radius, radius, 0, Math.PI * 0.5);

            cr.arc (x + radius, y + height - radius, radius, Math.PI * 0.5, Math.PI);
            cr.arc (x + radius, y + radius, radius, Math.PI, Math.PI * 1.5);
            cr.move_to (x + radius + arrow_offset, y + height);

            cr.rel_line_to (arrow_width / 2, arrow_height);
            cr.rel_line_to (arrow_width / 2, -arrow_height);

            cr.close_path ();
        }

        /**
         * Draws a 'pill' shape (rounded rectangle with boder radius such that both ends are semicircles)
         */
        public static void cairo_pill (Cairo.Context cr, double x, double y, double width, double height) {
            Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x, y, width, height, height / 2);
        }

        /**
         * Draws a ' halfpill' shape (rounded rectangle with boder radius such that one ends is a semicircle)
         */
        public static void cairo_half_pill (Cairo.Context cr, double x, double y, double width, double height, Gtk.PositionType side) {
            double radius = height / 2;
            cr.move_to (x + radius, y);
            switch (side) {
                case Gtk.PositionType.LEFT:
                    cr.arc (x + width - radius, y + radius, radius, Math.PI * 1.5, Math.PI * 0.5);
                    cr.line_to ((int)x, y + height); // (int) required to not draw 'half' pixels (blurry)
                    cr.line_to ((int)x, y);
                    cr.line_to ((int)(x + width - radius), y);
                    break;
                case Gtk.PositionType.RIGHT:
                    cr.arc (x + radius, y + height - radius, radius, Math.PI * 0.5, Math.PI * 1.5);
                    cr.line_to ((int)(x + width), y);
                    cr.line_to ((int)(x + width), y + height);
                    cr.line_to ((int)(x + radius), y + height);
                    break;
                default:
                    assert_not_reached();
            }
            cr.close_path ();
        }


    }
}
