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

    public PlaylistPopover () {
        opacity = GLOBAL_OPACITY;
        var grid = new Gtk.Grid ();
        grid.row_spacing = 6;
        grid.column_spacing = 12;
        grid.margin = 6;

        var fil = new Gtk.Button.from_icon_name ("document-open-symbolic", Gtk.IconSize.BUTTON);
        fil.set_tooltip_text (_("Open file"));
        dvd = new Gtk.Button.from_icon_name ("media-optical-symbolic", Gtk.IconSize.BUTTON);
        dvd.set_tooltip_text (_("Play from Disc"));

        var clear_playlist_button = new Gtk.Button.from_icon_name ("edit-clear", Gtk.IconSize.BUTTON);
        clear_playlist_button.set_tooltip_text (_("Clear Playlist"));

        rep = new Gtk.ToggleButton ();
        rep.set_image (new Gtk.Image.from_icon_name ("media-playlist-no-repeat-symbolic", Gtk.IconSize.BUTTON));
        rep.set_tooltip_text (_("Enable Repeat"));

        playlist_scrolled = new Gtk.ScrolledWindow (null, null);
        playlist_scrolled.set_min_content_height (100);
        playlist_scrolled.set_min_content_width (260);

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
    }

    private void set_dvd_visibility (bool visible) {
        dvd.no_show_all = !visible;
        dvd.visible = visible;
    }

    //Override because the Popover doesn't auto-rejust his size.
    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        base.get_preferred_height (out minimum_height, out natural_height);
        int p_minimum_height;
        int p_natural_height;
        var app = ((Audience.App) GLib.Application.get_default ());
        playlist.get_preferred_height (out p_minimum_height, out p_natural_height);
        int temp_minimum_height = minimum_height + p_minimum_height;
        int r_minimum_height;
        int r_natural_height;
        relative_to.get_preferred_height (out r_minimum_height, out r_natural_height);
        if (temp_minimum_height < app.mainwindow.get_window ().get_height () - r_minimum_height * 2) {
            minimum_height = temp_minimum_height;
        } else {
            minimum_height = app.mainwindow.get_window ().get_height () - r_minimum_height * 2;
        }

        int temp_natural_height = natural_height + p_natural_height;
        if (temp_natural_height < app.mainwindow.get_window ().get_height () - r_natural_height * 2) {
            natural_height = temp_natural_height;
        } else {
            natural_height = minimum_height;
        }
    }
}
