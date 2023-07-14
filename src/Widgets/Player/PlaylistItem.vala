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
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/

public class Audience.Widgets.PlaylistItem : Gtk.ListBoxRow {
    public bool is_playing { get; set; }
    public string title { get; construct; }
    public string filename { get; construct; }

    public PlaylistItem (string title, string filename) {
        Object (
            title: title,
            filename: filename
        );
    }

    construct {
        var play_icon = new Gtk.Image.from_icon_name ("media-playback-start-symbolic");

        var play_revealer = new Gtk.Revealer () {
            child = play_icon,
            transition_type = CROSSFADE
        };

        var track_name_label = new Gtk.Label (title) {
            ellipsize = MIDDLE
        };

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        box.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        box.append (play_revealer);
        box.append (track_name_label);

        set_tooltip_text (title);

        child = box;

        bind_property ("is-playing", play_revealer, "reveal-child");

        var drag_source = new Gtk.DragSource ();
        add_controller (drag_source);
        drag_source.prepare.connect (() => {
            var val = Value (typeof (PlaylistItem));
            val.set_object (this);
            var content_provider = new Gdk.ContentProvider.for_value (val);
            return content_provider;
        });
    }
}
