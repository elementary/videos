/*-
 * Copyright (c) 2013-2021 elementary, Inc. (https://elementary.io)
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
    public Playlist playlist { get; private set; }
    public Gtk.ToggleButton rep { get; private set; }

    private Gtk.Button dvd;
    private const int HEIGHT_OFFSET = 300;

    construct {
        var fil = new Gtk.Button.from_icon_name ("document-open-symbolic", Gtk.IconSize.BUTTON) {
            tooltip_text = _("Open file")
        };

        dvd = new Gtk.Button.from_icon_name ("media-optical-symbolic", Gtk.IconSize.BUTTON) {
            tooltip_text = _("Play from Disc")
        };

        var clear_playlist_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.BUTTON);
        clear_playlist_button.tooltip_text = _("Clear Playlist");

        rep = new Gtk.ToggleButton () {
            image = new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON),
            tooltip_text = _("Enable Repeat")
        };

        var playlist_scrolled = new Gtk.ScrolledWindow (null, null) {
            min_content_height = 100,
            min_content_width = 260,
            propagate_natural_height = true
        };

        playlist = new Playlist ();
        playlist_scrolled.add (playlist);

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6,
            margin = 6
        };
        grid.attach (playlist_scrolled, 0, 0, 7);
        grid.attach (fil, 0, 1);
        grid.attach (clear_playlist_button, 1, 1);
        grid.attach (dvd, 2, 1);
        grid.attach (rep, 6, 1);

        add (grid);

        fil.clicked.connect (() => {
            popdown ();
            ((Audience.Window)((Gtk.Application) Application.get_default ()).active_window).run_open_file (false, false);
        });

        dvd.clicked.connect (() => {
            popdown ();
            ((Audience.Window)((Gtk.Application) Application.get_default ()).active_window).run_open_dvd ();
        });

        clear_playlist_button.clicked.connect (() => {
            playlist.clear_items ();
        });

        rep.toggled.connect ( () => {
            /* app.repeat = rep.active; */
            if (rep.active) {
                ((Gtk.Image) rep.image).icon_name = "media-playlist-repeat-symbolic";
                rep.tooltip_text = _("Disable Repeat");
            } else {
                ((Gtk.Image) rep.image).icon_name = "media-playlist-no-repeat-symbolic";
                rep.tooltip_text = _("Enable Repeat");
            }
        });

        var disk_manager = DiskManager.get_default ();
        set_dvd_visibility (disk_manager.has_media_volumes ());
        disk_manager.volume_found.connect ((vol) => {
            set_dvd_visibility (disk_manager.has_media_volumes ());
        });

        disk_manager.volume_removed.connect ((vol) => {
            set_dvd_visibility (disk_manager.has_media_volumes ());
        });

        map.connect (() => {
            var window_height = ((Gtk.Application) Application.get_default ()).active_window.get_window ().get_height ();
            playlist_scrolled.set_max_content_height (window_height - HEIGHT_OFFSET);
        });
    }

    private void set_dvd_visibility (bool visible) {
        dvd.no_show_all = !visible;
        dvd.visible = visible;
    }
}
