
public class Audience.Widgets.BottomBar : Gtk.Revealer {
    public signal void run_open (int type);
    public signal void play_toggled ();
    public signal void unfullscreen ();
    public signal void seeked (double val);

    public bool hovered { get; set; default=false; }
    public bool fullscreen { get; set; default=false; }
    public SettingsPopover preferences_popover;

    private Gtk.Button play_button;
    private Gtk.Button preferences_button;
    private Gtk.Revealer unfullscreen_revealer;
    private Gtk.Popover playlist_popover;
    private TimeWidget time_widget;
    private bool is_playing = false;
    private uint hiding_timer = 0;

    public BottomBar () {
        transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        var main_actionbar = new Gtk.ActionBar ();
        main_actionbar.opacity = global_opacity;

        play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
        play_button.tooltip_text = _("Play");
        play_button.clicked.connect (() => {play_toggled ();});

        var playlist_button = new Gtk.Button.from_icon_name ("view-list-symbolic", Gtk.IconSize.BUTTON);
        playlist_button.tooltip_text = _("Playlist");
        playlist_button.clicked.connect (() => {playlist_popover.show_all ();playlist_popover.queue_resize ();});

        preferences_button = new Gtk.Button.from_icon_name ("document-properties-symbolic", Gtk.IconSize.BUTTON);
        preferences_button.tooltip_text = _("Settings");
        preferences_button.clicked.connect (() => {preferences_popover.show_all ();playlist_popover.queue_resize ();});

        time_widget = new TimeWidget ();
        time_widget.seeked.connect ((val) => {seeked (val);});

        playlist_popover = new Gtk.Popover (playlist_button);
        preferences_popover = new SettingsPopover (preferences_button);

        main_actionbar.pack_start (play_button);
        main_actionbar.set_center_widget (time_widget);
        main_actionbar.pack_end (preferences_button);
        main_actionbar.pack_end (playlist_button);
        add (main_actionbar);

        pupulate_playlist_popover ();

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

        notify["fullscreen"].connect (() => {
            if (fullscreen == true && child_revealed == true) {
                unfullscreen_revealer.set_reveal_child (true);
            } else if (fullscreen == false && child_revealed == true) {
                unfullscreen_revealer.set_reveal_child (false);
            }
        });

        show_all ();
    }

    public void set_preview_uri (string uri) {
        time_widget.set_preview_uri (uri);
    }

    public Gtk.Revealer get_unfullscreen_button () {
        unfullscreen_revealer = new Gtk.Revealer ();
        unfullscreen_revealer.opacity = global_opacity;
        unfullscreen_revealer.get_style_context ().add_class ("header-bar");
        unfullscreen_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        var unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic", Gtk.IconSize.BUTTON);
        unfullscreen_button.tooltip_text = _("Unfullscreen");
        unfullscreen_button.clicked.connect (() => {unfullscreen ();});
        unfullscreen_revealer.add (unfullscreen_button);
        unfullscreen_revealer.show_all ();
        return unfullscreen_revealer;
    }

    public void toggle_play_pause () {
        is_playing = !is_playing;
        if (is_playing == true) {
            play_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            play_button.tooltip_text = _("Pause");
            set_timeout ();
        } else {
            play_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
            play_button.tooltip_text = _("Play");
            set_reveal_child (true);
        }
    }

    public new void set_reveal_child (bool reveal) {
        base.set_reveal_child (reveal);
        if (reveal == true && fullscreen == true) {
            unfullscreen_revealer.set_reveal_child (reveal);
        } else if (reveal == false) {
            unfullscreen_revealer.set_reveal_child (reveal);
        }
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);

        if (parent.get_window () == null)
            return;
        var width = parent.get_window ().get_width ();
        if (width > 0 && width >= minimum_width) {
            natural_width = width;
        }
    }

    public void set_progression_time (double current_time, double total_time) {
        time_widget.set_progression_time (current_time, total_time);
    }

    private void pupulate_playlist_popover () {
        playlist_popover.opacity = global_opacity;
        var grid = new Gtk.Grid ();
        grid.row_spacing = 6;
        grid.column_spacing = 12;
        grid.margin = 6;

        var fil   = new Gtk.Button.with_label (_("Add from Harddrive…"));
        fil.image = new Gtk.Image.from_icon_name ("document-open", Gtk.IconSize.DIALOG);
        var dvd   = new Gtk.Button.with_label (_("Play a DVD…"));
        dvd.image = new Gtk.Image.from_icon_name ("media-cdrom", Gtk.IconSize.DIALOG);
        var net   = new Gtk.Button.with_label (_("Network File…"));
        net.image = new Gtk.Image.from_icon_name ("internet-web-browser", Gtk.IconSize.DIALOG);

        var playlist_scrolled = new Gtk.ScrolledWindow (null, null);
        var app = ((Audience.App) GLib.Application.get_default ());
        playlist_scrolled.add (app.playlist);

        fil.clicked.connect ( () => {
            playlist_popover.hide ();
            run_open (0);
        });

        dvd.clicked.connect ( () => {
            playlist_popover.hide ();
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

        grid.attach (playlist_scrolled, 0, 0, 2, 1);
        grid.attach (fil, 0, 1, 1, 1);
        grid.attach (dvd, 1, 1, 1, 1);
        //grid.add (net);
        playlist_popover.add (grid);
    }

    private void set_timeout () {
        if (hiding_timer != 0)
            Source.remove (hiding_timer);

        hiding_timer = GLib.Timeout.add (2000, () => {
            if (hovered == true || preferences_popover.visible == true || playlist_popover.visible == true || is_playing == false) {
                hiding_timer = 0;
                return false;
            }
            set_reveal_child (false);
            unfullscreen_revealer.set_reveal_child (false);
            hiding_timer = 0;
            return false;
        });
    }
}