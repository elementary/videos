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
    private bool is_playing {get; set;}
    public string title {get; set;}
    public string filename {get; set;}

    private Gtk.Image play_icon;
    private Gtk.Label track_name_label;
    private Gtk.Grid grid;

    public PlaylistItem(bool is_playing, string title, string filename) {
        this.is_playing = is_playing;
        this.title = title;
        this.filename = filename;

        if (is_playing == true) {
            play_icon.icon_name = "media-playback-start-symbolic";
            grid.attach (play_icon, 0, 0, 1, 1);
        }

        track_name_label.label = title;
        grid.attach (track_name_label, 1, 0, 2, 1);
        show_all ();

    }

    construct {
        grid = new Gtk.Grid ();
        grid.margin = 12;
        grid.margin_bottom = grid.margin_top = 6;
        grid.column_spacing = 12;
        grid.row_spacing = 3;
        add (grid);

        play_icon  = new Gtk.Image ();

        track_name_label = new Gtk.Label ("");
        track_name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
    }
}