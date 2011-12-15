/*
Audience Media Player 0.1, by Clayton Perdue and Cody Garver

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using Gtk;
using Gst;

class player_window : Gtk.Window {

    /*construct {
    
    build_data_dir = DATADIR;
    build_pkg_data_dir = PKGDATADIR;
    build_release_name = RELEASE_NAME;
    build_version = VERSION;
    build_version_info = VERSION_INFO;
    
    }*/

    private const string WINDOW_TITLE = "Audience";
    private Image PLAY_IMAGE = new Image.from_file (/*PKGDATADIR + */"/usr/share/audience" + "/style/images/play.svg");
    private Image PAUSE_IMAGE = new Image.from_file (/*PKGDATADIR + */"/usr/share/audience" + "/style/images/pause.svg");
    private DrawingArea drawing_area = new DrawingArea();
    private HBox hbox = new HBox(false, 1);
    private Pipeline pipeline = new Pipeline("pipe");
    private dynamic Element playbin = ElementFactory.make("playbin2", "playbin");
    private Label position_label = new Label("");
    private HScale progress_slider = new HScale.with_range(0, 1, 1);
    private Button play_button = new Button();
    private bool state = false;
    private bool fullscreened = false;

    public player_window(string[] args)
    {
        create_widgets();
        Timeout.add(1000, (GLib.SourceFunc) update_slide);
        Timeout.add(100, (GLib.SourceFunc) update_label);
        if (args.length > 1)
        {
            var uri = args[1];
            if (!("file://" in uri))
            {
                try 
                {
                    uri = filename_to_uri(uri);
                }
                catch (Error e)
                {
                    error ("%s", e.message);
                }
            }
            var file = File.new_for_uri(uri);
            if (!file.query_exists())
            {
                var uri_error_dialog = new MessageDialog(this, DialogFlags.MODAL, Gtk.MessageType.ERROR, ButtonsType.OK,  _("URI not valid."));
                if (uri_error_dialog.run() == ResponseType.OK) uri_error_dialog.destroy();
            }
            else create_pipeline(uri);
        }
    }
    
    public static CssProvider style_provider { get; private set; default = null; }
    
    private void create_widgets() {
    
        style_provider = new CssProvider ();
        try {
               style_provider.load_from_path (/*PKGDATADIR + */"/usr/share/audience" + "/style/default.css");
        } catch (Error e) {
               warning ("Could not add css provider. Some widgets will not look as intended. %s", e.message);
        }
        
        title = WINDOW_TITLE;

        play_button.set_image(PLAY_IMAGE);
        play_button.set_relief(Gtk.ReliefStyle.NONE);
        play_button.margin_left = 10;
        // play_button.margin_right = 10;
        play_button.margin_top = 10;
        play_button.margin_bottom = 10;
        play_button.tooltip_text = _("Play/Pause");
        play_button.can_focus = false;
        play_button.clicked.connect(on_play);
        play_button.sensitive = false;
        hbox.pack_start(play_button, false, true, 0);
        
        progress_slider.can_focus = false;
        progress_slider.set_draw_value (false);
        progress_slider.set_size_request(380, -1);
        progress_slider.margin_left = 20;
        progress_slider.margin_right = 20;
        progress_slider.margin_top = 10;
        progress_slider.margin_bottom = 10;
        progress_slider.set_range(0, 100);
        progress_slider.set_increments(0, 10);
        progress_slider.value_changed.connect(on_slide);
        
        position_label.get_style_context ().add_provider (style_provider, 600);
        position_label.name = "TimePast";
        position_label.margin_left = 10;
        position_label.margin_top = 10;
        position_label.margin_bottom = 10;
        
        hbox.pack_start(position_label, false, true, 0);
        hbox.pack_start(progress_slider, true, true, 0);
        
        Button fullscreen_button = new Button();
        fullscreen_button.set_image(new Image.from_file (/*PKGDATADIR + */"/usr/share/audience" + "/style/images/fullscreen.png"));
        fullscreen_button.set_relief(Gtk.ReliefStyle.NONE);
        // fullscreen_button.margin_left = 10;
        // fullscreen_button.margin_right = 10;
        fullscreen_button.margin_top = 10;
        fullscreen_button.margin_bottom = 10;
        fullscreen_button.tooltip_text = _("Fullscreen");
        fullscreen_button.can_focus = false;
        fullscreen_button.clicked.connect(on_fullscreen);
        hbox.pack_start(fullscreen_button, false, true, 0);
        
        Button open_button = new Button();
        open_button.set_image(new Image.from_file (/*PKGDATADIR + */"/usr/share/audience" + "/style/images/appmenu.svg"));
        open_button.set_relief(Gtk.ReliefStyle.NONE);
        open_button.margin_left = 10;
        open_button.margin_right = 10;
        open_button.margin_top = 10;
        open_button.margin_bottom = 10;
        open_button.tooltip_text = _("Open");
        open_button.can_focus = false;
        open_button.clicked.connect(on_open);
        hbox.pack_start(open_button, false, true, 0);

        Gdk.Color black;
        Gdk.Color.parse("black", out black);
        drawing_area.set_size_request(624, 352);
        drawing_area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
        drawing_area.button_press_event.connect(on_click);
        drawing_area.modify_bg(Gtk.StateType.NORMAL, black);

        VBox vbox = new VBox(false, 0);
        vbox.pack_start(drawing_area, true, true, 0);
        vbox.pack_start(hbox, false, true, 0);
        add(vbox);
        
        modify_bg(Gtk.StateType.NORMAL, black);
        
        destroy.connect (on_quit);
        show_all();
    }
    
    private int64 get_time(int which)
    {
        //which = 0: Get the current position in time
        //which = 1: Get the duration of the media
        Format fmt = Format.TIME;
        int64 pos;
        if (which == 0) pipeline.query_position(ref fmt, out pos);
        else pipeline.query_duration(ref fmt, out pos);
        return pos;
    }
    
    private void create_pipeline(string uri)
    {
        dynamic Element sink = ElementFactory.make ("xvimagesink", "sink");
        pipeline.set_state(State.READY);
        playbin.uri = uri;
        playbin.video_sink = sink;
        sink.set("force-aspect-ratio", true);
        ((XOverlay) sink).set_xwindow_id (Gdk.X11Window.get_xid (drawing_area.get_window ()));
        set_window_title (uri);
        pipeline.add(playbin);
        var bus = pipeline.get_bus();
        bus.add_watch (bus_callback);
        on_play();
    }
    
    private void update_slide()
    {
        var pos = get_time(0) / SECOND;
        var dur = get_time(1) / SECOND;
        progress_slider.value_changed.disconnect(on_slide);
        progress_slider.set_range(0, dur);
        progress_slider.set_value(pos);
        progress_slider.value_changed.connect(on_slide);
    }
    
    private void update_label()
    {
        int min = 0;
        int secs = (int) progress_slider.get_value();
        string seconds;
        while (secs >= 60)
        {
            ++min;
            secs -= 60;
        }
        if (secs < 10) seconds = "0" + secs.to_string();
        else seconds = secs.to_string();
        position_label.set_text(min.to_string() + ":" + seconds);
    }
    
    private bool bus_callback(Gst.Bus bus, Gst.Message message)
    {
        switch(message.type)
        {
            case Gst.MessageType.EOS:
                pipeline.set_state(State.READY);
                state = false;
                play_button.set_image(PLAY_IMAGE);
                play_button.sensitive = false;
                title = WINDOW_TITLE;
                break;
            default:
                break;
        }
        return true;
    }
    
    private void set_window_title (string uri) 
    {
        var path = uri.replace ("file://", "");
        string filename = Path.get_basename (path);
        var filename_split = filename.split (".");
        string window_title = "";
        for (int n = 0; n<= filename_split.length-2; n++)
            window_title += filename_split[n];
        this.title = window_title.replace ("%20", " ");
    }
    
    private void on_play()
    {
        if (state)
        {
            pipeline.set_state(State.PAUSED);
            state = false;
            play_button.set_image(PLAY_IMAGE);
        }
        else
        {
            pipeline.set_state (State.PLAYING);
            state = true;
            play_button.sensitive = true;
            play_button.set_image(PAUSE_IMAGE);
        }
    }
    
    private void on_open()
    {
        var file_chooser = new FileChooserDialog(_("Select media"), this, FileChooserAction.OPEN, Stock.CANCEL, ResponseType.CANCEL, Stock.OPEN, ResponseType.ACCEPT, null);
        if (file_chooser.run() == ResponseType.ACCEPT) 
        {
            if (state) state = false;
            create_pipeline(file_chooser.get_uri());
        }
        file_chooser.destroy();
    }
    
    private void on_slide()
    {
        int64 secs = (int64) progress_slider.get_value();
        pipeline.seek_simple(Format.TIME, SeekFlags.FLUSH | SeekFlags.ACCURATE, secs * SECOND);
    }
    
    private void on_fullscreen()
    {
        if (!fullscreened)
        {
            fullscreen();
            fullscreened = true;
            hbox.hide();
        }
        else
        {
            unfullscreen();
            fullscreened = false;
            hbox.show();
        }
    }
    
    private bool on_click()
    {
        if (fullscreened)
        {
            if (hbox.visible) hbox.hide();
            else hbox.show();
        }
        return true;
    }
    
    private void on_quit()
    {
        // Avoids memory issues
        pipeline.set_state (State.NULL);
        Gtk.main_quit ();
    }

}

int main(string[] args)
{
    Gtk.init(ref args);
    Gst.init(ref args);
    new player_window(args);
    Gtk.main();
    return 0;
}
