using Clutter;

namespace Audience.Widgets
{
	public class VideoPlayer : Actor
	{
		
		public bool at_end;
		
		bool _playing;
		public bool playing {
			get {
				return _playing;
			}
			set {
				if (value == playing)
					return;
				
				controls.show_play_button (!value);
				
				playbin.set_state (value ? Gst.State.PLAYING : Gst.State.PAUSED);
				set_screensaver (!value);
				controls_hidden = value;
				
				_playing = value;
			}
		}
		
		public double progress {
			get {
				int64 length, prog;
				var time = Gst.Format.TIME;
				
				playbin.query_duration (ref time, out length);
				playbin.query_position (ref time, out prog);
				
				if (length == 0)
					return 0;
				
				return prog / (double)length;
			}
			set {
				int64 length;
				var time = Gst.Format.TIME;
				playbin.query_duration (ref time, out length);
				playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE, (int64)(value * length));
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
				return playbin.uri;
			}
			set {
				if (value == (string)playbin.uri)
					return;
				
				intial_relayout = true;
				
				playbin.uri = value;
				controls.slider.preview.uri = value;
				controls.slider.preview.audio_volume = 0.0;
				at_end = false;
				
				int flags;
				playbin.get ("flags", out flags);
				flags &= ~SUBTITLES_FLAG;
				flags |= DOWNLOAD_FLAG;
				playbin.set ("flags", flags, "current-text", -1);
			}
		}
		
		bool _controls_hidden;
		public bool controls_hidden
		{
			get { return _controls_hidden; }
			set {
				if (_controls_hidden && !value) {
					float y2 = get_stage ().height - controls.height;
					controls.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, y:y2);
				} else if (!_controls_hidden && value){
					float y2 = get_stage ().height;
					controls.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 1000, y:y2);
				}
				_controls_hidden = value;
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

                if (value == -1) {
                    flags &= ~SUBTITLES_FLAG;
                    playbin.set ("flags", flags, "current-text", value);
                } else {
                    flags |= SUBTITLES_FLAG;
                    playbin.set ("flags", flags, "current-text", value);
                }

			}
		}
		
		public dynamic Gst.Element playbin;
		Clutter.Texture video;
		Controls controls;
		TopPanel panel;
		
		//we will only hide if hide lock is 0
		public int hide_lock;
		
		uint hiding_timer;
		
		public bool fullscreened;
		public bool moving_action;
		
		public signal void ended ();
		public signal void toggle_side_pane (bool show);
		public signal void text_tags_changed ();
		public signal void audio_tags_changed ();
		public signal void show_open_context ();
		public signal void exit_fullscreen ();
		public signal void configure_window (int video_w, int video_h);
		
		public VideoPlayer ()
		{
			reactive = true;
			
			controls = new Controls ();
			controls.add_constraint (new BindConstraint (this, BindCoordinate.WIDTH, 0));
			
			panel = new TopPanel ();
			
			video = new Clutter.Texture ();
			video.reactive = true;
			
			playbin = Gst.ElementFactory.make ("playbin2", "playbin");
			dynamic Gst.Element video_sink = Gst.ElementFactory.make ("cluttersink", "videosink");
			video_sink.texture = video;
			
			playbin.video_sink = video_sink;
			
			add_child (video);
			add_child (controls);
			add_child (panel);
			
			video.size_change.connect (relayout);
			controls.slider.seeked.connect ( (v) => {
				debug ("Seeked to %f", v);
				progress = v;
			});
			Timeout.add (100, () => {
				int64 length, prog;
				var format = Gst.Format.TIME;
				playbin.query_position (ref format, out prog);
				playbin.query_duration (ref format, out length);
				
				if (length == 0)
					return true;
				
				controls.slider.progress = prog / (double)length;
				
				controls.current.text = seconds_to_time ((int)(prog / 1000000000));
				controls.remaining.text = "-" + seconds_to_time ((int)(length / 1000000000) - (int)(prog / 1000000000));
				
				return true;
			});
			playbin.about_to_finish.connect (() => {
				at_end = true;
				ended ();
			});
			
			notify["fullscreened"].connect (() => panel.toggle (fullscreened) );
			
			//FIXME
			bool last_state = false;
			controls.notify["hovered"].connect (() => {
				if (controls.hovered == last_state)
					return;
				
				last_state = controls.hovered;
				hide_lock += controls.hovered ? 1 : -1;
			});
			
			controls.open.clicked.connect (() => {
				show_open_context ();
				
				toggle_timeout (false);
			});
			controls.play.clicked.connect (() => playing = !playing );
			controls.view.clicked.connect (() => {
				if (!controls.showing_view) {
					toggle_side_pane (true);
					controls.view.set_icon ("pane-hide-symbolic", Gtk.Stock.GO_FORWARD, "go-next-symbolic");
					controls.showing_view = true;
					
					hide_lock ++;
				} else {
					toggle_side_pane (false);
					controls.view.set_icon ("pane-show-symbolic", Gtk.Stock.GO_BACK, "go-previous-symbolic");
					controls.showing_view = false;
					
					hide_lock --;
				}
			});
			
			panel.vol.value_changed.connect ( (value) => {
				volume = value;
			});
			panel.vol.value = 1.0;
			
			playbin.text_tags_changed.connect ((el) => {
				var structure = new Gst.Structure.empty ("tags-changed");
				structure.set_value ("type", "text");
				el.post_message (new Gst.Message.application (el, structure));
			});
			playbin.audio_tags_changed.connect ((el) => {
				var structure = new Gst.Structure.empty ("tags-changed");
				structure.set_value ("type", "audio");
				el.post_message (new Gst.Message.application (el, structure));
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
				case Gst.MessageType.ELEMENT:
					if (msg.get_structure () == null)
						break;
					
					if (Gst.is_missing_plugin_message (msg)) {
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
	
		public override bool motion_event (Clutter.MotionEvent event)
		{
			controls_hidden = false;
			if (fullscreened)
				panel.hidden = false;
			if (!controls.slider.mouse_grabbed)
				get_stage ().cursor_visible = true;
			
			Gst.State state;
			playbin.get_state (out state, null, 0);
			if (state == Gst.State.PLAYING && hide_lock < 1) {
				toggle_timeout (true);
				hide_lock = 0;
			} else {
				toggle_timeout (false);
			}
			return true;
		}
		
		bool intial_relayout = false;
		public void relayout ()
		{
			int video_w, video_h;
			video.get_base_size (out video_w, out video_h);
			
			var stage = get_stage ();
			
			var aspect = stage.width / video_w < stage.height / video_h ? stage.width / video_w : stage.height / video_h;
			video.width  = video_w * aspect;
			video.height = video_h * aspect;
			video.x = (stage.width  - video.width)  / 2;
			video.y = (stage.height - video.height) / 2;
			
			if (controls.get_animation () != null)
				controls.detach_animation ();
			controls.y = controls_hidden ? stage.height : stage.height - controls.height;
			
			(controls.content as Clutter.Canvas).set_size ((int)controls.width, (int)controls.height);
			controls.content.invalidate ();
			
			if (intial_relayout) {
				configure_window (video_w, video_h);
				intial_relayout = false;
			}
		}
		
		void show_error (string? message=null)
		{
			var dlg  = new Gtk.Dialog.with_buttons (_("Error"), null, Gtk.DialogFlags.MODAL, Gtk.Stock.OK, Gtk.ResponseType.OK);
			var grid = new Gtk.Grid ();
			var err  = new Gtk.Image.from_stock (Gtk.Stock.DIALOG_ERROR, Gtk.IconSize.DIALOG);
			
			err.margin_right = 12;
			grid.margin = 12;
			grid.attach (err, 0, 0, 1, 1);
			grid.attach (new Widgets.LLabel.markup ("<b>"+
				_("Oops! Audience can't play this file!")+"</b>"), 1, 0, 1, 1);
			if (message != null)
				grid.attach (new Widgets.LLabel (message), 1, 1, 1, 2);
			/*TODO welcome.show_all ();
			clutter.hide ();*/
			
			((Gtk.Box)dlg.get_content_area ()).add (grid);
			dlg.show_all ();
			dlg.run ();
			dlg.destroy ();
		}
	
		void handle_missing_plugin (Gst.Message msg)
		{
			var detail = Gst.missing_plugin_message_get_description (msg);
			var dlg = new Gtk.Dialog.with_buttons ("Missing plugin", null,
				Gtk.DialogFlags.MODAL);
			var grid = new Gtk.Grid ();
			var err  = new Gtk.Image.from_stock (Gtk.Stock.DIALOG_ERROR, 
				Gtk.IconSize.DIALOG);
			var phrase = new Widgets.LLabel (_("Some media files need extra software to be played. Audience can install this software automatically."));
		
			err.margin_right = 12;
			grid.margin = 12;
			grid.attach (err, 0, 0, 1, 1);
			grid.attach (new Widgets.LLabel.markup ("<b>"+
				_("Audience needs %s to play this file.").printf (detail)+"</b>"), 1, 0, 1, 1);
			grid.attach (phrase, 1, 1, 1, 2);
		
			dlg.add_button (_("Don't install"), 1);
			dlg.add_button (_("Install")+" "+detail, 0);
		
			(dlg.get_content_area () as Gtk.Container).add (grid);
		
			dlg.show_all ();
			if (dlg.run () == 0) {
				var installer = Gst.missing_plugin_message_get_installer_detail (msg);
				var context = new Gst.InstallPluginsContext ();
				Gst.install_plugins_async ({installer}, context,
				() => { //finished
					debug ("Finished plugin install\n");
					Gst.update_registry ();
					/*TODO clutter.show ();
					welcome.hide ();*/
					playing = true;
				});
			}
			dlg.destroy ();
		}
		
		void toggle_timeout (bool enable)
		{
			if (hiding_timer != 0)
				Source.remove (hiding_timer);
			
			if (enable) {
				hiding_timer = GLib.Timeout.add (2000, () => {
					if (this.moving_action)
						return false;
					
					get_stage ().cursor_visible = false;
					controls_hidden = true;
					panel.hidden = true;
					
					return false;
				});
			}
		}
		
		//store the default values for setting back
		X.Display dpy; int timeout = -1; int interval; int prefer_blanking; int allow_exposures;
		void set_screensaver (bool enable)
		{
			if (dpy == null)
				dpy = new X.Display ();
			
			if (timeout == -1)
				dpy.get_screensaver (out timeout, out interval, out prefer_blanking, out allow_exposures);
			dpy.set_screensaver (enable ? timeout : 0, interval, prefer_blanking, allow_exposures);
		}
	}
}
