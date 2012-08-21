
namespace Audience.Widgets{

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
                    float y2 = (app.fullscreened)?Gdk.Screen.get_default ().height ()-CONTROLS_HEIGHT:
                                                  this.get_stage ().height - CONTROLS_HEIGHT;
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, y:y2);
                }else if (!_hidden && value){
                    float y2 = (app.fullscreened)?Gdk.Screen.get_default ().height ():
                                                  this.get_stage ().height;
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 1000, y:y2);
                }
                this._hidden = value;
            }
        }

        private App app;

        public Controls (App app) {
            this.app            = app;
            this.layout         = new Clutter.BoxLayout ();
            this.layout_manager = layout;
            this._hidden        = false;

            this.background = new Clutter.CairoTexture (100, CONTROLS_HEIGHT);

            this.current   = new Clutter.Text.full ("", "0", {255,255,255,255});
            this.remaining = new Clutter.Text.full ("", "0", {255,255,255,255});

            this.slider = new MediaSlider ();

            this.play = new Button ("media-playback-start-symbolic", Gtk.Stock.MEDIA_PLAY);
            this.view = new Button ("pane-show-symbolic", Gtk.Stock.GO_BACK, "go-previous-symbolic");
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
