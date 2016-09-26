/*-
 * Copyright (c) 2016-2016 elementary LLC.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 *
 */

public class Granite.Widgets.Toast : Gtk.Revealer {
    Gtk.Label notification_label;
    Gtk.Button restore_button;

    public signal void close ();
    public signal void accept ();

    construct {
        margin = 3;
        halign = Gtk.Align.CENTER;
        valign = Gtk.Align.START;

        restore_button = new Gtk.Button ();
        restore_button.clicked.connect (() => {
            reveal_child = false;
            accept ();
        });

        var close_button = new Gtk.Button.from_icon_name ("close-symbolic", Gtk.IconSize.MENU);
        close_button.get_style_context ().add_class ("close-button");
        close_button.clicked.connect (() => {
            reveal_child = false;
            close ();
        });
        
        notification_label = new Gtk.Label ("");

        var notification_box = new Gtk.Grid ();
        notification_box.column_spacing = 12;
        notification_box.add (close_button);
        notification_box.add (notification_label);
        notification_box.add (restore_button);

        var notification_frame = new Gtk.Frame (null);
        notification_frame.get_style_context ().add_class ("app-notification");
        notification_frame.add (notification_box);

        add (notification_frame);
    }
    
    public void set_button_label (string text) {
        restore_button.label = text;
    }
    
    public void set_notification (string text) {
        notification_label.label = text;
        reveal_child = true;
    }
}
