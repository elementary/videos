/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class Audience.MissingPluginDialog : Granite.MessageDialog {
    public string plugin_name { get; construct; }
    public string uri { get; construct; }

    public MissingPluginDialog (string uri, string filename, string plugin_name) {
        Object (
            title: "",
            primary_text: _("Missing plugin"),
            secondary_text: _("Videos is unable to play the file '%s'.").printf (filename),
            buttons: Gtk.ButtonsType.CANCEL,
            image_icon: new ThemedIcon ("dialog-error"),
            transient_for: App.get_instance ().mainwindow,
            window_position: Gtk.WindowPosition.CENTER,
            plugin_name: plugin_name,
            uri: uri
        );
    }

    construct {
        var play_anyway_button = add_button (_("Install Plugin"), Gtk.ResponseType.ACCEPT);
        play_anyway_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var error_text = _("'%s' plugin should be installed to play the file at '%s'").printf (plugin_name, uri);
        show_error_details (error_text);

    }
}
