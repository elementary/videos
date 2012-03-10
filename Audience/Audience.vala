
[DBus (name = "org.gnome.SettingsDaemon.MediaKeys")]
public interface GnomeMediaKeys : GLib.Object {
    public abstract void GrabMediaPlayerKeys (string application, uint32 time) throws GLib.IOError;
    public abstract void ReleaseMediaPlayerKeys (string application) throws GLib.IOError;
    public signal void MediaPlayerKeyPressed (string application, string key);
}


namespace Audience {
    
    public const int CONTROLS_HEIGHT = 32;
    
    public const string [] video = {
    "mpg",
    "flv",
    "mp4",
    "avi"
    };
    public const string [] audio = {
    "mp3",
    "ogg"
    };
    
    public static string get_title (string filename) {
        var title = get_basename (filename);
        title = title.replace ("%20", " ").
            replace ("%5B", "[").replace ("%5D", "]").replace ("%7B", "{").
            replace ("%7D", "}").replace ("_", " ").replace ("."," ").replace ("  "," ");
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
        int i=0;
        for (i=filename.length;i!=0;i--) {
            if (filename [i] == '.')
                break;
        }
        int j=0;
        for (j=filename.length;j!=0;j--) {
            if (filename[j] == '/')
                break;
        }
        return filename.substring (j + 1, i - j - 1);
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
    
    class LLabel : Gtk.Label {
        public LLabel (string label) {
            this.set_halign (Gtk.Align.START);
            this.label = label;
        }
        public LLabel.indent (string label) {
            this (label);
            this.margin_left = 10;
        }
        public LLabel.markup (string label) {
            this (label);
            this.use_markup = true;
        }
        public LLabel.right (string label) {
            this.set_halign (Gtk.Align.END);
            this.label = label;
        }
        public LLabel.right_with_markup (string label) {
            this.set_halign (Gtk.Align.END);
            this.use_markup = true;
            this.label = label;
        }
    }
    
    public class AudienceSettings : Granite.Services.Settings {
        
        public bool move_window          {get; set;}
        public bool keep_aspect          {get; set;}
        public bool show_details         {get; set;}
        public bool resume_videos        {get; set;}
        public string last_played_videos {get; set;} /*video1,time,video2,time2*/
        public string last_folder        {get; set;}
        
        public AudienceSettings () {
            base ("org.elementary.Audience");
        }
        
    }
    
    public class AudienceApp : Granite.Application {
        
        construct {
            program_name = "Audience";
            exec_name = "audience";
            
            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;
            
            app_years = "2011-2012";
            app_icon = "audience";
            app_launcher = "audience.desktop";
            application_id = "net.launchpad.audience";
            
            main_url = "https://code.launchpad.net/audience";
            bug_url = "https://bugs.launchpad.net/audience";
            help_url = "https://code.launchpad.net/audience";
            translate_url = "https://translations.launchpad.net/audience";
            
            /*about_authors = {""};
            about_documenters = {""};
            about_artists = {""};
            about_translators = "Launchpad Translators";
            about_comments = "To be determined"; */
            about_license_type = Gtk.License.GPL_3_0;
        }
        
        public ClutterGst.VideoTexture    canvas;
        public Gtk.Window                 mainwindow;
        public Audience.Widgets.TagView   tagview;
        public Audience.Widgets.Controls  controls;
        public Clutter.Stage              stage;
        public bool                       fullscreened;
        public uint                       hiding_timer;
        public GnomeMediaKeys             mediakeys;
        public AudienceSettings           settings;
        public Audience.Widgets.Playlist  playlist;
        public GtkClutter.Embed           clutter;
        public Granite.Widgets.Welcome    welcome;
        
        private float video_w;
        private float video_h;
        private bool  reached_end;
        private bool  error;
        
        public bool         playing;
        public File         current_file;
        public List<string> last_played_videos; //taken from settings, but splitted
        
        public AudienceApp () {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;
            
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;
            
            this.fullscreened = false;
            
            this.playlist   = new Audience.Widgets.Playlist ();
            this.settings   = new AudienceSettings ();
            this.canvas     = new ClutterGst.VideoTexture ();
            this.mainwindow = new Gtk.Window ();
            this.tagview    = new Audience.Widgets.TagView (this);
            
            var mainbox     = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            this.clutter    = new GtkClutter.Embed ();
            this.stage      = (Clutter.Stage)clutter.get_stage ();
            this.controls   = new Audience.Widgets.Controls ();
            
            //prepare last played videos
            this.last_played_videos = new List<string> ();
            var split = this.settings.last_played_videos.split (",");;
            for (var i=0;i<split.length;i++){
                this.last_played_videos.append (split[i]);
            }
            
            
            this.welcome = new Granite.Widgets.Welcome ("Audience", _("Watching films has never been better"));
            welcome.append ("document-open", _("Open a file"), _("Get file from your disk"));
            welcome.append ("media-cdrom", _("Watch a DVD"), _("Open a film"));
            welcome.append ("internet-web-browser", _("Open a location"), _("Watch something from the infinity of the internet"));
            
            /*UI*/
            this.canvas.reactive = true;
            this.canvas.width    = 624;
            this.canvas.height   = 352;
            
            stage.add_actor (canvas);
            stage.add_actor (tagview);
            stage.add_actor (controls.background);
            stage.add_actor (controls);
            stage.color = Clutter.Color.from_string ("#000");
            
            this.tagview.x      = stage.width;
            this.tagview.width  = 300;
            
            
            this.controls.play.set_tooltip (_("Play"));
            this.controls.open.set_tooltip (_("Open"));
            this.controls.view.set_tooltip (_("Sidebar"));
            this.controls.exit.set_tooltip (_("Leave Fullscreen"));
            
            
            mainbox.pack_start (welcome);
            mainbox.pack_start (clutter);
            
            this.mainwindow.title = program_name;
            this.mainwindow.window_position = Gtk.WindowPosition.CENTER;
            this.mainwindow.set_application (this);
            this.mainwindow.add (mainbox);
            this.mainwindow.set_default_size (624, 352);
            this.mainwindow.show_all ();
            
            clutter.hide ();
            
            /*events*/
            //playlist wants us to open a file
            playlist.play.connect ( (file) => {
                this.open_file (file.get_path ());
            });
            
            //handle welcome
            welcome.activated.connect ( (index) => {
                if (index == 0) {
                    run_open (0);
                } else if (index == 1) {
                    run_open (2);
                } else {
                    var d = new Gtk.Dialog.with_buttons (_("Open location"), 
                        this.mainwindow, Gtk.DialogFlags.MODAL, 
                        Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                        Gtk.Stock.OK,     Gtk.ResponseType.OK);
                    var grid  = new Gtk.Grid ();
                    var entry = new Gtk.Entry ();
                    
                    grid.attach (new Gtk.Image.from_icon_name ("internet-web-browser",
                        Gtk.IconSize.DIALOG), 0, 0, 1, 2);
                    grid.attach (new Gtk.Label (_("Choose location")), 1, 0, 1, 1);
                    grid.attach (entry, 1, 1, 1, 1);
                    
                    ((Gtk.Container)d.get_content_area ()).add (grid);
                    grid.show_all ();
                    
                    if (d.run () == Gtk.ResponseType.OK) {
                        open_file (entry.text);
                        canvas.get_pipeline ().set_state (Gst.State.PLAYING);
                        welcome.hide ();
                        clutter.show_all ();
                    }
                    d.destroy ();
                }
            });
            
            //check for errors on pipe's bus
            this.canvas.error.connect ( () => {
                warning ("An error occured!\n");
                this.error = true;
            });
            this.canvas.get_pipeline ().get_bus ().add_signal_watch ();
            this.canvas.get_pipeline ().get_bus ().message.connect ( () => {
                var msg = this.canvas.get_pipeline ().get_bus ().peek ();
                if (msg == null)
                    return;
                switch (msg.type) {
                    case Gst.MessageType.ERROR:
                        GLib.Error e;
                        string detail;
                        msg.parse_error (out e, out detail);
                        warning (e.message);
                        debug (detail+"\n");
                        this.canvas.get_pipeline ().set_state (Gst.State.NULL);
                        this.error = true;
                        break;
                    case Gst.MessageType.ELEMENT:
                        if (msg.get_structure () != null && 
                            Gst.is_missing_plugin_message (msg)) {
                            this.canvas.get_pipeline ().set_state (Gst.State.NULL);
                            debug ("Missing plugin\n");
                            this.error = true;
                            var detail = Gst.missing_plugin_message_get_description (msg);
                            var err = new Gtk.InfoBar.with_buttons (
                                "Do nothing", 0,
                                "Install missing plugins", 1);
                            ((Gtk.Container)err.get_content_area ()).add (new Gtk.Label (
                                "There's something missing to play this file! What now? ("+detail+")"));
                            err.message_type = Gtk.MessageType.ERROR;
                            mainbox.pack_start (err, false);
                            mainbox.reorder_child (err, 0);
                            err.show_all ();
                            
                            err.response.connect ( (id) => {
                                if (id == 1){
                                    var installer = Gst.missing_plugin_message_get_installer_detail
                                       (msg);
                                var context = new Gst.InstallPluginsContext ();
                                    Gst.install_plugins_async ({installer}, context,
                                    () => { //finished
                                        debug ("Finished plugin install\n");
                                        Gst.update_registry ();
                                        mainbox.remove (err);
                                        this.canvas.get_pipeline ().set_state (Gst.State.PLAYING);
                                    });
                                } else {
                                    mainbox.remove (err);
                                }
                            });
                        }
                        break;
                    default:
                        break;
                }
            });
            
            //media keys
            try {
                this.mediakeys = Bus.get_proxy_sync (BusType.SESSION, 
                    "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                this.mediakeys.MediaPlayerKeyPressed.connect ( (bus, app, key) => {
                    if (app != "audience")
                       return;
                    switch (key) {
                        case "Previous":
                            this.playlist.previous ();
                            break;
                        case "Next":
                            this.playlist.next ();
                            break;
                        case "Play":
                            this.toggle_play (!this.playing);
                            break;
                        default:
                            break;
                    }
                });
                this.mediakeys.GrabMediaPlayerKeys("audience", (uint32)0);
            } catch (Error e) {
                warning (e.message);
            }
            
            //shortcuts
            this.mainwindow.key_press_event.connect ( (e) => {
                switch (e.keyval) {
                    case Gdk.Key.space:
                        this.toggle_play (!this.playing);
                        break;
                    case Gdk.Key.Escape:
                        if (this.fullscreened)
                            this.toggle_fullscreen ();
                        else
                            this.mainwindow.destroy ();
                        break;
                    case Gdk.Key.o:
                        this.run_open (0);
                        break;
                    case Gdk.Key.f:
                    case Gdk.Key.F11:
                        this.toggle_fullscreen ();
                        break;
                    case Gdk.Key.q:
                        this.mainwindow.destroy ();
                        break;
                    case Gdk.Key.Left:
                        if ((this.canvas.progress - 0.05) < 0)
                            this.canvas.progress = 0.0;
                        else
                            this.canvas.progress -= 0.05;
                        break;
                    case Gdk.Key.Right:
                        this.canvas.progress += 0.05;
                        break;
                    default:
                        break;
                }
                return true;
            });
            
            //end
            this.canvas.eos.connect ( () => {
                this.reached_end = true;
                this.toggle_play (false);
                this.playlist.next ();
            });
            
            //slider
            this.controls.slider.seeked.connect ( (v) => {
                debug ("Seeked to %f", v);
                canvas.progress = v;
            });
            canvas.notify["progress"].connect ( () => {
                this.controls.slider.progress = this.canvas.progress;
                
                this.controls.current.text = seconds_to_time (
                    (int)(this.controls.slider.progress * this.canvas.duration));
                this.controls.remaining.text = "-" + seconds_to_time ((int)(canvas.duration - 
                    this.controls.slider.progress * this.canvas.duration));
            });
            
            /*slide controls back in*/
            this.mainwindow.motion_notify_event.connect ( () => {
                this.controls.hidden = false;
                if (!this.controls.slider.mouse_grabbed)
                    this.stage.cursor_visible = true;
                Gst.State state;
                canvas.get_pipeline ().get_state (out state, null, 0);
                if (state == Gst.State.PLAYING){
                    Source.remove (this.hiding_timer);
                    this.hiding_timer = GLib.Timeout.add (2000, () => {
                        this.stage.cursor_visible = false;
                        this.controls.hidden = true;
                        return false;
                    });
                }
                return false;
            });
            
            /*open location popover*/
            this.controls.open.clicked.connect ( () => {
                var pop = new Granite.Widgets.PopOver ();
                var box = new Gtk.Grid ();
                ((Gtk.Box)pop.get_content_area ()).add (box);
                
                box.row_spacing    = 5;
                box.column_spacing = 12;
                
                var fil   = new Gtk.Button.with_label (_("File"));
                var fil_i = new Gtk.Image.from_stock (Gtk.Stock.OPEN, Gtk.IconSize.DND);
                var cd    = new Gtk.Button.with_label ("CD");
                var cd_i  = new Gtk.Image.from_icon_name ("media-cdrom-audio", Gtk.IconSize.DND);
                var dvd   = new Gtk.Button.with_label ("DVD");
                var dvd_i = new Gtk.Image.from_icon_name ("media-cdrom", Gtk.IconSize.DND);
                var net   = new Gtk.Button.with_label (_("Network File"));
                var net_i = new Gtk.Image.from_icon_name ("internet-web-browser", Gtk.IconSize.DND);
                
                fil.clicked.connect ( () => {
                    pop.destroy ();
                    run_open (0);
                });
                cd.clicked.connect ( () => {
                    run_open (1);
                    pop.destroy ();
                });
                dvd.clicked.connect ( () => {
                    run_open (2);
                    pop.destroy ();
                });
                net.clicked.connect ( () => {
                    var entry = new Gtk.Entry ();
                    entry.secondary_icon_stock = Gtk.Stock.OPEN;
                    entry.icon_release.connect ( (pos, e) => {
                        open_file (entry.text);
                        canvas.get_pipeline ().set_state (Gst.State.PLAYING);
                        pop.destroy ();
                    });
                    box.remove (net);
                    box.attach (entry, 1, 3, 1, 1);
                    entry.show ();
                });
                
                box.attach (fil_i, 0, 0, 1, 1);
                box.attach (fil,   1, 0, 1, 1);
                box.attach (dvd_i, 0, 1, 1, 1);
                box.attach (dvd,   1, 1, 1, 1);
                box.attach (cd_i,  0, 2, 1, 1);
                box.attach (cd,    1, 2, 1, 1);
                box.attach (net_i, 0, 3, 1, 1);
                box.attach (net,   1, 3, 1, 1);
                
                int x_r, y_r;
                this.mainwindow.get_window ().get_origin (out x_r, out y_r);
                pop.move_to_coords ((int)(x_r + this.stage.width - 50), 
                    (int)(y_r + this.stage.height - CONTROLS_HEIGHT));
                
                pop.show_all ();
                pop.present ();
                pop.run ();
                pop.destroy ();
            });
            
            this.controls.play.clicked.connect  ( () => {toggle_play (!this.playing);});
            
            this.controls.exit.clicked.connect (toggle_fullscreen);
            
            this.controls.view.clicked.connect ( () => {
                if (!controls.showing_view){
                    tagview.expand ();
                    controls.view.set_icon ("pane-hide-symbolic", Gtk.Stock.JUSTIFY_LEFT);
                    controls.showing_view = true;
                }else{
                    tagview.collapse ();
                    controls.view.set_icon ("pane-show-symbolic", Gtk.Stock.JUSTIFY_LEFT);
                    controls.showing_view = false;
                }
            });
            
            //fullscreen on maximize
            this.mainwindow.window_state_event.connect ( (e) => {
                if (!((e.window.get_state () & Gdk.WindowState.MAXIMIZED) == 0) && !this.fullscreened){
                    this.mainwindow.fullscreen ();
                    this.fullscreened = true;
                    this.controls.show_fullscreen_button (true);
                    return true;
                }
                return false;
            });
            
            //positioning
            int old_h=0;
            int old_w=0;
            this.mainwindow.size_allocate.connect ( () => {
                if (this.mainwindow.get_allocated_width () != old_w || 
                    this.mainwindow.get_allocated_height () != old_h) {
                    if (this.current_file != null)
                        this.place ();
                    old_w = this.mainwindow.get_allocated_width  ();
                    old_h = this.mainwindow.get_allocated_height ();
                }
                return;
            });
            
            /*moving the window by drag, fullscreen for dbl-click*/
            bool moving = false;
            this.canvas.button_press_event.connect ( (e) => {
                if (e.click_count > 1) {
                    toggle_fullscreen ();
                    return true;
                } else {
                    moving = true;
                    return true;
                }
            });
            clutter.motion_notify_event.connect ( (e) => {
                if (moving && this.settings.move_window) {
                    moving = false;
                    this.mainwindow.begin_move_drag (1, 
                        (int)e.x_root, (int)e.y_root, e.time);
                    return true;
                }
                return false;
            });
            this.canvas.button_release_event.connect ( (e) => {
                moving = false;
                return false;
            });
            
            /*DnD*/
            Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (this.mainwindow, 
                Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.MOVE);
            this.mainwindow.drag_data_received.connect ( (ctx, x, y, sel, info, time) => {
                for (var i=0;i<sel.get_uris ().length; i++)
                    this.playlist.add_item (File.new_for_uri (sel.get_uris ()[i]));
                this.open_file (sel.get_uris ()[0]);
                welcome.hide ();
                clutter.show_all ();
            });
            
            //save position in video when not finished playing
            this.mainwindow.destroy.connect ( () => {
                if (!reached_end) {
                    for (var i=0;i<this.last_played_videos.length ();i+=2){
                        if (this.current_file.get_uri () == this.last_played_videos.nth_data (i)){
                            this.last_played_videos.nth (i+1).data = this.canvas.progress.to_string ();
                            this.save_last_played_videos ();
                            return;
                        }
                    }
                    //not in list yet, insert at start
                    this.last_played_videos.insert (this.current_file.get_uri (), 0);
                    this.last_played_videos.insert (this.canvas.progress.to_string (), 1);
                    if (this.last_played_videos.length () > 10) {
                        this.last_played_videos.delete_link (this.last_played_videos.nth (10));
                        this.last_played_videos.delete_link (this.last_played_videos.nth (11));
                    }
                    this.save_last_played_videos ();
                }
            });
        }
        
        private inline void save_last_played_videos () {
            string res = "";
            for (var i=0;i<this.last_played_videos.length () - 1;i++) {
                res += this.last_played_videos.nth_data (i) + ",";
            }
            res += this.last_played_videos.nth_data (this.last_played_videos.length () - 1);
            this.settings.last_played_videos = res;
        }
        
        public void run_open (int type) { //0=file, 1=cd, 2=dvd
            if (type == 0) {
                var file = new Gtk.FileChooserDialog (_("Open"), this.mainwindow, Gtk.FileChooserAction.OPEN,
                    Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                    Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
                file.select_multiple = true;
                
                var all_files_filter = new Gtk.FileFilter ();
                all_files_filter.set_filter_name (_("All files"));
                all_files_filter.add_pattern ("*");
                
                var supported_filter = new Gtk.FileFilter ();
                supported_filter.set_filter_name (_("Supported files"));
                supported_filter.add_mime_type ("video/*");
                supported_filter.add_mime_type ("audio/*");
                
                var video_filter = new Gtk.FileFilter ();
                video_filter.set_filter_name (_("Video files"));
                video_filter.add_mime_type ("video/*");
                video_filter.add_pattern ("*.ogg");
                
                var audio_filter = new Gtk.FileFilter ();
                audio_filter.set_filter_name (_("Audio files"));
                audio_filter.add_mime_type ("audio/*");
                file.add_filter (all_files_filter);
                file.add_filter (supported_filter);
                file.add_filter (video_filter);
                file.add_filter (audio_filter);
                file.set_filter (supported_filter);
                
                file.set_current_folder (this.settings.last_folder);
                if (file.run () == Gtk.ResponseType.ACCEPT) {
                    for (var i=0;i<file.get_files ().length ();i++) {
                        this.playlist.add_item (file.get_files ().nth_data (i));
                    }
                    open_file (file.get_uri ());
                    welcome.hide ();
                    clutter.show_all ();
                    this.settings.last_folder = file.get_current_folder ();
                }
                file.destroy ();
            }else if (type == 1){
                open_file ("cdda://");
                canvas.get_pipeline ().set_state (Gst.State.PLAYING);
            }else if (type == 2){
                open_file ("dvd://");
                canvas.get_pipeline ().set_state (Gst.State.PLAYING);
            }
        }
        
        private void toggle_play (bool start) {
            if (!start) {
                this.controls.show_play_button (true);
                canvas.get_pipeline ().set_state (Gst.State.PAUSED);
                Source.remove (this.hiding_timer);
                this.set_screensaver (true);
                this.playing = false;
            } else {
                if (this.reached_end) {
                    canvas.progress = 0.0;
                    this.reached_end = false;
                }
                canvas.get_pipeline ().set_state (Gst.State.PLAYING);
                this.controls.show_play_button (false);
                this.place ();
                if (this.hiding_timer != 0)
                    Source.remove (this.hiding_timer);
                this.hiding_timer = GLib.Timeout.add (2000, () => {
                    this.stage.cursor_visible = false;
                    this.controls.hidden = true;
                    return false;
                });
                this.set_screensaver (false);
                this.playing = true;
            }
        }
        
        private void toggle_fullscreen () {
            if (fullscreened) {
                this.mainwindow.unmaximize ();
                this.mainwindow.unfullscreen ();
                this.fullscreened = false;
                this.controls.show_fullscreen_button (false);
                this.place ();
            } else {
                this.mainwindow.fullscreen ();
                this.fullscreened = true;
                this.controls.show_fullscreen_button (true);
            }
        }
        
        internal void open_file (string filename) {
            this.error = false; //reset error
            this.current_file = File.new_for_commandline_arg (filename);
            this.reached_end = false;
            var uri = this.current_file.get_uri ();
            canvas.uri = uri;
            canvas.audio_volume = 1.0;
            this.controls.slider.preview.uri = uri;
            this.controls.slider.preview.audio_volume = 0.0;
            
            this.mainwindow.title = get_title (uri);
            if (this.settings.show_details)
                tagview.get_tags (uri, true);
            
            this.toggle_play (true);
            this.place (true);
            
            if (this.settings.resume_videos && !(get_extension (uri) in audio)) {
                int i;
                for (i=0;i<this.last_played_videos.length () && i!=-1;i+=2) {
                    if (this.current_file.get_uri () == this.last_played_videos.nth_data (i))
                        break;
                    if (i == this.last_played_videos.length () - 1)
                        i = -1;
                }
                if (i != -1) {
                    this.canvas.progress = double.parse (this.last_played_videos.nth_data (i + 1));
                    debug ("Resuming video from "+this.last_played_videos.nth_data (i + 1));
                }
            }
            
            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);
            
            /*disable subtitles by default*/
            dynamic Gst.Element pipe = this.canvas.get_pipeline ();
            pipe.flags ^= (1 << 2);
            
            /*subtitles/audio tracks*/
            this.tagview.setup_setup ("text");
            this.tagview.setup_setup ("audio");
        }
        
        private void place (bool resize_window = false) {
            this.tagview.height   = stage.height;
            this.tagview.x        = (this.tagview.expanded)?stage.width-this.tagview.width:stage.width;
            
            this.controls.width    = stage.width;
            this.controls.y        = stage.height - CONTROLS_HEIGHT;
            
            canvas.get_base_size (out video_w, out video_h);
            //aspect ratio handling
            if (!this.error) {
                if (stage.width < stage.height) {
                    this.canvas.height = stage.height;
                    this.canvas.width  = stage.height / video_h * video_w;
                    this.canvas.x      = (stage.width - this.canvas.width) / 2.0f;
                    this.canvas.y      = 0.0f;
                }else{
                    this.canvas.width  = stage.width;
                    this.canvas.height = stage.width / video_w *  video_h;
                    this.canvas.y      = (stage.height - this.canvas.height) / 2.0f;
                    this.canvas.x      = 0.0f;
                }
                if (video_h < 30) { //video wasn't loaded fast enough, repeat untill it is
                    Timeout.add (100, () => {
                        this.place ();
                        if (video_h < 30){
                            return true;
                        }
                        if (resize_window)
                            fit_window ();
                        return false;
                    });
                } else if (resize_window) {
                    fit_window ();
                }
            }
        }
        private void fit_window () {
            var ung = Gdk.Geometry (); /*unlock*/
            ung.min_aspect = 0.0;
            ung.max_aspect = 99999999.0;
            this.mainwindow.set_geometry_hints (this.mainwindow, ung, Gdk.WindowHints.ASPECT);
            
            if (Gdk.Screen.get_default ().width ()  > this.video_w &&
                Gdk.Screen.get_default ().height () > this.video_h) {
                this.mainwindow.resize (
                    (int)this.video_w, (int)this.video_h);
            } else {
                this.mainwindow.resize (
                    (int)(Gdk.Screen.get_default ().width () * 0.9),
                    (int)(Gdk.Screen.get_default ().height () * 0.9));
            }
            
            if (this.settings.keep_aspect) {
                var g = Gdk.Geometry (); /*lock*/
                g.min_aspect = g.max_aspect = this.video_w / this.video_h;
                this.mainwindow.set_geometry_hints (this.mainwindow, g, Gdk.WindowHints.ASPECT);
            }
        }
        
        public void set_screensaver (bool enable) {
            var xid = (ulong)Gdk.X11Window.get_xid (mainwindow.get_window ());
            try {
                if (enable) {
                    Process.spawn_command_line_sync (
                        "xdg-screensaver resume "+xid.to_string ());
                } else {
                    Process.spawn_command_line_sync (
                        "xdg-screensaver suspend "+xid.to_string ());
                }
            } catch (Error e) {warning (e.message);}
        }
        
        //the application started
        public override void activate () {
            
        }
        
        //the application was requested to open some files
        public override void open (File [] files, string hint) {
            for (var i=0;i<files.length;i++)
                this.playlist.add_item (files[i]);
            this.open_file (files[0].get_path ());
            this.welcome.hide ();
            this.clutter.show_all ();
        }
    }
}

public static void main (string [] args) {
    var err = GtkClutter.init (ref args);
    if (err != Clutter.InitError.SUCCESS) {
        error ("Could not initalize clutter! (a fallback will be available soon) "+err.to_string ());
    }
    ClutterGst.init (ref args);
    
    var app = new Audience.AudienceApp ();
    
    app.run (args);
}

