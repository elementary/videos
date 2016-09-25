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
    public class LibraryPage : Gtk.Grid {

        public signal void filter_result_changed (bool has_results);

        public Gtk.FlowBox view_movies;
        public Audience.Services.LibraryManager manager;
        public Gtk.ScrolledWindow scrolled_window;
        bool poster_initialized = false;
        int items_counter;
        string query;

        public bool has_items { get { return items_counter > 0; } }

        public static LibraryPage instance = null;
        public static LibraryPage get_instance () {
            if (instance == null) {
                instance = new LibraryPage ();
            }
            return instance;
        }

        construct {
            query = "";
            items_counter = 0;

            scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.expand = true;

            view_movies = new Gtk.FlowBox ();
            view_movies.margin = 24;
            view_movies.homogeneous = true;
            view_movies.row_spacing = 12;
            view_movies.column_spacing = 12;
            view_movies.valign = Gtk.Align.START;
            view_movies.selection_mode = Gtk.SelectionMode.NONE;
            view_movies.child_activated.connect (play_video);

            scrolled_window.add (view_movies);

            manager = Audience.Services.LibraryManager.get_instance ();
            manager.video_file_detected.connect (add_item);
            manager.video_file_deleted.connect (remove_item_from_path);
            manager.video_moved_to_trash.connect ((video) => {
                Audience.App.get_instance ().mainwindow.set_app_notification (_("Video '%s' Removed.").printf (video.title));
            });

            manager.begin_scan ();

            map.connect (() => {
                if (!poster_initialized) {
                    poster_initialized = true;
                    poster_initialisation.begin ();
                    show_all ();
                }
            });

            view_movies.set_sort_func (video_sort_func);
            view_movies.set_filter_func (video_filter_func);

            add (scrolled_window);
        }

        private void add_item (Audience.Objects.Video video) {
            Audience.LibraryItem new_item = get_container (video);
            if (new_item.video.video_file.get_path () == video.video_file.get_path ()) {
                view_movies.add (new_item);
                items_counter++;
            }
            new_item.add_episode (video);
        }

        private void play_video (Gtk.FlowBoxChild item) {
            var selected = (item as Audience.LibraryItem);

            if (selected.get_episodes_counter() == 1) {
                if (selected.video.video_file.query_exists ()) {
                    bool from_beginning = selected.video.video_file.get_uri () != settings.current_video;
                    App.get_instance ().mainwindow.play_file (selected.video.video_file.get_uri (), from_beginning);
                } else {
                    remove_item.begin (selected);
                }
            } else {
                Audience.Dialogs.EpisodesViewer episodes = new Audience.Dialogs.EpisodesViewer (selected.episodes);
                episodes.show_all ();
            }
        }

        public Audience.LibraryItem get_container (Audience.Objects.Video video) {
            foreach (var child in view_movies.get_children ()) {
                if ((child as LibraryItem).video.container == video.container) {
                    return child as LibraryItem;
                }
            }
            Audience.LibraryItem new_container = new Audience.LibraryItem (video);
            if (poster_initialized) {
                new_container.show_all ();
            }
            return new_container;
        }

        private async void remove_item (LibraryItem item) {
            manager.clear_cache (item.video);
            item.dispose ();
            items_counter--;
        }

        private async void remove_item_from_path (string path ) {
            foreach (var child in view_movies.get_children ()) {
                if ((child as LibraryItem).video.video_file.get_path ().has_prefix (path)) {
                    remove_item.begin (child as LibraryItem);
                }
            }

            if (!has_child ()) {
                Audience.App.get_instance ().mainwindow.navigate_back ();
            }
        }

        private async void poster_initialisation () {
            foreach (var child in view_movies.get_children ()) {
                var item = (child as LibraryItem);
                foreach (var video in item.episodes) {
                    video.initialize_poster.begin ();
                }
            }
        }

        private bool video_filter_func (Gtk.FlowBoxChild child) {
            if (query.length == 0) {
                return true;
            }

            string[] filter_elements = query.split (" ");
            var video_title = (child as LibraryItem).video.title;

            foreach (string filter_element in filter_elements) {
                if (!video_title.down ().contains (filter_element.down ())) {
                    return false;
                }
            }
            return true;
        }

        private int video_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = child1 as LibraryItem;
            var item2 = child2 as LibraryItem;
            if (item1 != null && item2 != null) {
                return item1.video.file.collate (item2.video.file);
            }
            return 0;
        }

        public void filter (string text) {
            query = text.strip ();
            view_movies.invalidate_filter ();
            filter_result_changed (has_child ());
        }

        public bool has_child () {
            if (view_movies.get_children ().length () > 0) {
               foreach (unowned Gtk.Widget child in view_movies.get_children ()) {
                   if (child.get_child_visible ()) {
                       return true;
                   }
                }
            }
            return false;
        }
    }
}
