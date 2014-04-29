
public class Audience.Widgets.BottomBar : Gtk.Revealer {
    public bool hovered { get; set; default=false; }
    //public signal void state_changed (bool play);
    private uint hiding_timer = 0;
    private Gtk.Button play_button;
    private Gtk.Button panel_button;
    private Gtk.Popover add_popover;
    private TimeWidget time_widget;
    public signal void run_open (int type);
    public signal void play_toggled ();
    public signal void seeked (double val);
    private bool is_playing = false;

    public BottomBar () {
        transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        var main_actionbar = new Gtk.ActionBar ();

        play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
        play_button.tooltip_text = _("Play");
        play_button.clicked.connect (() => {play_toggled ();});

        var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic", Gtk.IconSize.BUTTON);
        add_button.tooltip_text = _("Open");
        add_button.clicked.connect (() => {add_popover.show_all ();});
        add_popover = new Gtk.Popover (add_button);

        panel_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
        panel_button.tooltip_text = _("Play");
        //panel_button.clicked.connect (() => {play_toggled ();});

        time_widget = new TimeWidget ();
        time_widget.seeked.connect ((val) => {seeked (val);});

        main_actionbar.pack_start (play_button);
        main_actionbar.set_center_widget (time_widget);
        main_actionbar.pack_end (add_button);
        add (main_actionbar);

        pupulate_popover ();

        notify["hovered"].connect (() => {
            if (hovered == false) {
                set_timeout ();
            } else {
                if (hiding_timer != 0) {
                    Source.remove (hiding_timer);
                    hiding_timer = 0;
                }
            }
        });
        show_all ();
    }

    private void pupulate_popover () {
        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.row_spacing = 6;
        grid.margin = 6;
        
        var fil   = new Gtk.Button.with_label (_("Add from Harddrive…"));
        fil.image = new Gtk.Image.from_icon_name ("document-open", Gtk.IconSize.DIALOG);
        var dvd   = new Gtk.Button.with_label (_("Play a DVD…"));
        dvd.image = new Gtk.Image.from_icon_name ("media-cdrom", Gtk.IconSize.DIALOG);
        var net   = new Gtk.Button.with_label (_("Network File…"));
        net.image = new Gtk.Image.from_icon_name ("internet-web-browser", Gtk.IconSize.DIALOG);

        fil.clicked.connect ( () => {
            add_popover.hide ();
            run_open (0);
        });
        dvd.clicked.connect ( () => {
            add_popover.hide ();
            run_open (2);
        });
        net.clicked.connect ( () => {
            /*var entry = new Gtk.Entry ();
            entry.secondary_icon_stock = Gtk.Stock.OPEN;
            entry.icon_release.connect ( (pos, e) => {
                open_file (entry.text);
                video_player.playing = true;
                pop.destroy ();
            });
            box.remove (net);
            box.reorder_child (entry, 2);
            entry.show ();*/
        });

        grid.add (fil);
        grid.add (dvd);
        //grid.add (net);
        add_popover.add (grid);
    }

    public void toggle_play_pause () {
        is_playing = !is_playing;
        if (is_playing == true) {
            play_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            play_button.tooltip_text = _("Pause");
        } else {
            play_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
            play_button.tooltip_text = _("Play");
        }
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);

        var width = parent.get_window ().get_width ();
        if (width > 0 && width >= minimum_width) {
            natural_width = width;
        }
    }

    public void set_progression_time (double current_time, double total_time) {
        time_widget.set_progression_time (current_time, total_time);
    }

    private void set_timeout () {
        if (hiding_timer != 0)
            Source.remove (hiding_timer);

        hiding_timer = GLib.Timeout.add (2000, () => {
            if (hovered == true || add_popover.visible == true || is_playing == false) {
                hiding_timer = 0;
                return false;
            }
            set_reveal_child (false);
            hiding_timer = 0;
            return false;
        });
    }
}