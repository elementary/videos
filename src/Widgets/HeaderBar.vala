/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Audience.HeaderBar : Gtk.Box {
    public bool fullscreened {
        set {
            if (value) {
                header_bar.set_decoration_layout ("close");
            } else {
                header_bar.set_decoration_layout (null);
            }

            unfullscreen_button.visible = value;
        }
    }

    public bool flat { get; construct; }
    public Gtk.HeaderBar header_bar { get; construct; }

    private Gtk.Button unfullscreen_button;
    private unowned GLib.Binding binding;

    public HeaderBar (bool flat = true) {
        Object (flat: flat);
    }

    construct {
        var navigation_button = new Gtk.Button.with_label ("") {
            valign = Gtk.Align.CENTER
        };
        navigation_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

        var force_dark_mode_button = new Granite.SwitchModelButton (_("Always use Dark Mode"));

        var popover_content = new Gtk.Box (VERTICAL, 0) {
            margin_bottom = 3,
            margin_top = 3
        };
        popover_content.append (force_dark_mode_button);

        var popover = new Gtk.Popover () {
            child = popover_content
        };

        var menu_button = new Gtk.MenuButton () {
            primary = true,
            popover = popover,
            icon_name = "open-menu"
        };
        menu_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic") {
            visible = false,
            tooltip_text = _("Unfullscreen")
        };

        header_bar = new Gtk.HeaderBar () {
            show_title_buttons = true,
            hexpand = true
        };
        header_bar.pack_start (navigation_button);
        header_bar.pack_end (unfullscreen_button);
        header_bar.pack_end (menu_button);

        if (flat) {
            header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);
        }

        append (header_bar);

        settings.bind ("force-dark-mode", force_dark_mode_button, "active", DEFAULT);

        map.connect (() => {
            var adjacent_page_name = ((Window) get_root ()).get_adjacent_page_name ();
            if (adjacent_page_name != null) {
                navigation_button.visible = true;
                navigation_button.label = adjacent_page_name;
            } else {
                navigation_button.visible = false;
            }

            binding = ((Window) get_root ()).bind_property ("fullscreened", this, "fullscreened", SYNC_CREATE);
        });

        unmap.connect (() => binding.unbind ());

        navigation_button.clicked.connect (() => ((Adw.Leaflet) get_ancestor (typeof (Adw.Leaflet))).navigate (BACK));

        unfullscreen_button.clicked.connect (() => ((Window) get_root ()).unfullscreen ());
    }
}
