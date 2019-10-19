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

public class Audience.UnsupportedFileDialog : Granite.MessageDialog {
    public string content_type {get; construct;}
    public string filename {get; construct;}
    public string uri {get; construct;}

    public UnsupportedFileDialog (string uri, string filename, string content_type) {
        Object (
            title: "",
            primary_text: _("Unrecognized file format"),
            secondary_text: _("Videos might not be able to play the file '%s'.".printf (filename)),
            buttons: Gtk.ButtonsType.CANCEL,
            image_icon: new ThemedIcon ("dialog-error"),
            window_position: Gtk.WindowPosition.CENTER,
            content_type: content_type,
            filename: filename,
            uri: uri

        );
    }

    construct {
        var play_anyway_button = add_button (_("Play Anyway"), Gtk.ResponseType.ACCEPT);
        play_anyway_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var error_text = _("Unable to play file at : " + uri + "\nReason: Unplayable Content Type " + content_type);
        show_error_details (error_text);
    }
}
