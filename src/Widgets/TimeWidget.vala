
public class Audience.Widgets.TimeWidget : Gtk.Grid {
    public Gtk.Label progression_label;
    public Gtk.Label time_label;
    public Gtk.Scale scale;
    public signal void seeked (double val);
    private bool is_seeking = false;
    private bool released = true;
    private uint timeout_id = 0;

    public TimeWidget () {
        orientation = Gtk.Orientation.HORIZONTAL;
        column_spacing = 12;
        halign = Gtk.Align.CENTER;
        progression_label = new Gtk.Label ("");
        time_label = new Gtk.Label ("");
        scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 1, 0.1);
        scale.expand = true;
        scale.draw_value = false;
        scale.can_focus = false;
        scale.button_press_event.connect ((event) => {
            is_seeking = true;
            released = false;

            if (timeout_id != 0)
                Source.remove (timeout_id);

            timeout_id = Timeout.add (300, () => {
                if (released == false)
                    return true;
                seeked (scale.get_value ());
                is_seeking = false;
                return false;
            });
            return false;
        });
        scale.button_release_event.connect ((event) => {released = true; return false;});
        add (progression_label);
        add (scale);
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
        if (is_seeking == true)
            return;
        scale.set_value (current_time/total_time);
        progression_label.label = seconds_to_time ((int)(current_time / 1000000000));
        time_label.label = seconds_to_time ((int)((total_time - current_time) / 1000000000));
    }
}