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

public class Audience.Widgets.Playlist : Gtk.ListBox {
    private int current = 0;

    private const Gtk.TargetEntry[] TARGET_ENTRIES = {
        {"PLAYLIST_ITEM", Gtk.TargetFlags.SAME_APP, 0}
    };

    construct {
        can_focus = true;
        hexpand = true;
        vexpand = true;
        selection_mode = Gtk.SelectionMode.BROWSE;

        row_activated.connect ((item) => {
            string filename = ((PlaylistItem)(item)).filename;
            PlaybackManager.get_default ().play (File.new_for_commandline_arg (filename));
        });

        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, TARGET_ENTRIES, Gdk.DragAction.MOVE);
        drag_data_received.connect (on_drag_data_received);

        for (int i = 0; i < settings.get_strv ("last-played-videos").length; i++) {
            if (settings.get_strv ("last-played-videos")[i] == settings.get_string ("current-video")) {
                current = i;
            }
            add_item (File.new_for_uri (settings.get_strv ("last-played-videos")[i]));
        }

        var playback_manager = PlaybackManager.get_default ();
        playback_manager.clear_playlist.connect (clear_items);
        playback_manager.get_first_item.connect (get_first_item);
        playback_manager.next.connect (next);
        playback_manager.previous.connect (previous);
        playback_manager.queue_file.connect (add_item);
        playback_manager.save_playlist.connect (save_playlist);
        playback_manager.uri_changed.connect (set_current);
    }

    ~Playlist () {
        save_playlist ();
    }

    private bool next () {
        var children = get_children ();
        current++;
        if (current >= children.length ()) {
            current = 0;
            return false;
        }

        var next_item = (children.nth_data (current) as PlaylistItem);
        PlaybackManager.get_default ().play (File.new_for_commandline_arg (next_item.filename));
        return true;
    }

    private void previous () {
        var children = get_children ();
        current--;
        if (current < 0) {
            var first_item = children.first ().data as PlaylistItem;
            PlaybackManager.get_default ().play (File.new_for_commandline_arg (first_item.filename));
            return;
        }

        var next_item = (children.nth_data (current) as PlaylistItem);
        PlaybackManager.get_default ().play (File.new_for_commandline_arg (next_item.filename));
    }

    private void add_item (File path) {
        if (!path.query_exists ()) {
            return;
        }

        var file_name = path.get_uri ();
        bool exist = false;

        foreach (Gtk.Widget item in get_children ()) {
            string name = ((PlaylistItem)(item)).filename;
            if (name == file_name) {
                exist = true;
            }
        }

        if (exist) {
            return;
        }

        var row = new PlaylistItem (Audience.get_title (path.get_basename ()), path.get_uri ());
        add (row);
        PlaybackManager.get_default ().item_added ();
    }

    private void clear_items (bool should_stop = true) {
        current = 0;
        foreach (Gtk.Widget item in get_children ()) {
            remove (item);
        }

        if (should_stop) {
            PlaybackManager.get_default ().stop ();
        }
    }

    private File? get_first_item () {
        var children = get_children ();
        if (children.length () > 0) {
            var first_item = children.first ().data as PlaylistItem;
            return File.new_for_commandline_arg (first_item.filename);
        }

        return null;
    }

    private void set_current (string current_file) {
        int count = 0;
        int current_played = 0;

        foreach (Gtk.Widget item in get_children ()) {
            var row = item as PlaylistItem;
            string name = row.filename;
            if (name == current_file) {
                current_played = count;
                row.is_playing = true;
            } else {
                row.is_playing = false;
            }
            count++;
        }

        this.current = current_played;
    }

    private void save_playlist () {
        var privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");
        if (!privacy_settings.get_boolean ("remember-recent-files") || !privacy_settings.get_boolean ("remember-app-usage")) {
            return;
        }

        string[] videos = {};
        foreach (unowned var child in get_children ()) {
            var filename = ((PlaylistItem) child).filename;
            videos += filename;
        }

        settings.set_strv ("last-played-videos", videos);
    }

    private void on_drag_data_received (Gdk.DragContext context, int x, int y,
        Gtk.SelectionData selection_data, uint target_type, uint time) {
        PlaylistItem target;
        Gtk.Widget row;
        PlaylistItem source;
        int new_position;
        int old_position;

        target = (PlaylistItem) get_row_at_y (y);
        if (target == null) {
            return;
        }

        new_position = target.get_index ();
        row = ((Gtk.Widget[]) selection_data.get_data ())[0];
        source = (PlaylistItem) row.get_ancestor (typeof (PlaylistItem));
        old_position = source.get_index ();

        if (source == target) {
            return;
        }

        remove (source);
        insert (source, new_position);
    }
}
