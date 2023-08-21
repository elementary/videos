/*-
 * Copyright 2013-2021 elementary, Inc. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

public class Audience.Widgets.PlaylistPopover : Gtk.Popover {
    private const int HEIGHT_OFFSET = 300;

    private Gtk.ListBox playlist;
    private Gtk.Button dvd;

    construct {
        var fil = new Gtk.Button.from_icon_name ("document-open-symbolic") {
            tooltip_text = _("Open file")
        };

        dvd = new Gtk.Button.from_icon_name ("media-optical-symbolic") {
            tooltip_text = _("Play from Disc")
        };

        var clear_playlist_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
            tooltip_text = _("Clear Playlist")
        };

        var rep = new Gtk.ToggleButton () {
            action_name = App.ACTION_PREFIX + App.ACTION_REPEAT,
            icon_name = "media-playlist-no-repeat-symbolic",
            tooltip_text = _("Enable Repeat")
        };

        var playback_manager = PlaybackManager.get_default ();

        playlist = new Gtk.ListBox () {
            can_focus = true,
            hexpand = true,
            vexpand = true,
            selection_mode = Gtk.SelectionMode.BROWSE
        };
        playlist.bind_model (playback_manager.play_queue, widget_create_func);

        var playlist_scrolled = new Gtk.ScrolledWindow () {
            min_content_height = 100,
            min_content_width = 260,
            propagate_natural_height = true,
            child = playlist
        };

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6,
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6,
        };
        grid.attach (playlist_scrolled, 0, 0, 7);
        grid.attach (fil, 0, 1);
        grid.attach (clear_playlist_button, 1, 1);
        grid.attach (dvd, 2, 1);
        grid.attach (rep, 6, 1);

        position = TOP;
        child = grid;

        playlist.row_activated.connect ((item) => {
            string filename = ((PlaylistItem)(item)).filename;
            PlaybackManager.get_default ().play (File.new_for_commandline_arg (filename));
        });

        fil.clicked.connect (() => {
            popdown ();
            ((Audience.Window)((Gtk.Application) Application.get_default ()).active_window).run_open_file (false, false);
        });

        dvd.clicked.connect (() => {
            popdown ();
            ((Audience.Window)((Gtk.Application) Application.get_default ()).active_window).run_open_dvd ();
        });

        clear_playlist_button.clicked.connect (() => {
            popdown ();
            PlaybackManager.get_default ().clear_playlist ();
        });

        rep.toggled.connect ( () => {
            /* app.repeat = rep.active; */
            if (rep.active) {
                rep.icon_name = "media-playlist-repeat-symbolic";
                rep.tooltip_text = _("Disable Repeat");
            } else {
                rep.icon_name = "media-playlist-no-repeat-symbolic";
                rep.tooltip_text = _("Enable Repeat");
            }
        });

        playback_manager.uri_changed.connect (set_current);

        var disk_manager = DiskManager.get_default ();
        set_dvd_visibility (disk_manager.has_media_volumes ());
        disk_manager.volume_found.connect ((vol) => {
            set_dvd_visibility (disk_manager.has_media_volumes ());
        });

        disk_manager.volume_removed.connect ((vol) => {
            set_dvd_visibility (disk_manager.has_media_volumes ());
        });

        map.connect (() => {
            var window_height = ((Gtk.Application) Application.get_default ()).active_window.default_height;
            playlist_scrolled.set_max_content_height (window_height - HEIGHT_OFFSET);
        });
    }

    private void set_dvd_visibility (bool visible) {
        dvd.visible = visible;
    }

    private Gtk.Widget widget_create_func (Object item) {
        var path = (File) item;

        if (!path.query_exists ()) {
            return new Gtk.ListBoxRow ();
        }

        var item_title = Audience.get_title (path.get_basename ());
        var row = new PlaylistItem (item_title, path.get_uri ());
        return row;
    }

    private void set_current (string current_file) {
        var playback_manager = PlaybackManager.get_default ();

        for (int i = 0; i < playback_manager.play_queue.get_n_items (); i++) {
            var row = (PlaylistItem) playlist.get_row_at_index (i);
            if (row.filename == current_file) {
                row.is_playing = true;
            } else {
                row.is_playing = false;
            }
        }
    }
}
