using Clutter;

enum PlayFlags {
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

namespace Audience.Widgets {
    public class VideoPlayer : Actor {
        public bool at_end;

        bool _playing;
        public bool playing {
            get {
                return _playing;
            }
            set {
                if (value == playing)
                    return;

                set_screensaver (!value);
                set_screenlock (!value);
                playbin.set_state (value ? Gst.State.PLAYING : Gst.State.PAUSED);
                _playing = value;
            }
        }

        public double progress {
            get {
                int64 length, prog;
                playbin.query_duration (Gst.Format.TIME, out length);
                playbin.query_position (Gst.Format.TIME, out prog);
                if (length == 0)
                    return 0;

                return prog / (double)length;
            }
            set {
                int64 length;
                playbin.query_duration (Gst.Format.TIME, out length);
                playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE, (int64)(double.max (value, 0.0) * length));
            }
        }

        public double volume {
            get {
                return playbin.volume;
            }
            set {
                playbin.volume = value;
            }
        }

        public string uri {
            owned get {
                return playbin.current_uri;
            }
            set {
                if (value == (string)playbin.uri)
                    return;

                try {
                    var info = new Gst.PbUtils.Discoverer (10 * Gst.SECOND).discover_uri (value);
                    var video = info.get_video_streams ();
                    if (video.data != null) {
                        var video_info = (Gst.PbUtils.DiscovererVideoInfo)video.data;
                        video_width = video_info.get_width ();
                        video_height = video_info.get_height ();
                    }
                } catch (Error e) {
                    error ();
                    warning (e.message);
                    return;
                }

                intial_relayout = true;
                playing = false;
                playbin.set_state (Gst.State.READY);
                playbin.suburi = null;
                subtitle_uri = null;
                playbin.uri = value;
                volume = 1.0;
                at_end = false;

                relayout ();
                playing = true;
            }
        }

        public int current_audio {
            get {
                return playbin.current_audio;
            }
            set {
                playbin.current_audio = value;
            }
        }

        string? subtitle_uri = null;

        // currently used text stream. Set to -1 to disable subtitles
        public int current_text {
            get {
                return playbin.current_text;
            }
            set {
                if (value == current_text)
                    return;

                int flags;
                playbin.get ("flags", out flags);

                var disable = value < 0;
                if (disable)
                    playbin.current_text = -1;

                check_text_layer (!disable);
                if (!disable) {
                    playbin.current_text = value;
                }
            }
        }

        public dynamic Gst.Element playbin;
        Clutter.Texture video;
        TopPanel panel;

        uint video_width;
        uint video_height;

        public GnomeSessionManager session_manager;
        uint32 inhibit_cookie;
        
        public bool fullscreened { get; set; }
        
        public signal void ended ();
        public signal void toggle_side_pane (bool show);
        public signal void text_tags_changed ();
        public signal void audio_tags_changed ();
        public signal void show_open_context ();
        public signal void exit_fullscreen ();
        public signal void error ();
        public signal void plugin_install_done ();
        public signal void configure_window (uint video_w, uint video_h);
        public signal void progression_changed (double current_time, double total_time);
        
        public VideoPlayer () {
            panel = new TopPanel ();

            video = new Clutter.Texture ();

            var video_sink = Audience.get_clutter_sink ();
            video_sink.texture = video;

            playbin = Gst.ElementFactory.make ("playbin", "playbin");
            playbin.video_sink = video_sink;

            add_child (video);
            add_child (panel);
            Timeout.add (100, () => {
                int64 length, prog;
                playbin.query_position (Gst.Format.TIME, out prog);
                playbin.query_duration (Gst.Format.TIME, out length);
                if (length == 0)
                    return true;

                progression_changed ((double)prog, (double)length);
                return true;
            });

            notify["fullscreened"].connect (() => {
                panel.hidden = !fullscreened;
            });

            panel.unfullscreen.connect (() => {
                exit_fullscreen ();
            });

            panel.vol.value_changed.connect ( (value) => {
                volume = value;
            });

            panel.vol.value = 1.0;

            playbin.about_to_finish.connect (() => {
                at_end = true;
                ended ();
            });

            playbin.text_tags_changed.connect ((el) => {
                var structure = new Gst.Structure.empty ("tags-changed");
                structure.set_value ("type", "text");
                el.post_message (new Gst.Message.application (el, (owned) structure));
            });

            playbin.audio_tags_changed.connect ((el) => {
                var structure = new Gst.Structure.empty ("tags-changed");
                structure.set_value ("type", "audio");
                el.post_message (new Gst.Message.application (el, (owned) structure));
            });

            playbin.get_bus ().add_signal_watch ();
            playbin.get_bus ().message.connect (watch);
        }

        void watch () {
            var msg = playbin.get_bus ().peek ();
            if (msg == null)
                return;

            switch (msg.type) {
                case Gst.MessageType.APPLICATION:
                    if (msg.get_structure ().get_name () == "tags-changed") {
                        if (msg.get_structure ().get_string ("type") == "text")
                            text_tags_changed ();
                        else
                            audio_tags_changed ();
                    }
                    break;
                case Gst.MessageType.ERROR:
                    GLib.Error e; string detail;
                    msg.parse_error (out e, out detail);
                    playbin.set_state (Gst.State.NULL);
                    
                    warning (detail);
                    
                    show_error (e.message);
                    break;
                case Gst.MessageType.EOS:
                    playbin.set_state (Gst.State.READY);
                    break;
                case Gst.MessageType.ELEMENT:
                    if (msg.get_structure () == null)
                        break;
                    
                    if (Gst.PbUtils.is_missing_plugin_message (msg)) {
                        error ();
                        playbin.set_state (Gst.State.NULL);
                        
                        handle_missing_plugin (msg);
                    /*TODO } else { //may be navigation command
                        var nav_msg = Gst.Navigation.message_get_type (msg);
                        
                        if (nav_msg == Gst.NavigationMessageType.COMMANDS_CHANGED) {
                            var q = Gst.Navigation.query_new_commands ();
                            pipeline.query (q);
                            
                            uint n;
                            gst_navigation_query_parse_commands_length (q, out n);
                            for (var i=0;i<n;i++) {
                                Gst.NavigationCommand cmd;
                                gst_navigation_query_parse_commands_nth (q, 0, out cmd);
                                debug ("Got command: %i", (int)cmd);
                            }
                        }*/
                    }
                    break;
                default:
                    break;
            }
        }

        public void set_subtitle_uri (string? uri) {
            subtitle_uri = uri;
            if (!check_text_layer (subtitle_uri != null))
                apply_subtitles ();
        }

        // checks whether text layer has to be enabled
        // returns if apply_subtitles has been called
        bool check_text_layer (bool enable) {
            int flags;
            playbin.get ("flags", out flags);

            if (!enable && (flags & PlayFlags.TEXT) > 0) {
                flags &= ~PlayFlags.TEXT;
                playbin.set ("flags", flags);
            } else if (enable && (flags & PlayFlags.TEXT) < 1) {
                flags |= PlayFlags.TEXT;
                playbin.set ("flags", flags);
                apply_subtitles ();
                return true;
            }

            return false;
        }

        // ported from totem bvw widget set_subtitle_uri
        void apply_subtitles () {
            int64 time;
            playbin.query_position (Gst.Format.TIME, out time);

            playbin.get_state (null, null, Gst.CLOCK_TIME_NONE);

            Gst.State current;
            playbin.get_state (out current, null, Gst.CLOCK_TIME_NONE);
            if (current > Gst.State.READY) {
                playbin.set_state (Gst.State.READY);
                playbin.get_state (null, null, Gst.CLOCK_TIME_NONE);
            }

            playbin.suburi = subtitle_uri;
            if (current > Gst.State.READY) {
                playbin.set_state (current);
                playbin.get_state (null, null, Gst.CLOCK_TIME_NONE);
            }

            playbin.set_state (Gst.State.PAUSED);
            playbin.seek (1.0, Gst.Format.TIME,
                    Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE,
                    Gst.SeekType.SET, time,
                    Gst.SeekType.NONE, (int64)Gst.CLOCK_TIME_NONE);

            if (current > Gst.State.READY) {
                playbin.set_state (current);
                playbin.get_state (null, null, Gst.CLOCK_TIME_NONE);
            }
        }

        bool intial_relayout = false;
        public bool relayout () {
            if (video_width < 1 || video_height < 1 || uri == null)
                return false;

            if (intial_relayout) {
                configure_window (video_width, video_height);
                intial_relayout = false;
            }

            var stage = get_stage ();
            var aspect = stage.width / video_width < stage.height / video_height ?
                stage.width / video_width : stage.height / video_height;
            video.width  = video_width * aspect;
            video.height = video_height * aspect;
            video.x = (stage.width  - video.width)  / 2;
            video.y = (stage.height - video.height) / 2;

            return true;
        }

        void show_error (string? message=null) {
            var dlg  = new Gtk.Dialog.with_buttons (_("Error"), null, Gtk.DialogFlags.MODAL, Gtk.Stock.OK, Gtk.ResponseType.OK);
            var grid = new Gtk.Grid ();
            var err  = new Gtk.Image.from_stock (Gtk.Stock.DIALOG_ERROR, Gtk.IconSize.DIALOG);

            err.margin_right = 12;
            grid.margin = 12;
            grid.attach (err, 0, 0, 1, 1);
            grid.attach (new Widgets.LLabel.markup ("<b>%s</b>".printf (_("Oops! Audience can't play this file!"))), 1, 0, 1, 1);
            if (message != null)
                grid.attach (new Widgets.LLabel (message), 1, 1, 1, 2);

            error ();
            ((Gtk.Box)dlg.get_content_area ()).add (grid);
            dlg.show_all ();
            dlg.run ();
            dlg.destroy ();
        }

        void handle_missing_plugin (Gst.Message msg) {
            var detail = Gst.PbUtils.missing_plugin_message_get_description (msg);
            var dlg = new Gtk.Dialog.with_buttons ("Missing plugin", null, Gtk.DialogFlags.MODAL);
            var grid = new Gtk.Grid ();
            var err  = new Gtk.Image.from_stock (Gtk.Stock.DIALOG_ERROR, Gtk.IconSize.DIALOG);
            var phrase = new Widgets.LLabel (_("Some media files need extra software to be played. Audience can install this software automatically."));

            err.margin_right = 12;
            grid.margin = 12;
            grid.attach (err, 0, 0, 1, 1);
            grid.attach (new Widgets.LLabel.markup ("<b>%s</b>".printf (_("Audience needs %s to play this file.").printf (detail))), 1, 0, 1, 1);
            grid.attach (phrase, 1, 1, 1, 2);

            dlg.add_button (_("Don't install"), 1);
            dlg.add_button (_("Install")+" "+detail, 0);

            (dlg.get_content_area () as Gtk.Container).add (grid);
            dlg.show_all ();
            if (dlg.run () == 0) {
                var installer = Gst.PbUtils.missing_plugin_message_get_installer_detail (msg);
                var context = new Gst.PbUtils.InstallPluginsContext ();
                Gst.PbUtils.install_plugins_async ({installer}, context, () => { //finished
                    debug ("Finished plugin install");
                    Gst.update_registry ();
                    plugin_install_done ();
                    playing = true;
                });
            }

            dlg.destroy ();
        }

        //TODO: Remove X Dependency!
        //store the default values for setting back
        X.Display dpy; int timeout = -1; int interval; int prefer_blanking; int allow_exposures;
        void set_screensaver (bool enable) {
            if (dpy == null)
                dpy = new X.Display ();

            if (timeout == -1)
                dpy.get_screensaver (out timeout, out interval, out prefer_blanking, out allow_exposures);

            dpy.set_screensaver (enable ? timeout : 0, interval, prefer_blanking, allow_exposures);
        }

        //prevent screenlocking in Gnome 3 using org.gnome.SessionManager
        void set_screenlock (bool enable) {
            try {
                session_manager = Bus.get_proxy_sync (BusType.SESSION, 
                        "org.gnome.SessionManager", "/org/gnome/SessionManager");
                if (enable) {
                    session_manager.Uninhibit (inhibit_cookie);
                } else {
                    inhibit_cookie = session_manager.Inhibit ("audience", 0, "Playing Video using Audience", 12);
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
    }
}