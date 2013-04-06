
namespace Audience.Widgets{

    public class MediaSlider : Clutter.Group {

        public signal void seeked (double new_progress);

        public Clutter.Texture preview;
		public Clutter.Actor preview_bg;
		dynamic Gst.Element preview_playbin;
		dynamic Gst.Element sink;

		double progress_stacked = 0.0;
		bool seeking = false;

        private double _buffered;
        public double buffered{
            get { return _buffered; }
            set { _buffered = value; this.bar.invalidate (); }
        }

        private double _progress;
        public double progress{
            get { return _progress; }
            set { _progress = value; this.bar.invalidate (); }
        }

        private Clutter.CairoTexture bar;

        private const int BAR_HEIGHT = 8;

        /*the mouse is currently on the controls*/
        public bool mouse_grabbed = false;

        public MediaSlider () {
            this.preview   = new Clutter.Texture ();
            this._buffered = 0.0;
            this._progress = 0.0;
            this.bar       = new Clutter.CairoTexture (1, BAR_HEIGHT);

            preview.filter_quality = Clutter.TextureQuality.HIGH;
            preview.scale_x = 0.0;
            preview.scale_y = 0.0;
            preview.scale_gravity = Clutter.Gravity.CENTER;
            preview.height =  90.0f;
            // preview.width is set in VideoPlayer.vala

			// connect gstreamer stuff
#if HAS_CLUTTER_GST_1
			preview_playbin = Gst.ElementFactory.make ("playbin", "play");
#else
			preview_playbin = Gst.ElementFactory.make ("playbin2", "play");
#endif
			preview_playbin.get_bus ().add_signal_watch ();
			preview_playbin.get_bus ().message.connect ((msg) => {
				switch (msg.type) {
					case Gst.MessageType.STATE_CHANGED:
						if (progress_stacked != 0)
							seek (progress_stacked);
						break;
					case Gst.MessageType.ASYNC_DONE:
						if (seeking) {
							seeking = false;
							if (progress_stacked != 0)
								seek (progress_stacked);
						}
						break;
				}
			});
			sink = Audience.get_clutter_sink ();
			sink.texture = preview;
			preview_playbin.video_sink = sink;

            preview_bg = new Clutter.Actor ();
			preview_bg.y = -120.0f;
            preview_bg.add_constraint (new Clutter.BindConstraint (preview, Clutter.BindCoordinate.WIDTH, 30.0f));
            preview_bg.add_constraint (new Clutter.BindConstraint (preview, Clutter.BindCoordinate.HEIGHT, 45.0f));
            preview_bg.opacity = 0;
			preview_bg.content = new Clutter.Canvas ();
			preview_bg.allocation_changed.connect (() => {
				(preview_bg.content as Clutter.Canvas).set_size ((int)preview_bg.width, (int)preview_bg.height);
			});
            var ARROW_HEIGHT = 17;
            var ARROW_WIDTH  = 20;
            var popover_grad = new Cairo.Pattern.linear (0, 0, 0, preview_bg.height);
            popover_grad.add_color_stop_rgba (0.0, 0.243, 0.243, 0.243, 0.7);
            popover_grad.add_color_stop_rgba (1.0, 0.094, 0.094, 0.094, 0.7);

            var popover_inset_grad = new Cairo.Pattern.linear (0, 0, 0, preview_bg.height);
            popover_inset_grad.add_color_stop_rgba (0.0, 1, 1, 1, 0.3);
            popover_inset_grad.add_color_stop_rgba (1.0, 1, 1, 1, 0.1);
            (preview_bg.content as Clutter.Canvas).draw.connect ( (ctx) => {
				ctx.set_operator (Cairo.Operator.CLEAR);
				ctx.paint ();
				ctx.set_operator (Cairo.Operator.OVER);

                // Outline
                Drawing.cairo_popover (ctx, 0, 0, preview_bg.width,
                    preview_bg.height - ARROW_HEIGHT, 3, ARROW_WIDTH, ARROW_HEIGHT);
                ctx.set_source_rgba (0, 0, 0, 0.7);
                ctx.fill ();

                // Inset border
                Drawing.cairo_popover (ctx, 1, 1, preview_bg.width - 2,
                    preview_bg.height - 2 - ARROW_HEIGHT, 3, ARROW_WIDTH - 2, ARROW_HEIGHT - 2);
                ctx.set_source (popover_inset_grad);
                ctx.fill ();

                ctx.set_operator(Cairo.Operator.SOURCE);
                // Fill
                Drawing.cairo_popover (ctx, 2, 2, preview_bg.width - 4,
                    preview_bg.height - 4 - ARROW_HEIGHT, 3, ARROW_WIDTH - 4, ARROW_HEIGHT - 4);
                ctx.set_source (popover_grad);
                ctx.fill ();

                ctx.set_operator(Cairo.Operator.OVER);
                return true;
            });

            this.bar.y = CONTROLS_HEIGHT / 2 - BAR_HEIGHT / 2;
            this.bar.auto_resize = true;
            var bar_grad = new Cairo.Pattern.linear (0, 0, 0, BAR_HEIGHT);
            bar_grad.add_color_stop_rgba (0.0, 0.254, 0.247, 0.231, 0.4);
            bar_grad.add_color_stop_rgba (1.0, 0.298, 0.290, 0.282, 0.4);
            var bar_shadow_grad = new Cairo.Pattern.linear (0, 0, 0, BAR_HEIGHT);
            bar_shadow_grad.add_color_stop_rgba (0.0, 1, 1, 1, 0);
            bar_shadow_grad.add_color_stop_rgba (1.0, 1, 1, 1, 0.2);
            this.bar.draw.connect ( (ctx) => {
                this.bar.clear();
                //drop shadow
                Drawing.cairo_pill (ctx, 0, 0, this.bar.width, BAR_HEIGHT);
                ctx.set_source (bar_shadow_grad);
                ctx.fill ();
                //outline
                Drawing.cairo_pill (ctx, 1, 1, this.bar.width - 2, BAR_HEIGHT - 2);
                ctx.set_source_rgba (0, 0, 0, 0.4);
                ctx.fill ();
                //bg
                Drawing.cairo_pill (ctx, 2, 2, this.bar.width - 4, BAR_HEIGHT - 4);
                ctx.set_source (bar_grad);
                ctx.fill ();
                //buffering
                if (this._buffered != 0.0){
					int64 duration;
#if HAS_CLUTTER_GST_1
					preview_playbin.query_duration (Gst.Format.TIME, out duration);
#else
					var time = Gst.Format.TIME;
					preview_playbin.query_duration (ref time, out duration);
#endif
                    Drawing.cairo_half_pill (ctx, 2, 2,
                        (this._buffered / duration * this.bar.width) - 4, BAR_HEIGHT - 4, Gtk.PositionType.RIGHT);
                    ctx.set_source_rgb (0.6, 0.6, 0.6);
                    ctx.fill ();
                }
                //progress
                if (this._progress != 0.0){
                    Drawing.cairo_half_pill (ctx, 2, 2, (this._progress * this.width) - 4, BAR_HEIGHT - 4, Gtk.PositionType.RIGHT);
                    ctx.set_source_rgb (1.0, 1.0, 1.0);
                    ctx.fill ();
                }
                return true;
            });

            var scalex = new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0);
            bar.add_constraint (scalex);

            //seek
            preview.reactive = true;

            reactive = true;
            add_child (bar);
            add_child (preview_bg);
        }

		public override bool motion_event (Clutter.MotionEvent event)
		{
			float local_x, local_y;
			this.transform_stage_point (event.x, event.y, out local_x, out local_y);

			preview.x = event.x - preview.width / 2;
			preview_bg.x = local_x - preview.width / 2 - 15.0f;

			seek (float.max (local_x, 0.0000001f) / this.width);

			return true;
		}

		public override bool enter_event (Clutter.CrossingEvent event)
		{
			this.preview.animate (Clutter.AnimationMode.EASE_OUT_ELASTIC, 800,
				scale_x:1.0, scale_y:1.0);
			preview_bg.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 500, opacity:240);
			preview_toggle_playing (true);
			this.mouse_grabbed = true;
			return false;
		}

		public override bool leave_event (Clutter.CrossingEvent event)
		{
			preview.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 150,
				scale_x:0.0, scale_y:0.0);
			preview_bg.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 150, opacity:0);
			preview_toggle_playing (false);
			mouse_grabbed = false;
			return false;
		}

		public override bool button_release_event (Clutter.ButtonEvent event)
		{
			float x, y;
			this.transform_stage_point (event.x, event.y, out x, out y);
			this.seeked (x / this.width);
			return true;
		}

		public void set_preview_uri (string uri)
		{
			preview_playbin.set_state (Gst.State.READY);
			preview_playbin.uri = uri;
			preview_playbin.volume = 0.0;
		}

		void preview_toggle_playing (bool play)
		{
			this.preview_playbin.set_state (play ? Gst.State.PLAYING : Gst.State.PAUSED);
		}

		void seek (double progress)
		{
			if (seeking) {
				progress_stacked = progress;
				return;
			}

			int64 duration;
#if HAS_CLUTTER_GST_1
			preview_playbin.query_duration (Gst.Format.TIME, out duration);
#else
			var time = Gst.Format.TIME;
			preview_playbin.query_duration (ref time, out duration);
#endif
			preview_playbin.seek (1.0, Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.KEY_UNIT,
				Gst.SeekType.SET, (int64)(progress * duration),
				Gst.SeekType.NONE, (int64)Gst.CLOCK_TIME_NONE);

			this.progress_stacked = 0;

			seeking = true;
		}
    }
}

