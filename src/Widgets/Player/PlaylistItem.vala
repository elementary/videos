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
    public signal void remove_item ();
    public bool is_playing { get; set; }
    public string title { get; construct; }
    public string filename { get; construct; }

    private const Gtk.TargetEntry[] TARGET_ENTRIES = {
        {"PLAYLIST_ITEM", Gtk.TargetFlags.SAME_APP, 0}
    };

    public PlaylistItem (string title, string filename) {
        Object (
            title: title,
            filename: filename
        );
    }

    construct {
        var play_icon = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);

        var play_revealer = new Gtk.Revealer ();
        play_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        play_revealer.add (play_icon);

        var track_name_label = new Gtk.Label (title);
        track_name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;

        var delete_button = new Gtk.Image.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.BUTTON);
        delete_button.tooltip_text = _("Remove video from playlist");
        delete_button.halign = Gtk.Align.END;
        delete_button.expand = true;

        var remove_item_event_box = new Gtk.EventBox ();
        remove_item_event_box.add (delete_button);
        remove_item_event_box.button_release_event.connect (on_button_released);

        var action_revealer = new Gtk.Revealer ();
        action_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        action_revealer.add (remove_item_event_box);
        action_revealer.transition_duration = 1000;
        action_revealer.show_all ();
        action_revealer.set_reveal_child (false);

        var grid = new Gtk.Grid ();
        grid.expand = true;
        grid.margin = 3;
        grid.margin_bottom = grid.margin_top = 6;
        grid.column_spacing = 6;
        grid.attach (play_revealer, 0, 0, 1, 1);
        grid.attach (track_name_label, 1, 0, 3, 1);
        grid.attach (action_revealer, 4, 0, 1, 1);

        // Drag source must have a GdkWindow. GTK4 will remove the limitation.
        var dnd_event_box = new Gtk.EventBox ();
        dnd_event_box.drag_begin.connect (on_drag_begin);
        dnd_event_box.drag_data_get.connect (on_drag_data_get);
        dnd_event_box.add (grid);

        Gtk.drag_source_set (dnd_event_box, Gdk.ModifierType.BUTTON1_MASK, TARGET_ENTRIES, Gdk.DragAction.MOVE);

        dnd_event_box.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);

        dnd_event_box.enter_notify_event.connect ((event) => {
            action_revealer.set_reveal_child (true);
            return Gdk.EVENT_PROPAGATE;
        });

        dnd_event_box.leave_notify_event.connect ((event) => {
            if (event.detail == Gdk.NotifyType.INFERIOR) {
                return Gdk.EVENT_PROPAGATE;
            }

            action_revealer.set_reveal_child (false);
            return Gdk.EVENT_PROPAGATE;
        });



        set_tooltip_text (title);

        add (dnd_event_box);
        show_all ();

        bind_property ("is-playing", play_revealer, "reveal-child");
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

    private bool on_button_released (Gtk.Widget sender, Gdk.EventButton event) {
        remove_item ();
        return Gdk.EVENT_STOP;
    }
}
