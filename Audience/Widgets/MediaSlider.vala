
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
            var ARROW_WIDTH  = 20;
            var popover_grad = new Cairo.Pattern.linear (0, 0, 0, preview_bg.height);
            popover_grad.add_color_stop_rgba (0.0, 0.243, 0.243, 0.243, 0.7);
            popover_grad.add_color_stop_rgba (1.0, 0.094, 0.094, 0.094, 0.7);
            
            var popover_inset_grad = new Cairo.Pattern.linear (0, 0, 0, preview_bg.height);
            popover_inset_grad.add_color_stop_rgba (0.0, 1, 1, 1, 0.3);
            popover_inset_grad.add_color_stop_rgba (1.0, 1, 1, 1, 0.1);
            preview_bg.draw.connect ( (ctx) => {
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
                Drawing.cairo_pill (ctx, 0, 0, this.bar.width, this.BAR_HEIGHT);
                ctx.set_source (bar_shadow_grad);
                ctx.fill ();
                //outline
                Drawing.cairo_pill (ctx, 1, 1, this.bar.width - 2, this.BAR_HEIGHT - 2);
                ctx.set_source_rgba (0, 0, 0, 0.4);
                ctx.fill ();
                //bg
                Drawing.cairo_pill (ctx, 2, 2, this.bar.width - 4, this.BAR_HEIGHT - 4);
                ctx.set_source (bar_grad);
                ctx.fill ();
                //buffering
                if (this._buffered != 0.0){
                    Drawing.cairo_half_pill (ctx, 2, 2, 
                        (this._buffered / this.preview.duration * this.bar.width) - 4, this.BAR_HEIGHT - 4, Gtk.PositionType.RIGHT);
                    ctx.set_source_rgb (0.6, 0.6, 0.6);
                    ctx.fill ();
                }
                //progress
                if (this._progress != 0.0){
                    Drawing.cairo_half_pill (ctx, 2, 2, (this._progress * this.width) - 4, this.BAR_HEIGHT - 4, Gtk.PositionType.RIGHT);
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
}
