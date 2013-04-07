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

namespace Audience.Widgets
{
	public class VideoPlayer : Actor
	{
		
		public bool at_end;
		
		bool paused;
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

				if (!value) {
					paused = true;
					lock_hide ();
				}
				if (value && paused) {
					paused = false;
					unlock_hide ();
				}

				_playing = value;
			}
		}
		
		public double progress {
			get {
				int64 length, prog;
				
#if HAS_CLUTTER_GST_1
				playbin.query_duration (Gst.Format.TIME, out length);
				playbin.query_position (Gst.Format.TIME, out prog);
#else
				var time = Gst.Format.TIME;
				playbin.query_duration (ref time, out length);
				playbin.query_position (ref time, out prog);
#endif
				
				if (length == 0)
					return 0;
				
				return prog / (double)length;
			}
			set {
				int64 length;
#if HAS_CLUTTER_GST_1
				playbin.query_duration (Gst.Format.TIME, out length);
#else
				var time = Gst.Format.TIME;
				playbin.query_duration (ref time, out length);
#endif
				playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE,
					(int64)(double.max (value, 0.0) * length));
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
#if HAS_CLUTTER_GST_1
				return playbin.current_uri;
#else
				return playbin.uri;
#endif
			}
			set {
				if (value == (string)playbin.uri)
					return;

				try {
#if HAS_CLUTTER_GST_1
					var info = new Gst.PbUtils.Discoverer (10 * Gst.SECOND).discover_uri (value);
#else
					var info = new Gst.Discoverer (10 * Gst.SECOND).discover_uri (value);
#endif
					var video = info.get_video_streams ();
					if (video.data != null) {
#if HAS_CLUTTER_GST_1
						var video_info = (Gst.PbUtils.DiscovererVideoInfo)video.data;
#else
						var video_info = (Gst.DiscovererVideoInfo)video.data;
#endif
						video_width = video_info.get_width ();
						video_height = video_info.get_height ();
					}
				} catch (Error e) {
					error ();
					warning (e.message);
					return;
				}
				
				intial_relayout = true;
				
				playbin.set_state (Gst.State.READY);
				playbin.suburi = null;
				subtitle_uri = null;
				playbin.uri = value;
				volume = 1.0;
				controls.slider.set_preview_uri (value);
				at_end = false;
				
				relayout ();
			}
		}
		
		bool _controls_hidden;
		public bool controls_hidden
		{
			get { return _controls_hidden; }
			set {
				if (_controls_hidden && !value) {
					float y2 = get_stage ().height - controls.height;
					controls.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 300, y:y2);
				} else if (!_controls_hidden && value){
					float y2 = get_stage ().height;
					controls.animate (Clutter.AnimationMode.EASE_IN_QUAD, 600, y:y2);
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
		Controls controls;
		TopPanel panel;

		uint video_width;
		uint video_height;
		
		// we will only hide if hide lock is 0
		public int hide_lock = 0;
		
		uint hiding_timer;
		
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
		
		public VideoPlayer ()
		{
			reactive = true;
			
			controls = new Controls ();
			controls.add_constraint (new BindConstraint (this, BindCoordinate.WIDTH, 0));
			controls.slider.preview.add_constraint (new BindConstraint (controls, Clutter.BindCoordinate.Y, -105.0f));
			
			panel = new TopPanel ();
			
			video = new Clutter.Texture ();
			video.reactive = true;
			
#if HAS_CLUTTER_GST_1
			playbin = Gst.ElementFactory.make ("playbin", "playbin");
#else
			playbin = Gst.ElementFactory.make ("playbin2", "playbin");
#endif
			var video_sink = Audience.get_clutter_sink ();
			video_sink.texture = video;
			
			playbin.video_sink = video_sink;
			
			add_child (video);
			add_child (controls);
			add_child (panel);
			add_child (controls.slider.preview);
			
			controls.slider.seeked.connect ( (v) => {
				debug ("Seeked to %f", v);
				progress = v;
			});
			Timeout.add (100, () => {
				int64 length, prog;
#if HAS_CLUTTER_GST_1
				playbin.query_position (Gst.Format.TIME, out prog);
				playbin.query_duration (Gst.Format.TIME, out length);
#else
				var format = Gst.Format.TIME;
				playbin.query_position (ref format, out prog);
				playbin.query_duration (ref format, out length);
#endif
				
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

			notify["fullscreened"].connect (() => {
				if (hide_lock > 0)
					panel.hidden = !fullscreened;
			});
			panel.unfullscreen.connect (() => {
				exit_fullscreen ();
			});
			
			bool last_state = false;
			controls.notify["hovered"].connect (() => {
				if (controls.hovered == last_state)
					return;
				
				last_state = controls.hovered;

				if (controls.hovered)
					lock_hide ();
				else
					unlock_hide ();
			});
			
			controls.open.clicked.connect (() => {
				show_open_context ();
			});
			controls.play.clicked.connect (() => playing = !playing );
			controls.view.clicked.connect (() => {
				if (!controls.showing_view) {
					toggle_side_pane (true);
					controls.view.set_icon ("pane-hide-symbolic", Gtk.Stock.GO_FORWARD, "go-next-symbolic");
					controls.showing_view = true;
					
					lock_hide ();
				} else {
					toggle_side_pane (false);
					controls.view.set_icon ("pane-show-symbolic", Gtk.Stock.GO_BACK, "go-previous-symbolic");
					controls.showing_view = false;
					
					unlock_hide ();
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

		public void lock_hide () {
			if (hide_lock == 0)
				toggle_controls (true);
			hide_lock++;
		}
		public void unlock_hide () {
			hide_lock--;

			if (hide_lock < 1)
				toggle_controls (false);
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
					
#if HAS_CLUTTER_GST_1
					if (Gst.PbUtils.is_missing_plugin_message (msg)) {
#else
					if (Gst.is_missing_plugin_message (msg)) {
#endif
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

		public override bool motion_event (Clutter.MotionEvent event)
		{
			if (!controls.slider.mouse_grabbed)
				get_stage ().cursor_visible = true;
			
			Gst.State state;
			playbin.get_state (out state, null, 0);
			if (state == Gst.State.PLAYING) {
				if (hiding_timer < 1)
					lock_hide ();
				set_timeout ();
			}
			return true;
		}

		public void set_subtitle_uri (string? uri)
		{
			subtitle_uri = uri;
			if (!check_text_layer (subtitle_uri != null))
				apply_subtitles ();
		}

		// checks whether text layer has to be enabled
		// returns if apply_subtitles has been called
		bool check_text_layer (bool enable)
		{
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
		void apply_subtitles ()
		{
			int64 time;
#if HAS_CLUTTER_GST_1
			playbin.query_position (Gst.Format.TIME, out time);
#else
			var format = Gst.Format.TIME;
			playbin.query_position (ref format, out time);
#endif

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
		public bool relayout ()
		{
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
			
			if (controls.get_animation () != null)
				controls.detach_animation ();
			controls.y = controls_hidden ? stage.height : stage.height - controls.height;
			
			(controls.content as Clutter.Canvas).set_size ((int)controls.width, (int)controls.height);
			controls.content.invalidate ();

			panel.x = get_stage ().width - panel.width - 10;
			controls.slider.preview.width = (float) video_width / video_height * controls.slider.preview.height;

			return true;
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

			error ();
			
			((Gtk.Box)dlg.get_content_area ()).add (grid);
			dlg.show_all ();
			dlg.run ();
			dlg.destroy ();
		}
	
		void handle_missing_plugin (Gst.Message msg)
		{
#if HAS_CLUTTER_GST_1
			var detail = Gst.PbUtils.missing_plugin_message_get_description (msg);
#else
			var detail = Gst.missing_plugin_message_get_description (msg);
#endif
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
#if HAS_CLUTTER_GST_1
				var installer = Gst.PbUtils.missing_plugin_message_get_installer_detail (msg);
				var context = new Gst.PbUtils.InstallPluginsContext ();
				Gst.PbUtils.install_plugins_async ({installer}, context,
#else
				var installer = Gst.missing_plugin_message_get_installer_detail (msg);
				var context = new Gst.InstallPluginsContext ();
				Gst.install_plugins_async ({installer}, context,
#endif
				() => { //finished
					debug ("Finished plugin install\n");
					Gst.update_registry ();
					plugin_install_done ();
					playing = true;
				});
			}
			dlg.destroy ();
		}
		
		void set_timeout ()
		{
			if (hiding_timer != 0)
				Source.remove (hiding_timer);
			
			hiding_timer = GLib.Timeout.add (2000, () => {
				unlock_hide ();
				hiding_timer = 0;
				return false;
			});
		}
		
		void toggle_controls (bool show)
		{
			if (show) {
				controls_hidden = false;
				get_stage ().cursor_visible = true;
				if (fullscreened)
					panel.hidden = false;
			} else {
				get_stage ().cursor_visible = false;
				controls_hidden = true;
				panel.hidden = true;
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
