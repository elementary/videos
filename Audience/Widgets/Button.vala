
namespace Audience.Widgets{

    public class Button : GtkClutter.Texture {
        public signal void clicked ();

		bool pressed = false;

        public Button (string icon, string fallback, string alt_fallback=""){
            set_icon (icon, fallback, alt_fallback);

            reactive = true;
			width = 16;
			height = 16;
            opacity = 255;
        }

		public override bool leave_event (Clutter.CrossingEvent event) {
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity:255);
			return true;
		}

		public override bool enter_event (Clutter.CrossingEvent event) {
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity:170);
			return true;
		}

		public override bool button_press_event (Clutter.ButtonEvent event) {
			pressed = true;
			return true;
		}

		public override bool button_release_event (Clutter.ButtonEvent event) {
			if (pressed) {
				clicked ();
				pressed = false;
			}
			return true;
		}

        public void set_icon (string icon, string fallback, string alt_fallback="") {
            try {
                var ti = new ThemedIcon.from_names ({icon, alt_fallback, fallback});
                var l = Gtk.IconTheme.get_default ().lookup_by_gicon (ti, 16, 0);
                if (l != null) {
                    this.set_from_pixbuf (l.load_symbolic ({1.0,1.0,1.0,1.0}, null, null, null, null));
                } else {
                    warning("NULL detected when trying to load icon: " + icon + " (or " + fallback + ")");
                }
            } catch (Error e){warning (e.message);}
        }
    }
}
