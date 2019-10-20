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
    public string title {get; construct;}
    public string filename {get; construct;}

    private Gtk.Image play_icon;
    private Gtk.EventBox dnd_event_box;
    private Gtk.Label track_name_label;
    private Gtk.Grid grid;
    private Gtk.Box action_box;

    public signal void remove_playlist_item ();

    private const string PLAY_ICON = "media-playback-start-symbolic";
    private const Gtk.TargetEntry[] TARGET_ENTRIES = {
        {"PLAYLIST_ITEM", Gtk.TargetFlags.SAME_APP, 0}
    };

    public PlaylistItem (string title, string filename) {
        Object (
            title: title,
            filename: filename
        );

        show_all ();
    }

    construct {
        grid = new Gtk.Grid ();
        grid.margin = 3;
        grid.margin_bottom = grid.margin_top = 6;
        grid.column_spacing = 6;
        grid.row_spacing = 3;

        // Drag source must have a GdkWindow. GTK4 will remove the limitation.
        dnd_event_box = new Gtk.EventBox ();
        dnd_event_box.add (grid);
        add (dnd_event_box);

        play_icon = new Gtk.Image ();
        grid.attach (play_icon, 0, 0, 1, 1);

        track_name_label = new Gtk.Label (title);
        track_name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        grid.attach (track_name_label, 1, 0, 2, 1);

        var delete_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU);
        delete_button.valign = Gtk.Align.CENTER;
        delete_button.halign = Gtk.Align.END;
        delete_button.tooltip_text = _("Remove video from playlist");
        delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        action_box.expand = true;
        action_box.halign = Gtk.Align.END;
        action_box.visible = false;

        action_box.pack_start (delete_button, false, false, 0);

        var action_revealer = new Gtk.Revealer ();
        action_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        action_revealer.add (action_box);
        action_revealer.transition_duration = 1000;
        action_revealer.show_all ();
        action_revealer.set_reveal_child (false);

        grid.attach_next_to (action_revealer, track_name_label, Gtk.PositionType.RIGHT);

        dnd_event_box.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);

        dnd_event_box.enter_notify_event.connect (event => {
            action_revealer.set_reveal_child (true);
            action_box.visible = true;
            return false;
        });

        dnd_event_box.leave_notify_event.connect (event => {
            if (event.detail == Gdk.NotifyType.INFERIOR) {
                return false;
            }

            action_revealer.set_reveal_child (false);
            action_box.visible = false;
            return false;
        });

        delete_button.clicked.connect (() => remove_playlist_item ());

        Gtk.drag_source_set (dnd_event_box, Gdk.ModifierType.BUTTON1_MASK, TARGET_ENTRIES, Gdk.DragAction.MOVE);
        dnd_event_box.drag_begin.connect (on_drag_begin);
        dnd_event_box.drag_data_get.connect (on_drag_data_get);

    }

    public void set_play_state () {
        play_icon.icon_name = PLAY_ICON;
    }

    public void set_unplay_state () {
        play_icon.icon_name = "";
    }

    private void on_drag_begin (Gtk.Widget widget, Gdk.DragContext context) {
        var row = (PlaylistItem) widget.get_ancestor (typeof (PlaylistItem));
        action_box.visible = false;

        Gtk.Allocation alloc;
        row.get_allocation (out alloc);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
        var cr = new Cairo.Context (surface);
        row.draw (cr);

        int x, y;
        widget.translate_coordinates (row, 0, 0, out x, out y);
        surface.set_device_offset (-x, -y);
        Gtk.drag_set_icon_surface (context, surface);
        action_box.visible = true;
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
