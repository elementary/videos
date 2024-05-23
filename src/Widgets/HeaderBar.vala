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

    public Gtk.HeaderBar header_bar { get; construct; }

    private Gtk.Button unfullscreen_button;
    private unowned GLib.Binding binding;

    construct {
        var navigation_button = new Gtk.Button.with_label ("") {
            valign = Gtk.Align.CENTER
        };
        navigation_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

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
        header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        append (header_bar);

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
