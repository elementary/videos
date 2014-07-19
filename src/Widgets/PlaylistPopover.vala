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
    Gtk.ScrolledWindow playlist_scrolled;
    public PlaylistPopover () {
        opacity = GLOBAL_OPACITY;
        var grid = new Gtk.Grid ();
        grid.row_spacing = 6;
        grid.column_spacing = 12;
        grid.margin = 6;

        var fil   = new Gtk.Button.with_label (_("Add from Harddrive…"));
        fil.image = new Gtk.Image.from_icon_name ("document-open", Gtk.IconSize.DIALOG);
        var dvd   = new Gtk.Button.with_label (_("Play a DVD…"));
        dvd.image = new Gtk.Image.from_icon_name ("media-cdrom", Gtk.IconSize.DIALOG);
        dvd.no_show_all = true;
        var net   = new Gtk.Button.with_label (_("Network File…"));
        net.image = new Gtk.Image.from_icon_name ("internet-web-browser", Gtk.IconSize.DIALOG);

        playlist_scrolled = new Gtk.ScrolledWindow (null, null);
        var app = ((Audience.App) GLib.Application.get_default ());
        playlist_scrolled.add (app.playlist);

        fil.clicked.connect ( () => {
            hide ();
            app.run_open_file ();
        });

        dvd.clicked.connect ( () => {
            hide ();
            app.run_open_dvd ();
        });

        net.clicked.connect ( () => {
            /*var entry = new Gtk.Entry ();
            entry.secondary_icon_stock = Gtk.Stock.OPEN;
            entry.icon_release.connect ( (pos, e) => {
                open_file (entry.text);
                video_player.playing = true;
                pop.destroy ();
            });
            box.remove (net);
            box.reorder_child (entry, 2);
            entry.show ();*/
        });

        grid.attach (playlist_scrolled, 0, 0, 2, 1);
        grid.attach (fil, 0, 1, 1, 1);
        grid.attach (dvd, 1, 1, 1, 1);

        //look for dvd
        var disk_manager = DiskManager.get_default ();
        foreach (var volume in disk_manager.get_volumes ()) {
            dvd.no_show_all = false;
            dvd.show ();
        }

        disk_manager.volume_found.connect ((vol) => {
            dvd.no_show_all = false;
            dvd.show ();
        });

        disk_manager.volume_removed.connect ((vol) => {
            if (disk_manager.get_volumes ().length () <= 0) {
                dvd.no_show_all = true;
                dvd.hide ();
            }
        });

        //grid.add (net);
        add (grid);
    }

    //Override because the Popover doesn't auto-rejust his size.
    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        base.get_preferred_height (out minimum_height, out natural_height);
        int p_minimum_height;
        int p_natural_height;
        var app = ((Audience.App) GLib.Application.get_default ());
        app.playlist.get_preferred_height (out p_minimum_height, out p_natural_height);
        int temp_minimum_height = minimum_height + p_minimum_height;
        int r_minimum_height;
        int r_natural_height;
        relative_to.get_preferred_height (out r_minimum_height, out r_natural_height);
        if (temp_minimum_height < app.mainwindow.get_window ().get_height () - r_minimum_height*2) {
            minimum_height = temp_minimum_height;
        } else {
            minimum_height = app.mainwindow.get_window ().get_height () - r_minimum_height*2;
        }

        int temp_natural_height = natural_height + p_natural_height;
        if (temp_natural_height < app.mainwindow.get_window ().get_height () - r_natural_height*2) {
            natural_height = temp_natural_height;
        } else {
            natural_height = minimum_height;
        }
    }
}