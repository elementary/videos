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
    private bool is_playing;
    private string title;
    public string filename {get; set;}

    private Gtk.Image play_icon;
    private Gtk.EventBox dnd_event_box;
    private Gtk.Label track_name_label;
    private Gtk.Grid grid;

    private const string PLAY_ICON = "media-playback-start-symbolic";
    private const Gtk.TargetEntry[] TARGET_ENTRIES = {
        {"PLAYLIST_ITEM", Gtk.TargetFlags.SAME_APP, 0}
    };

    public PlaylistItem (bool is_playing, string title, string filename) {
        this.is_playing = is_playing;
        this.title = title;
        this.filename = filename;

        track_name_label.label = title;
        grid.attach (track_name_label, 1, 0, 2, 1);
        show_all ();

        Gtk.drag_source_set (dnd_event_box, Gdk.ModifierType.BUTTON1_MASK, TARGET_ENTRIES, Gdk.DragAction.MOVE);
        dnd_event_box.drag_begin.connect (on_drag_begin);
        dnd_event_box.drag_data_get.connect (on_drag_data_get);

    }

    construct {
        grid = new Gtk.Grid ();
        grid.margin = 3;
        grid.margin_bottom = grid.margin_top = 6;
        grid.column_spacing = 6;
        grid.row_spacing = 3;

        dnd_event_box = new Gtk.EventBox ();
        dnd_event_box.add (grid);
        add (dnd_event_box);

        play_icon = new Gtk.Image ();
        grid.attach (play_icon, 0, 0, 1, 1);

        track_name_label = new Gtk.Label ("");
        track_name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
    }

    public void set_play_state () {
        is_playing = true;
        play_icon.icon_name = PLAY_ICON;
    }

    public void set_unplay_state () {
        play_icon.icon_name = "";
        is_playing = true;
    }

    private void on_drag_begin (Gtk.Widget widget, Gdk.DragContext context) {
        var row = (PlaylistItem) widget.get_ancestor (typeof (PlaylistItem));

        Gtk.Allocation alloc;
        row.get_allocation (out alloc);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
        var cr = new Cairo.Context (surface);
        row.draw (cr);

        int x, y;
        widget.translate_coordinates (row, 0, 0, out x, out y);
        surface.set_device_offset (-x, -y);
        Gtk.drag_set_icon_surface (context, surface);
    }

    private void on_drag_data_get (Gtk.Widget widget, Gdk.DragContext context, Gtk.SelectionData selection_data,
        uint target_type, uint time) {
        uchar[] data = new uchar[(sizeof (PlaylistItem))];
        ((Gtk.Widget[])data)[0] = widget;

        selection_data.set (
            Gdk.Atom.intern_static_string ("PLAYLIST_ITEM"), 32, data
        );
    }
}
