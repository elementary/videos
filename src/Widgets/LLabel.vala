
namespace Audience.Widgets{

    class LLabel : Gtk.Label {
        public LLabel (string label) {
            this.set_halign (Gtk.Align.START);
            this.label = label;
        }
        public LLabel.indent (string label) {
            this (label);
            this.margin_left = 10;
        }
        public LLabel.markup (string label) {
            this (label);
            this.use_markup = true;
        }
        public LLabel.right (string label) {
            this.set_halign (Gtk.Align.END);
            this.label = label;
        }
        public LLabel.right_with_markup (string label) {
            this.set_halign (Gtk.Align.END);
            this.use_markup = true;
            this.label = label;
        }
    }
}
