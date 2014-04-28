
public class Audience.Widgets.TimeWidget : Gtk.Grid {
    public Gtk.Label progression_label;
    public Gtk.Label time_label;
    public Gtk.ProgressBar progress_bar;
    public signal void seeked (double val);

    public TimeWidget () {
        orientation = Gtk.Orientation.HORIZONTAL;
        column_spacing = 12;
        progression_label = new Gtk.Label ("");
        time_label = new Gtk.Label ("");
        progress_bar = new Gtk.ProgressBar ();
        progress_bar.hexpand = true;
        add (progression_label);
        add (progress_bar);
        add (time_label);
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);

        var width = parent.get_window ().get_width ();
        if (width > 0 && width >= minimum_width) {
            natural_width = width;
        }
    }

    public void set_progression_time (double current_time, double total_time) {
        progress_bar.fraction = current_time/total_time;
        progression_label.label = seconds_to_time ((int)(current_time / 1000000000));
        time_label.label = "-%s".printf (seconds_to_time ((int)((total_time - current_time) / 1000000000)));
    }
}