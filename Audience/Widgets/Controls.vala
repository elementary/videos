

namespace Audience.Widgets{
    
    public class MediaSlider : Clutter.Group {
        
        public signal void seeked (double new_progress);
        
        public ClutterGst.VideoTexture preview;
        
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
            this.preview   = new ClutterGst.VideoTexture ();
            this._buffered = 0.0;
            this._progress = 0.0;
            this.bar       = new Clutter.CairoTexture (1, this.BAR_HEIGHT);
            
            this.preview.filter_quality = Clutter.TextureQuality.HIGH;
            this.preview.audio_volume  = 0.0;
            this.preview.scale_x       = 0.0;
            this.preview.scale_y       = 0.0;
            this.preview.scale_gravity = Clutter.Gravity.CENTER;
            this.preview.height =  90.0f;
            this.preview.width  =  120.0f;
            this.preview.y      = -105.0f;
            
            var preview_bg = new Clutter.CairoTexture (90, 90);
            preview_bg.add_constraint (new Clutter.BindConstraint (preview, Clutter.BindCoordinate.X, -15.0f));
            preview_bg.add_constraint (new Clutter.BindConstraint (preview, Clutter.BindCoordinate.Y, -15.0f));
            preview_bg.add_constraint (new Clutter.BindConstraint (preview, Clutter.BindCoordinate.WIDTH, 30.0f));
            preview_bg.add_constraint (new Clutter.BindConstraint (preview, Clutter.BindCoordinate.HEIGHT, 45.0f));
            preview_bg.auto_resize = true;
            preview_bg.opacity = 0;
            var ARROW_HEIGHT = 17;
            var ARROW_WIDTH  = 30;
            var popover_grad = new Cairo.Pattern.linear (0, 0, 0, preview_bg.height);
            popover_grad.add_color_stop_rgba (0.0, 0.212, 0.212, 0.212, 1.000);
            popover_grad.add_color_stop_rgba (1.0, 0.141, 0.141, 0.141, 1.000);
            preview_bg.draw.connect ( (ctx) => {
                /*stolen from Granite.Widgets.PopOver.cairo_popover*/
                Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 1, 1,
                    preview_bg.width - 2, preview_bg.height - ARROW_HEIGHT + 1, 5);
                ctx.move_to (preview_bg.width/2-ARROW_WIDTH/2, 2 + preview_bg.height - ARROW_HEIGHT);
                ctx.rel_line_to (ARROW_WIDTH / 2.0, ARROW_HEIGHT);
                ctx.rel_line_to (ARROW_WIDTH / 2.0, -ARROW_HEIGHT);
                ctx.close_path ();
                
                ctx.set_source_rgba (0.0, 0.0, 0.0, 0.5);
                ctx.set_line_width (1.0);
                ctx.stroke_preserve ();
                
                ctx.set_source (popover_grad);
                ctx.fill ();
                return true;
            });
            
            this.bar.y = CONTROLS_HEIGHT / 2 - this.BAR_HEIGHT / 2;
            this.bar.auto_resize = true;
            var bar_grad = new Cairo.Pattern.linear (0, 0, 0, this.BAR_HEIGHT);
            bar_grad.add_color_stop_rgba (0.0, 0.254, 0.247, 0.231, 0.4);
            bar_grad.add_color_stop_rgba (1.0, 0.298, 0.290, 0.282, 0.4);
            var bar_shadow_grad = new Cairo.Pattern.linear (0, 0, 0, this.BAR_HEIGHT);
            bar_shadow_grad.add_color_stop_rgba (0.0, 1, 1, 1, 0);
            bar_shadow_grad.add_color_stop_rgba (1.0, 1, 1, 1, 0.2);
            this.bar.draw.connect ( (ctx) => {
                this.bar.clear();
                //drop shadow
                Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, 
                    this.bar.width, this.BAR_HEIGHT, this.BAR_HEIGHT / 2);
                ctx.set_source (bar_shadow_grad);
                ctx.fill ();
                //outline
                Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 1, 1, 
                    this.bar.width - 2, this.BAR_HEIGHT - 2, (this.BAR_HEIGHT - 2) / 2);
                ctx.set_source_rgba (0, 0, 0, 0.4);
                ctx.fill ();
                //bg
                Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 2, 2, 
                    this.bar.width - 4, this.BAR_HEIGHT - 4, (this.BAR_HEIGHT - 4) / 2);
                ctx.set_source (bar_grad);
                ctx.fill ();
                //buffering
                if (this._buffered != 0.0){
                    Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 2, 2, 
                        (this._buffered / this.preview.duration * this.bar.width) - 4,
                        this.BAR_HEIGHT - 4, (this.BAR_HEIGHT - 4) / 2);
                    ctx.set_source_rgb (0.6, 0.6, 0.6);
                    ctx.fill ();
                }
                //progress
                if (this._progress != 0.0){
                    Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 2, 2, 
                        (this._progress * this.width) - 4, this.BAR_HEIGHT - 4, 
                        (this.BAR_HEIGHT - 4) / 2);
                    ctx.set_source_rgb (1.0, 1.0, 1.0);
                    ctx.fill ();
                }
                return true;
            });
            
            var scalex = new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0);
            this.bar.add_constraint (scalex);
            /*
             Events
             */
            //move preview
            this.enter_event.connect ( (e) => {
                this.preview.animate (Clutter.AnimationMode.EASE_OUT_ELASTIC, 800, 
                    scale_x:1.0, scale_y:1.0);
                preview_bg.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 500, opacity:240);
                this.preview.playing = true;
                this.get_stage ().cursor_visible = true;
                this.mouse_grabbed = true;
                return false;
            });
            this.motion_event.connect ( (e) => {
                float x, y;
                this.transform_stage_point (e.x, e.y, out x, out y);
                
                if (x - (preview.width / 2) <= 0)
                    this.preview.x = 1;
                else if (x + (preview.width / 2) >= this.width)
                    this.preview.x = this.width - this.preview.width;
                else
                    this.preview.x = x - preview.width / 2;
                
                this.preview.progress = x / this.width;
                return true;
            });
            this.leave_event.connect ( (e) => {
                this.preview.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 150, 
                    scale_x:0.0, scale_y:0.0);
                preview_bg.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 150, opacity:0);
                this.preview.playing = false;
                this.get_stage ().cursor_visible = true;
                this.mouse_grabbed = false;
                return false;
            });
            
            //seek
            this.preview.reactive = true;
            this.button_release_event.connect ( (e) => {
                float x, y;
                this.transform_stage_point (e.x, e.y, out x, out y);
                this.seeked (x / this.width);
                return true;
            });
            
            this.reactive = true;
            this.add_actor (this.bar);
            this.add_actor (preview_bg);
            this.add_actor (this.preview);
        }
    }
    
    
    public class Button : GtkClutter.Texture {
        public signal void clicked ();
        
        public Button (string icon, string fallback){
            set_icon (icon, fallback);
            
            this.reactive = true;
            this.opacity = 255;
            this.enter_event.connect ( () => {
                this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity:170);
                return true;
            });
            this.leave_event.connect ( () => {
                this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity:255);
                return true;
            });
            
            this.button_release_event.connect ( () => {
                this.clicked ();
                return true;
            });
        }
        
        public void set_tooltip (string text){
            //TODO
        }
        
        public void set_icon (string icon, string fallback) {
            try{
                var l = Gtk.IconTheme.get_default ().lookup_icon (icon, 16, 0);
                if (l == null)
                    this.set_from_stock (new Gtk.Image (), fallback, Gtk.IconSize.SMALL_TOOLBAR);
                else
                    this.set_from_pixbuf (l.load_symbolic ({1.0,1.0,1.0,1.0}, null, null, null, null));
            }catch (Error e){warning (e.message);}
        }
    }
    
    /*a bar only shown for fullscreen including volume and unfullscreen*/
    public class TopPanel : Clutter.Box {
        
        public Button exit;
        public GtkClutter.Actor volume;
        public Gtk.VolumeButton vol;
        
        bool _hidden;
        public bool hidden{
            get { return _hidden; }
            set { 
                if (_hidden && !value){
                    float y2 = 0.0f;
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, y:y2);
                }else if (!_hidden && value){
                    float y2 = -this.height;
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 1000, y:y2);
                }
                this._hidden = value;
            }
        }
        
        public TopPanel () {
            this.layout_manager = new Clutter.BoxLayout ();
            
            this.exit   = new Button ("view-restore-symbolic", Gtk.Stock.LEAVE_FULLSCREEN);
            this.volume = new GtkClutter.Actor ();
            var buf     = new Clutter.Rectangle.with_color ({0,0,0,0});
            this.vol    = new Gtk.VolumeButton ();
            this.vol.use_symbolic = true;
            this._hidden = true;
            
            var css = new Gtk.CssProvider ();
            try {
                css.load_from_data ("""
                * {
                    color: #fff;
                    transition: 2ms linear;
                }
                *:hover {
                    color: #aaa;
                    transition: 2ms linear;
                }
                .button {
                    background-image: none;
                    background-color: alpha (#000, 0);
                    border-color: alpha (#000, 0);
                    border-image: none;
                    -unico-border-gradient: none;
                    -unico-inner-stroke-width: 0px;
                    -unico-outer-stroke-width: 0px;
                }
                """, -1);
            }catch (Error e) { warning (e.message); }
            this.vol.get_child ().get_style_context ().add_provider (css, 20000);
            this.vol.get_style_context ().add_provider (css, 20000);
            
            ((Gtk.Container)this.volume.get_widget ()).add (this.vol);
            this.volume.get_widget ().draw.connect ( (ctx) => {
                ctx.rectangle (0, 0, this.volume.width, this.volume.height);
                ctx.set_operator (Cairo.Operator.SOURCE);
                ctx.set_source_rgba (0, 0, 0, 0);
                ctx.fill ();
                return false;
            });
            
            buf.width = 10;
            
            //this.add_actor (this.volume); removed until we get it to control global volume
            this.add_actor (buf);
            this.add_actor (this.exit);
            
            this.y = this.height;
            this.x = Gdk.Screen.get_default ().width () - this.width - 30;
        }
        
        public void toggle (bool show) {
            if (show) {
                this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, y:0.0f);
                this.show ();
            }else if (this.y != this.height) {
                var a = this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, y:this.height);
                a.completed.connect ( () => {
                    this.hide ();
                });
            }
        }
    }
    
    /*the controls bar at the bottom*/
    public class Controls : Clutter.Box {
        //"media-playback-pause-symbolic", Gtk.Stock.MEDIA_PAUSE
        public MediaSlider slider;
        public Button play;
        public Button view;
        public Button open;
        
        public Clutter.Text current;
        public Clutter.Text remaining;
        
        Clutter.BoxLayout layout;
        
        private Gdk.Pixbuf play_pix;
        private Gdk.Pixbuf pause_pix;
        
        public bool showing_view = false;
        
        public Clutter.CairoTexture background;
        
        public bool hovered;
        
        bool _hidden;
        public bool hidden{
            get { return _hidden; }
            set { 
                if (_hidden && !value){
                    float y2 = this.get_stage ().height - CONTROLS_HEIGHT;
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, y:y2);
                }else if (!_hidden && value){
                    float y2 = this.get_stage ().height;
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 1000, y:y2);
                }
                this._hidden = value;
            }
        }
        
        public Controls (){
            this.layout         = new Clutter.BoxLayout ();
            this.layout_manager = layout;
            this._hidden        = false;
            
            this.background = new Clutter.CairoTexture (100, CONTROLS_HEIGHT);
            
            this.current   = new Clutter.Text.full ("", "0", {255,255,255,255});
            this.remaining = new Clutter.Text.full ("", "0", {255,255,255,255});
            
            this.slider = new MediaSlider ();
            
            this.play = new Button ("media-playback-start-symbolic", Gtk.Stock.MEDIA_PLAY);
            this.view = new Button ("pane-show-symbolic", Gtk.Stock.GO_BACK);
            this.open = new Button ("list-add-symbolic", Gtk.Stock.OPEN);
            
            var spacer_left = new Clutter.Rectangle.with_color ({0,0,0,0});
            spacer_left.width = 0;
            var spacer_right = new Clutter.Rectangle.with_color ({0,0,0,0});
            spacer_right.width = 0;
            
            this.add_actor (spacer_left);
            this.add_actor (this.play);
            this.add_actor (this.current);
            this.add_actor (this.slider);
            this.add_actor (this.remaining);
            this.add_actor (this.open);
            this.add_actor (this.view);
            this.add_actor (spacer_right);
            
            this.layout.set_spacing (10);
            this.layout.set_expand (this.slider, true);
            this.layout.set_fill (this.slider, true, true);
            
            /*setup a css style for the control background*/
            var style_holder = new Gtk.EventBox ();
            var css = new Gtk.CssProvider ();
            try{css.load_from_data ("
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
            ", -1);}catch (Error e){warning (e.message);}
            style_holder.get_style_context ().add_provider (css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            
            this.background.auto_resize = true;
            this.background.draw.connect ( (ctx) => {
                style_holder.get_style_context ().render_background (ctx, -2, 0, this.background.width+4, CONTROLS_HEIGHT+1);
                style_holder.get_style_context ().render_frame (ctx, -2, 0, this.background.width+4, CONTROLS_HEIGHT+1);
                return true;
            });
            this.background.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.X, 0.0f));
            this.background.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.Y, 0.0f));
            this.background.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0.0f));
            this.background.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.HEIGHT, 0.0f));
            
            try{
                var l = Gtk.IconTheme.get_default ().lookup_icon ("media-playback-pause-symbolic", 16, 0);
                if (l == null)
                    this.pause_pix = new Gtk.Image.from_stock (Gtk.Stock.MEDIA_PAUSE, Gtk.IconSize.LARGE_TOOLBAR).pixbuf;
                else
                    this.pause_pix = l.load_symbolic ({1.0,1.0,1.0,1.0}, null, null, null, null);
            }catch (Error e){warning (e.message);}
            
            try{
                var l = Gtk.IconTheme.get_default ().lookup_icon ("media-playback-start-symbolic", 16, 0);
                if (l == null)
                    this.play_pix = new Gtk.Image.from_stock (Gtk.Stock.MEDIA_PLAY, Gtk.IconSize.LARGE_TOOLBAR).pixbuf;
                else
                    this.play_pix = l.load_symbolic ({1.0,1.0,1.0,1.0}, null, null, null, null);
            }catch (Error e){warning (e.message);}
            
            this.height = CONTROLS_HEIGHT;
            
            this.reactive = true;
            this.enter_event.connect ( () => {
                this.hovered = true;
                return false;
            });
            this.leave_event.connect ( () => {
                this.hovered = false;
                return false;
            });
        }
        
        public void show_play_button (bool show){ /*or show pause button*/
            try{
                this.play.set_from_pixbuf ((show)?play_pix:pause_pix);
            }catch (Error e){warning (e.message);}
        }
    }
    
}
