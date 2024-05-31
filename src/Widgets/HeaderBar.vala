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
            action_name = Window.ACTION_PREFIX + Window.ACTION_BACK,
            valign = Gtk.Align.CENTER
        };
        navigation_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

        unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic") {
            visible = false,
            tooltip_text = _("Unfullscreen")
        };

        var title_label = new Gtk.Label ("");
        title_label.add_css_class (Granite.STYLE_CLASS_TITLE_LABEL);

        header_bar = new Gtk.HeaderBar () {
            show_title_buttons = true,
            title_widget = title_label,
            hexpand = true
        };
        header_bar.pack_start (navigation_button);
        header_bar.pack_end (unfullscreen_button);
        header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        append (header_bar);

        map.connect (() => {
            var current_page = (Adw.NavigationPage) get_ancestor (typeof (Adw.NavigationPage));
            var navigation_view = (Adw.NavigationView) get_ancestor (typeof (Adw.NavigationView));

            current_page.bind_property ("title", title_label, "label", SYNC_CREATE);

            var previous_page = navigation_view.get_previous_page (current_page);
            if (previous_page != null) {
                navigation_button.visible = true;
                navigation_button.label = previous_page.title;
            } else {
                navigation_button.visible = false;
            }

            binding = ((Window) get_root ()).bind_property ("fullscreened", this, "fullscreened", SYNC_CREATE);
        });

        unmap.connect (() => binding.unbind ());

        unfullscreen_button.clicked.connect (() => ((Window) get_root ()).unfullscreen ());
    }
}
