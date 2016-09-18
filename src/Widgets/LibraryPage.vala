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

    public class LibraryPage : Gtk.ScrolledWindow {

        Gtk.Grid grid;

        Gtk.FlowBox view_movies;
        Gtk.FlowBox view_tv_shows;

        Gtk.Label label_movies;
        Gtk.Label label_tv_shows;

        Audience.Services.LibraryManager manager;

        public LibraryPage () {

            view_movies = new Gtk.FlowBox ();
            view_movies.margin = 24;
            view_movies.homogeneous = true;
            view_movies.child_activated.connect ((item) => {
                App.get_instance ().mainwindow.play_file ((item as Audience.LibraryItem).video.video_file.get_uri ());
            });

            view_movies.set_sort_func ((child1, child2) => {
                var item1 = child1 as LibraryItem;
                var item2 = child2 as LibraryItem;
                if (item1 != null && item2 != null) {
                        return item1.video.file.collate (item2.video.file);
                    }
                return 0;
            });

            view_tv_shows = new Gtk.FlowBox ();
            view_tv_shows.margin = 24;
            view_tv_shows.max_children_per_line = 1;
            view_tv_shows.homogeneous = true;
            /*view_tv_shows.child_activated.connect ((item) => {
                App.get_instance ().mainwindow.play_file ((item as Audience.LibraryItem).video.video_file.get_uri ());
            });*/

            view_tv_shows.set_sort_func ((child1, child2) => {
                var item1 = child1 as LibraryItem;
                var item2 = child2 as LibraryItem;
                if (item1 != null && item2 != null) {
                        return item1.video.file.collate (item2.video.file);
                    }
                return 0;
            });

            manager = Audience.Services.LibraryManager.get_instance ();
            manager.video_file_detected.connect (add_item);
            manager.begin_scan ();

            label_movies = new Gtk.Label (_("Movies"));
            label_movies.get_style_context ().add_class ("h1");
            label_movies.margin_top = 24;

            label_tv_shows = new Gtk.Label (_("TV Shows"));
            label_tv_shows.get_style_context ().add_class ("h1");
            label_tv_shows.margin_top = 24;

            grid = new Gtk.Grid ();
            grid.orientation = Gtk.Orientation.VERTICAL;
            grid.column_homogeneous = true;
            grid.add (label_movies);
            grid.add (view_movies);
            grid.add (label_tv_shows);
            grid.add (view_tv_shows);


            this.add (grid);
        }

        private void add_item (Audience.Objects.Video video) {
            if (video.tv_show_title != "") {
                LibraryTvShow tv_show = get_tv_show_container (video.tv_show_title);
                tv_show.add_item (video);
            } else {
                view_movies.add (new Audience.LibraryItem (video));
            }
        }

        private LibraryTvShow get_tv_show_container (string tv_show_title) {
            foreach (var item in view_tv_shows.get_children ()) {
                if ((item as LibraryTvShow).tv_show_title == tv_show_title) {
                   return item as LibraryTvShow;
                }
            }
            
            LibraryTvShow item = new LibraryTvShow (tv_show_title);
            item.child_activated.connect ((item) => {
                App.get_instance ().mainwindow.play_file ((item as Audience.LibraryItem).video.video_file.get_uri ());
            });
            view_tv_shows.add (item);
            return item;
        }
    }
}
