

public class Audience.EpisodeItem : Gtk.Box {
    private Gtk.Label title_label;
    private Objects.MediaItem? video;

    construct {
        var move_to_trash = new Gtk.Button () {
            child = new Gtk.Label (_("Move to Trash")) { halign = START }
        };
        move_to_trash.add_css_class (Granite.STYLE_CLASS_MENUITEM);

        var context_menu_box = new Gtk.Box (VERTICAL, 0);
        context_menu_box.append (move_to_trash);

        var context_menu = new Gtk.Popover () {
            child = context_menu_box,
            halign = START,
            has_arrow = false,
            position = BOTTOM
        };
        context_menu.add_css_class (Granite.STYLE_CLASS_MENU);
        context_menu.set_parent (this);

        title_label = new Gtk.Label ("") {
            halign = START
        };

        orientation = VERTICAL;
        hexpand = true;
        margin_top = 12;
        margin_bottom = 12;
        margin_start = 12;
        margin_end = 12;

        append (title_label);

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        add_controller (gesture_click);
        gesture_click.released.connect ((n_press, x, y) => {
            context_menu.pointing_to = Gdk.Rectangle () {
                x = (int) x,
                y = (int) y
            };

            context_menu.popup ();
        });

        move_to_trash.clicked.connect (() => {
            context_menu.popdown ();
            // video.trashed ();
            // try {
            //     video.video_file.trash ();
            //     Services.LibraryManager.get_instance ().deleted_items (video.video_file.get_path ());
            // } catch (Error e) {
            //     warning (e.message);
            // }
        });
    }

    public void bind (Objects.MediaItem video) {
        this.video = video;
        title_label.label = video.title;
    }
}
