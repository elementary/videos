
namespace Audience.Widgets{

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
}
