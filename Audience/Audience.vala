
/*
[CCode (cname="gst_navigation_query_parse_commands_length")]
public extern bool gst_navigation_query_parse_commands_length (Gst.Query q, out uint n);
[CCode (cname="gst_navigation_query_parse_commands_nth")]
public extern bool gst_navigation_query_parse_commands_nth (Gst.Query q, uint n, out Gst.NavigationCommand cmd);
*/
namespace Audience {
    
    public Audience.Settings settings; //global space for easier access...
    
    public class App : Granite.Application {
        
        construct {
            program_name = "Audience";
            exec_name = "audience";
            
            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;
            
            app_years = "2011-2013";
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
        
        public Gtk.Window                 mainwindow;
        public Audience.Widgets.TagView   tagview;
        public GnomeMediaKeys             mediakeys;
        public Audience.Widgets.Playlist  playlist;
        public GtkClutter.Embed           clutter;
        public Granite.Widgets.Welcome    welcome;
        public Audience.Widgets.VideoPlayer video_player;
        
        public bool has_dvd;
        
        public List<string> last_played_videos; //taken from settings, but splitted
        
        public GLib.VolumeMonitor monitor;
        
        public App () {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;
            
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;
        }
        
        void build ()
        {
            playlist = new Widgets.Playlist ();
            settings = new Settings ();
            mainwindow = new Gtk.Window ();
            video_player = new Widgets.VideoPlayer ();
            tagview = new Widgets.TagView (this);

			tagview.select_external_subtitle.connect (video_player.set_subtitle_uri);
            
            var mainbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            clutter = new GtkClutter.Embed ();
            
            //prepare last played videos
            last_played_videos = new List<string> ();
            var split = settings.last_played_videos.split (",");;
            for (var i=0;i<split.length;i++){
                last_played_videos.append (split[i]);
            }
            
            has_dvd = Audience.has_dvd ();
            
            if (settings.last_folder == "-1")
                settings.last_folder = Environment.get_home_dir ();
            
            welcome = new Granite.Widgets.Welcome (_("No videos are open."), _("Select a source to begin playing."));
            welcome.append ("document-open", _("Open file"), _("Open a saved file."));
            
            //welcome.append ("internet-web-browser", _("Open a location"), _("Watch something from the infinity of the internet"));
            var filename = last_played_videos.length () > 0 ? last_played_videos.nth_data (0) : "";
			var last_file = File.new_for_uri (filename);
			if (last_file.query_exists ()) {
				welcome.append ("media-playback-start", _("Resume last video"), get_title (last_file.get_basename ()));
				welcome.set_item_visible (1, last_played_videos.length () > 0);
			}
            
            welcome.append ("media-cdrom", _("Play from Disc"), _("Watch a DVD or open a file from disc"));
            welcome.set_item_visible (2, has_dvd);
            
            var stage = clutter.get_stage ();
            
            video_player.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.WIDTH, 0));
            video_player.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, 0));
            
            stage.add_child (video_player);
            stage.add_child (tagview);
            stage.background_color = {0, 0, 0};
            
            this.tagview.y      = -10;
            this.tagview.x      = stage.width;
            this.tagview.add_constraint (new Clutter.BindConstraint (stage, Clutter.BindCoordinate.HEIGHT, -20));
            
            mainbox.pack_start (welcome);
            mainbox.pack_start (clutter);
            
            this.mainwindow.title = program_name;
            this.mainwindow.window_position = Gtk.WindowPosition.CENTER;
            this.mainwindow.set_application (this);
            this.mainwindow.add (mainbox);
            this.mainwindow.set_default_size (624, 352);
            this.mainwindow.show_all ();
            if (!settings.show_window_decoration)
                this.mainwindow.decorated = false;
            
            clutter.hide ();
            
            /*events*/
            video_player.text_tags_changed.connect (tagview.setup_text_setup);
            video_player.audio_tags_changed.connect (tagview.setup_audio_setup);
            
            //look for dvd
            this.monitor = GLib.VolumeMonitor.get ();
            monitor.drive_connected.connect ( (drive) => {
                this.has_dvd = Audience.has_dvd ();
                welcome.set_item_visible (2, this.has_dvd);
            });
            monitor.drive_disconnected.connect ( () => {
                this.has_dvd = Audience.has_dvd ();
                welcome.set_item_visible (2, this.has_dvd);
            });
            //playlist wants us to open a file
            playlist.play.connect ( (file) => {
                this.play_file (file.get_uri ());
            });
            
            //handle welcome
            welcome.activated.connect ( (index) => {
				if (filename == "" && index == 1)
					index = 2;
                switch (index) {
                case 0:
                    run_open (0);
                    break;
                case 1:
					welcome.hide ();
					clutter.show_all ();

					open_file (filename);
					
					video_player.playing = false;
					video_player.progress = double.parse (last_played_videos.nth_data (1));
					video_player.playing = true;
					break;
				case 2:
					run_open (2);
					break;
                default:
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
                        open_file (entry.text, true);
                        video_player.playing = true;
                        welcome.hide ();
                        clutter.show_all ();
                    }
                    d.destroy ();
                    break;
                }
            });
            
            //media keys
            try {
                mediakeys = Bus.get_proxy_sync (BusType.SESSION, 
                    "org.gnome.SettingsDaemon", "/org/gnome/SettingsDaemon/MediaKeys");
                mediakeys.MediaPlayerKeyPressed.connect ( (bus, app, key) => {
                    if (app != "audience")
                       return;
                    switch (key) {
                        case "Previous":
                            playlist.previous ();
                            break;
                        case "Next":
                            playlist.next ();
                            break;
                        case "Play":
                            video_player.playing = !video_player.playing;
                            break;
                        default:
                            break;
                    }
                });
                
                mediakeys.GrabMediaPlayerKeys("audience", 0);
            } catch (Error e) { warning (e.message); }
            
            //shortcuts
            this.mainwindow.key_press_event.connect ( (e) => {
                switch (e.keyval) {
                    case Gdk.Key.p:
                    case Gdk.Key.space:
                        video_player.playing = !video_player.playing;
                        break;
                    case Gdk.Key.Escape:
                        if (video_player.fullscreened)
                            toggle_fullscreen ();
                        else
                            mainwindow.destroy ();
                        break;
                    case Gdk.Key.o:
                        run_open (0);
                        break;
                    case Gdk.Key.f:
                    case Gdk.Key.F11:
                        toggle_fullscreen ();
                        break;
                    case Gdk.Key.q:
                        mainwindow.destroy ();
                        break;
                    case Gdk.Key.Left:
                        if ((video_player.progress - 0.05) < 0)
                            video_player.progress = 0.0;
                        else
                            video_player.progress -= 0.05;
                        break;
                    case Gdk.Key.Right:
                        video_player.progress += 0.05;
                        break;
                    case Gdk.Key.a:
                        next_audio ();
                        break;
                    case Gdk.Key.s:
                        next_text ();
                        break;
                    default:
                        break;
                }
                
                return true;
            });
            
            //end
            video_player.ended.connect ( () => {
                playlist.next ();
            });
            
            /*open location popover*/
            video_player.show_open_context.connect ( () => {
                var has_been_stopped = video_player.playing;
                
                video_player.playing = false;
                
                if (!has_dvd) { //just one source, so open that one
                    Timeout.add (300, () => {
                        run_open (0);
                        return false;
                    });
                    return;
                }
                
                var pop = new Granite.Widgets.PopOver ();
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                ((Gtk.Box)pop.get_content_area ()).add (box);
                
                var fil   = new Gtk.Button.with_label (_("Add from Harddrive"));
                fil.image = new Gtk.Image.from_icon_name ("document-open", Gtk.IconSize.DIALOG);
                var dvd   = new Gtk.Button.with_label (_("Play a DVD"));
                dvd.image = new Gtk.Image.from_icon_name ("media-cdrom", Gtk.IconSize.DIALOG);
                var net   = new Gtk.Button.with_label (_("Network File"));
                net.image = new Gtk.Image.from_icon_name ("internet-web-browser", Gtk.IconSize.DIALOG);
                
                fil.clicked.connect ( () => {
                    pop.destroy ();
                    run_open (0);
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
                        video_player.playing = true;
                        pop.destroy ();
                    });
                    box.remove (net);
                    box.reorder_child (entry, 2);
                    entry.show ();
                });
                
                box.pack_start (fil);
                if (has_dvd)
                    box.pack_start (dvd);
                //box.pack_start (net); uri temporary dropped
                
                /*temporary until popover closing gets fixed*/
                var canc = new Gtk.Button.from_stock (Gtk.Stock.CANCEL);
                box.pack_start (canc);
                canc.clicked.connect ( () => {
                    pop.destroy ();
                });
                
                int x_r, y_r;
                this.mainwindow.get_window ().get_origin (out x_r, out y_r);
                
                pop.move_to_coords ((int)(x_r + clutter.get_stage ().width - 50), 
                    (int)(y_r + stage.height - 18));
                
                pop.show_all ();
                
                Timeout.add (300, () => { //for some reason this doesn't cause a crash :)
                    pop.present ();
                    pop.run ();
                    pop.destroy ();
                    if (has_been_stopped)
                        video_player.playing = true;
                    
                    return false;
                });
            });

			video_player.error.connect (() => {
				welcome.show_all ();
				clutter.hide ();
			});

			video_player.plugin_install_done.connect (() => {
				clutter.show ();
				welcome.hide ();
			});
			
			video_player.notify["playing"].connect (() => {
				mainwindow.set_keep_above (video_player.playing && settings.stay_on_top);
			});
            
            video_player.exit_fullscreen.connect (toggle_fullscreen);
            
            video_player.toggle_side_pane.connect ((show) => {
                if (show) {
                    tagview.expand ();
                } else {
                    tagview.collapse ();
                }
            });
            
            video_player.configure_window.connect ((video_w, video_h) => {

				Gdk.Rectangle monitor;
				var screen = Gdk.Screen.get_default ();
				screen.get_monitor_geometry (
					screen.get_monitor_at_window (mainwindow.get_window ()),
					out monitor);

				int width = 0, height = 0;
		        if (monitor.width > video_w && monitor.height > video_h) {
					width = (int)video_w;
					height = (int)video_h;
		        } else {
					width = (int)(monitor.width * 0.9);
					height = (int)((double)video_h / video_w * width);
		        }

				var geom = Gdk.Geometry ();
		        if (settings.keep_aspect) {
		            geom.min_aspect = geom.max_aspect = video_w / (double)video_h;
		        } else {
				    geom.min_aspect = 0.0;
				    geom.max_aspect = 99999999.0;
		        }

				mainwindow.get_window ().move_resize (monitor.width / 2 - width / 2 + monitor.x,
					monitor.height / 2 - height / 2 + monitor.y,
					width, height);

				if (settings.keep_aspect) {
					mainwindow.get_window ().set_geometry_hints (geom, Gdk.WindowHints.ASPECT);
				}

            });
            
            //fullscreen on maximize
            mainwindow.window_state_event.connect ( (e) => {
                if (!((e.window.get_state () & Gdk.WindowState.MAXIMIZED) == 0) && !video_player.fullscreened){
                    mainwindow.fullscreen ();
                    video_player.fullscreened = true;
                    
                    return true;
                }
                return false;
            });
            
            //positioning
            int old_h = - 1;
            int old_w = - 1;
            mainwindow.size_allocate.connect ( (alloc) => {
                if (alloc.width != old_w || 
                    alloc.height != old_h) {
					if (video_player.relayout ()) {
						old_w = alloc.width;
						old_h = alloc.height;
					}
                }

				tagview.x = tagview.expanded ? stage.width - tagview.width + 10 : stage.width;
            });
            
            /*moving the window by drag, fullscreen for dbl-click*/
			bool down = false;
            bool moving = false;
            video_player.button_press_event.connect ( (e) => {
                if (e.click_count > 1) {
                    toggle_fullscreen ();
					down = false;
                    return true;
                } else {
                    down = true;
                    return true;
                }
            });
            clutter.motion_notify_event.connect ( (e) => {
                if (down && settings.move_window) {
					down = false;
                    moving = true;
                    mainwindow.begin_move_drag (1, 
                        (int)e.x_root, (int)e.y_root, e.time);
                    
					video_player.lock_hide ();

                    return true;
				}
                return false;
            });
            clutter.button_release_event.connect ( (e) => {
				down = false;
                return false;
            });
            mainwindow.focus_in_event.connect (() => {
                if (moving) {
					video_player.unlock_hide ();
					moving = false;
				}
				return false;
			});
            
            /*DnD*/
            Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
            Gtk.drag_dest_set (mainwindow, Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.MOVE);
            mainwindow.drag_data_received.connect ( (ctx, x, y, sel, info, time) => {
                for (var i=1;i<sel.get_uris ().length; i++)
                    playlist.add_item (File.new_for_uri (sel.get_uris ()[i]));
                open_file (sel.get_uris ()[0]);
                
                welcome.hide ();
                clutter.show_all ();
            });
            
            //save position in video when not finished playing
            mainwindow.destroy.connect ( () => {
                if (video_player.uri == null || video_player.uri == "" || video_player.uri.has_prefix ("dvd://"))
                    return;
                if (!video_player.at_end) {
                    for (var i = 0; i < last_played_videos.length (); i += 2){
                        if (video_player.uri == last_played_videos.nth_data (i)){
                            last_played_videos.nth (i+1).data = video_player.progress.to_string ();
                            save_last_played_videos ();
                            
                            return;
                        }
                    }
                    //not in list yet, insert at start
                    last_played_videos.insert (video_player.uri, 0);
                    last_played_videos.insert (video_player.progress.to_string (), 1);
                    if (last_played_videos.length () > 10) {
                        last_played_videos.delete_link (last_played_videos.nth (10));
                        last_played_videos.delete_link (last_played_videos.nth (11));
                    }
                    save_last_played_videos ();
                }
            });
        }

        public void next_audio () {
            int n_audio;
            video_player.playbin.get ("n-audio", out n_audio);
            int current = video_player.current_audio;

            if (n_audio > 1) {
                if (current < n_audio - 1) {
                    current += 1;
                } else {
                    current = 0;
                }
            }
            tagview.languages.active_id = current.to_string ();               
        }

        public void next_text () {
            int n_text;
            video_player.playbin.get ("n-text", out n_text);
            int current = int.parse (tagview.subtitles.active_id);

            if (n_text > 1) {
                if (current < n_text - 1) {
                    current  += 1;
                } else {
                    current = -1;
                }
            }           
            tagview.subtitles.active_id = current.to_string ();
        }
        
        private inline void save_last_played_videos () {
            string res = "";
            for (var i = 0; i < last_played_videos.length () - 1; i ++)
                res += last_played_videos.nth_data (i) + ",";
            
            res += last_played_videos.nth_data (last_played_videos.length () - 1);
            settings.last_played_videos = res;
        }
        
        public void run_open (int type) { //0=file, 2=dvd
            if (type == 0) {
                var file = new Gtk.FileChooserDialog (_("Open"), mainwindow, Gtk.FileChooserAction.OPEN,
                    Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL, Gtk.Stock.OPEN, Gtk.ResponseType.ACCEPT);
                file.select_multiple = true;
                
                var all_files_filter = new Gtk.FileFilter ();
                all_files_filter.set_filter_name (_("All files"));
                all_files_filter.add_pattern ("*");
                
                var video_filter = new Gtk.FileFilter ();
                video_filter.set_filter_name (_("Video files"));
                video_filter.add_mime_type ("video/*");
                
                file.add_filter (video_filter);
                file.add_filter (all_files_filter);
                
                file.set_current_folder (settings.last_folder);
                if (file.run () == Gtk.ResponseType.ACCEPT) {
                    welcome.hide ();
                    clutter.show_all ();
                    for (var i=1;i<file.get_files ().length ();i++) {
                        playlist.add_item (file.get_files ().nth_data (i));
                    }
                    open_file (file.get_uri ());
                    settings.last_folder = file.get_current_folder ();
                }
                file.destroy ();
            }else if (type == 2) {
                open_file ("dvd://", true);
                video_player.playing = true;
                
                welcome.hide ();
                clutter.show_all ();
            }
        }
        
        private void toggle_fullscreen ()
        {
            if (video_player.fullscreened) {
                mainwindow.unmaximize ();
                mainwindow.unfullscreen ();
                video_player.fullscreened = false;
            } else {
                mainwindow.fullscreen ();
                video_player.fullscreened = true;
            }
        }
        
        internal void open_file (string filename, bool dont_modify=false)
        {
            var file = File.new_for_commandline_arg (filename);
			
            if (file.query_file_type (0) == FileType.DIRECTORY) {
                Audience.recurse_over_dir (file, (file_ret) => {
                	playlist.add_item (file_ret);
                });
                file = playlist.get_first_item ();
            }
            else
                playlist.add_item (file);
            
            play_file (file.get_uri ());
        }

        public void play_file (string uri) {
            debug ("Opening %s", uri);
            video_player.uri = uri;
            
            mainwindow.title = get_title (uri);
            if (!settings.playback_wait)
                video_player.playing = true;
            
            if (settings.resume_videos) {
                int i;
                for (i = 0; i < last_played_videos.length () && i != -1; i += 2) {
                    if (video_player.uri == last_played_videos.nth_data (i))
                        break;
                    if (i == last_played_videos.length () - 1)
                        i = -1;
                }
                if (i != -1 && last_played_videos.nth_data (i + 1) != null) {
                    Idle.add (() => { video_player.progress = double.parse (last_played_videos.nth_data (i + 1)); return false;});
                    debug ("Resuming video from " + last_played_videos.nth_data (i + 1));
                }
            }
            
            Gtk.RecentManager recent_manager = Gtk.RecentManager.get_default ();
            recent_manager.add_item (uri);
            
            /*subtitles/audio tracks*/
            tagview.setup_setup ("text");
            tagview.setup_setup ("audio");
        }
        
        //the application started
        public override void activate () {
            build ();
        }
        
        //the application was requested to open some files
        public override void open (File [] files, string hint) {
            if (mainwindow == null)
            	activate ();
            
            for (var i = 1; i < files.length; i ++)
                playlist.add_item (files[i]);
            
            open_file (files[0].get_path ());
            welcome.hide ();
            clutter.show_all ();
        }
    }
}

public static void main (string [] args) {
    X.init_threads ();
    
    var err = GtkClutter.init (ref args);
    if (err != Clutter.InitError.SUCCESS) {
        error ("Could not initalize clutter! "+err.to_string ());
    }

	Gst.init (ref args);
    
    var app = new Audience.App ();
    
    app.run (args);
}

