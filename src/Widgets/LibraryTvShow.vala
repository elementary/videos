// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2016 elementary LLC.
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
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 *
 */

namespace Audience {

    public class LibraryTvShow : Gtk.FlowBoxChild  {
        public signal void child_activated (Gtk.FlowBoxChild child);

        Gtk.Grid grid;
        Gtk.Label title;
        Gtk.FlowBox view_tv_show;

        public string tv_show_title { get; private set; }

        public LibraryTvShow (string tv_show_title) {
            this.tv_show_title = tv_show_title;

            view_tv_show = new Gtk.FlowBox ();
            view_tv_show.child_activated.connect ((item) => { child_activated (item); });
            view_tv_show.homogeneous = true;
            view_tv_show.set_sort_func ((child1, child2) => {
                var item1 = child1 as LibraryItem;
                var item2 = child2 as LibraryItem;
                if (item1 != null && item2 != null) {
                        return item1.video.file.collate (item2.video.file);
                    }
                return 0;
            });
            
            title = new Gtk.Label (tv_show_title);
            title.get_style_context ().add_class ("h2");
            title.halign = Gtk.Align.START;
            grid = new Gtk.Grid ();
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.column_homogeneous = true;
            
            grid.add (title);
            grid.add (view_tv_show);
            this.add (grid);
        }

        public void add_item (Audience.Objects.Video video) {
            view_tv_show.add (new Audience.LibraryItem (video));
        }
    }

}
