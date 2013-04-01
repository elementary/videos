using Clutter;

namespace Audience.Widgets
{
    public class Controls : Actor
    {
        public MediaSlider slider;
        public Button play;
        public Button view;
        public Button open;
        
        public Text current;
        public Text remaining;
        
        private Gdk.Pixbuf play_pix;
        private Gdk.Pixbuf pause_pix;
        
        public bool showing_view = false;
        public bool hovered { get; set; }
        
        public Controls ()
        {
            layout_manager = new BoxLayout ();
            content = new Canvas ();
            
			(layout_manager as BoxLayout).spacing = 10;

            this.current   = new Text.full ("", "0", {255,255,255,255});
            this.remaining = new Text.full ("", "0", {255,255,255,255});
            
            this.slider = new MediaSlider ();
            
            this.play = new Button ("media-playback-start-symbolic", Gtk.Stock.MEDIA_PLAY);
            this.view = new Button ("pane-show-symbolic", Gtk.Stock.GO_BACK, "go-previous-symbolic");
            this.open = new Button ("list-add-symbolic", Gtk.Stock.OPEN);
            
            var spacer_left = new Rectangle.with_color ({0,0,0,0});
            spacer_left.width = 0;
            var spacer_right = new Rectangle.with_color ({0,0,0,0});
            spacer_right.width = 0;
            
            this.add_child (spacer_left);
            this.add_child (this.play);
            this.add_child (this.current);
            this.add_child (this.slider);
            this.add_child (this.remaining);
            this.add_child (this.open);
            this.add_child (this.view);
            this.add_child (spacer_right);

			(layout_manager as BoxLayout).set_expand (slider, true);
			(layout_manager as BoxLayout).set_fill (slider, true, true);
            
            /*setup a css style for the control background*/
            var style_holder = new Gtk.EventBox ();
            var css = new Gtk.CssProvider ();
            try{css.load_from_data ("""
            * {
                engine: unico;
                background-image: -gtk-gradient (linear, 
                    left top, left bottom, 
                    from (alpha(#323232, 0.698)), 
                    to   (alpha(#242424, 0.698)));
                
                -unico-outer-stroke-gradient: -gtk-gradient (linear, 
                    left top, left bottom,
                    from (alpha(#161616, 0.698)), 
                    to   (alpha(#000000, 0.698)));
                -unico-inner-stroke-gradient: -gtk-gradient (linear,
                    left top, left bottom,
                    from       (alpha(#ffffff, 0.149)),
                    color-stop (0.1, alpha(#ffffff, 0.035)), 
                    color-stop (0.9, alpha(#ffffff, 0.024)), 
                    to         (alpha(#ffffff, 0.059)));
                -unico-inner-stroke-width: 1;
                -unico-outer-stroke-width: 1;
            }
            """, -1);}catch (Error e){warning (e.message);}
            style_holder.get_style_context ().add_provider (css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            
            (content as Canvas).draw.connect ( (ctx) => {
                ctx.set_operator (Cairo.Operator.CLEAR);
                ctx.paint ();
                ctx.set_operator (Cairo.Operator.OVER);
                
                style_holder.get_style_context ().render_background (ctx, -2, 0, width+4, CONTROLS_HEIGHT+1);
                style_holder.get_style_context ().render_frame (ctx, -2, 0, width+4, CONTROLS_HEIGHT+1);
                
                return false;
            });
            (content as Canvas).set_size (500, CONTROLS_HEIGHT);
            
            try {
                var l = Gtk.IconTheme.get_default ().lookup_icon ("media-playback-pause-symbolic", 16, 0);
                if (l == null)
                    this.pause_pix = new Gtk.Image.from_stock (Gtk.Stock.MEDIA_PAUSE, Gtk.IconSize.LARGE_TOOLBAR).pixbuf;
                else
                    this.pause_pix = l.load_symbolic ({1.0,1.0,1.0,1.0}, null, null, null, null);
            } catch (Error e) { warning (e.message); }
            
            try {
                var l = Gtk.IconTheme.get_default ().lookup_icon ("media-playback-start-symbolic", 16, 0);
                if (l == null)
                    this.play_pix = new Gtk.Image.from_stock (Gtk.Stock.MEDIA_PLAY, Gtk.IconSize.LARGE_TOOLBAR).pixbuf;
                else
                    this.play_pix = l.load_symbolic ({1.0,1.0,1.0,1.0}, null, null, null, null);
            } catch (Error e) { warning (e.message); }
            
            this.height = CONTROLS_HEIGHT;
            
            this.reactive = true;
            this.enter_event.connect ( () => {
                this.hovered = true;
                return false;
            });
            this.leave_event.connect ( (e) => {
				if (!contains (e.related))
					this.hovered = false;
                return false;
            });
        }

		// catch all button presses
		public override bool button_press_event (Clutter.ButtonEvent event) {
			return true;
		}
        
        public void show_play_button (bool show){ /*or show pause button*/
            try{
                this.play.set_from_pixbuf ((show)?play_pix:pause_pix);
            }catch (Error e){warning (e.message);}
        }
    }
    
}
