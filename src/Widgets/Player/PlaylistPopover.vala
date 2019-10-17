// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013-2014 Audience Developers (http://launchpad.net/pantheon-chat)
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
    public Playlist playlist;
    public Gtk.ToggleButton rep;
    private Gtk.ScrolledWindow playlist_scrolled;
    private Gtk.Button dvd;
    private const int HEIGHT_OFFSET = 300;

    public PlaylistPopover () {
        opacity = GLOBAL_OPACITY;
        var grid = new Gtk.Grid ();
        grid.row_spacing = 6;
        grid.column_spacing = 12;
        grid.margin = 6;

        var fil = new Gtk.Button.from_icon_name ("document-open-symbolic", Gtk.IconSize.BUTTON);
        fil.tooltip_text = _("Open file");
        dvd = new Gtk.Button.from_icon_name ("media-optical-symbolic", Gtk.IconSize.BUTTON);
        dvd.tooltip_text = _("Play from Disc");

        var clear_playlist_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.BUTTON);
        clear_playlist_button.tooltip_text = _("Clear Playlist");

        rep = new Gtk.ToggleButton ();
        rep.set_image (new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON));
        rep.tooltip_text = _("Enable Repeat");

        playlist_scrolled = new Gtk.ScrolledWindow (null, null);
        playlist_scrolled.min_content_height = 100;
        playlist_scrolled.min_content_width = 260;
        playlist_scrolled.propagate_natural_height = true;

        playlist = new Playlist ();
        playlist_scrolled.add (playlist);

        fil.clicked.connect (() => {
            hide ();
            App.get_instance ().mainwindow.run_open_file (false, false);
        });

        dvd.clicked.connect (() => {
            hide ();
            App.get_instance ().mainwindow.run_open_dvd ();
        });

        clear_playlist_button.clicked.connect (() => {
            playlist.clear_items ();
        });

        rep.toggled.connect ( () => {
            /* app.repeat = rep.active; */
            if (rep.active) {
                rep.set_image (new Gtk.Image.from_icon_name ("media-playlist-repeat-symbolic", Gtk.IconSize.BUTTON));
                rep.set_tooltip_text (_("Disable Repeat"));
            } else {
                rep.set_image (new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON));
                rep.set_tooltip_text (_("Enable Repeat"));
            }
        });

        grid.attach (playlist_scrolled, 0, 0, 7, 1);
        grid.attach (fil, 0, 1, 1, 1);
        grid.attach (clear_playlist_button, 1, 1, 1, 1);
        grid.attach (dvd, 2, 1, 1, 1);
        grid.attach (rep, 6, 1, 1, 1);

        add (grid);

        var disk_manager = DiskManager.get_default ();
        set_dvd_visibility (disk_manager.has_media_volumes ());
        disk_manager.volume_found.connect ((vol) => {
            set_dvd_visibility (disk_manager.has_media_volumes ());
        });

        disk_manager.volume_removed.connect ((vol) => {
            set_dvd_visibility (disk_manager.has_media_volumes ());
        });

        map.connect (() => {
            var window_height = App.get_instance ().mainwindow.get_window ().get_height ();
            playlist_scrolled.set_max_content_height (window_height - HEIGHT_OFFSET);
        });
    }

    private void set_dvd_visibility (bool visible) {
        dvd.no_show_all = !visible;
        dvd.visible = visible;
    }
}
