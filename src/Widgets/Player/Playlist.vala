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
    public signal void play (File path);
    public signal void item_added ();
    public signal void stop_video ();

    private int current = 0;

    private const Gtk.TargetEntry[] TARGET_ENTRIES = {
        {"PLAYLIST_ITEM", Gtk.TargetFlags.SAME_APP, 0}
    };

    public Playlist () {
        Object (
            can_focus: true,
            expand: true,
            selection_mode: Gtk.SelectionMode.BROWSE
        );

        row_activated.connect ((item) => {
            string filename = (item as PlaylistItem).filename;
            play (File.new_for_commandline_arg (filename));
        });

        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, TARGET_ENTRIES, Gdk.DragAction.MOVE);
        drag_data_received.connect (on_drag_data_received);

        // Automatically load from gsettings last_played_videos
        restore_playlist ();
    }

    ~Playlist () {
        save_playlist ();
    }

    public bool next () {
        var children = get_children ();
        current++;
        if (current >= children.length ()) {
            current = 0;
            return false;
        }

        var next_item = (children.nth_data (current) as PlaylistItem);
        play (File.new_for_commandline_arg (next_item.filename));
        return true;
    }

    public void previous () {
        var children = get_children ();
        current--;
        if (current < 0) {
            var first_item = children.first ().data as PlaylistItem;
            play (File.new_for_commandline_arg (first_item.filename));
            return;
        }

        var next_item = (children.nth_data (current) as PlaylistItem);
        play (File.new_for_commandline_arg (next_item.filename));
    }

    public void add_item (File path) {
        if (!path.query_exists ()) {
            return;
        }

        var file_name = path.get_uri ();
        bool exist = false;

        foreach (Gtk.Widget item in get_children ()) {
            string name = (item as PlaylistItem).filename;
            if (name == file_name) {
                exist = true;
            }
        }

        if (exist) {
            return;
        }

        var row = new PlaylistItem (Audience.get_title (path.get_basename ()), path.get_uri ());
        add (row);
        item_added ();
        connect_row_signals (row);
    }

    public void remove_item (File path) {
        var file_name = path.get_uri ();

        foreach (Gtk.Widget item in get_children ()) {
            string name = (item as PlaylistItem).filename;
            if (name == file_name) {
                remove (item);
                return;
            }
        }
    }

    public void clear_items () {
        current = 0;
        foreach (Gtk.Widget item in get_children ()) {
            remove (item);
        }

        stop_video ();
    }

    public File? get_first_item () {
        var children = get_children ();
        if (children.length () > 0) {
            var first_item = children.first ().data as PlaylistItem;
            return File.new_for_commandline_arg (first_item.filename);
        }

        return null;
    }

    public int get_current () {
        return current;
    }

    public void set_current (string current_file) {
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

    public List<string> get_all_items () {
        var list = new List<string> ();
        foreach (Gtk.Widget item in get_children ()) {
            string name = (item as PlaylistItem).filename;
            list.append (name);
        }

        return (owned) list;
    }

    public void save_playlist () {
        if (Audience.App.get_instance ().mainwindow.is_privacy_mode_enabled ()) {
            return;
        }

        var list = get_all_items ();

        uint i = 0;
        var videos = new string[list.length ()];
        foreach (var filename in list) {
            videos[i] = filename;
            i++;
        }

        settings.set_strv ("last-played-videos", videos);

    }

    private void restore_playlist () {
        this.current = 0;

        for (int i = 0; i < settings.get_strv ("last-played-videos").length; i++) {
            if (settings.get_strv ("last-played-videos")[i] == settings.get_string ("current-video"))
                this.current = i;
            add_item (File.new_for_uri (settings.get_strv ("last-played-videos")[i]));
        }
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

    private void connect_row_signals (PlaylistItem row) {
        row.remove_item.connect (() => {
            remove_item (File.new_for_path (row.filename));
            if (row.is_playing) {
                next ();
            }
            remove (row);
        }); 
    }
}
