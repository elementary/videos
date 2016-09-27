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
    public class EpisodesPage : Gtk.Grid {

        Gtk.Image poster;
        Gtk.ScrolledWindow scrolled_window;
        Gtk.FlowBox view_episodes;

        public Audience.Services.LibraryManager manager;

        string query;

        construct {
            query = "";

            poster = new Gtk.Image ();
            poster.margin = 24;
            poster.margin_right = 0;
            poster.valign = Gtk.Align.START;
            poster.get_style_context ().add_class ("card");

            view_episodes = new Gtk.FlowBox ();
            view_episodes.margin = 24;
            view_episodes.homogeneous = true;
            view_episodes.valign = Gtk.Align.START;
            view_episodes.selection_mode = Gtk.SelectionMode.NONE;
            view_episodes.set_sort_func (episode_sort_func);
            view_episodes.set_filter_func (episodes_filter_func);
            view_episodes.child_activated.connect (play_video);
            view_episodes.max_children_per_line = 1;

            scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.expand = true;
            scrolled_window.add (view_episodes);

            expand = true;
            attach (poster, 0, 1, 1, 1);
            attach (scrolled_window, 1, 1, 1, 1);

            manager = Audience.Services.LibraryManager.get_instance ();
            manager.video_file_deleted.connect (remove_item_from_path);
            manager.video_file_detected.connect (add_item);
        }

        public void set_episodes_items (Gee.ArrayList<Audience.Objects.Video> episodes) {
            view_episodes.forall ((item)=> {
                item.dispose ();
            });

            foreach (Audience.Objects.Video episode in episodes) {
                view_episodes.add (new Audience.LibraryItem (episode, LibraryItemStyle.ROW));
            }

            poster.pixbuf = episodes.first ().poster;
        }

        private void play_video (Gtk.FlowBoxChild item) {
            var selected = (item as Audience.LibraryItem);
            var video = selected.episodes.first ();
            if (video.video_file.query_exists ()) {
                bool from_beginning = video.video_file.get_uri () != settings.current_video;
                App.get_instance ().mainwindow.play_file (video.video_file.get_uri (), from_beginning);
            }
        }

        public void filter (string text) {
             query = text.strip ();
             view_episodes.invalidate_filter ();
        }

        private bool episodes_filter_func (Gtk.FlowBoxChild child) {
            if (query.length == 0) {
                return true;
            }

            string[] filter_elements = query.split (" ");
            var video_title = (child as LibraryItem).get_title ();

            foreach (string filter_element in filter_elements) {
                if (!video_title.down ().contains (filter_element.down ())) {
                    return false;
                }
            }
            return true;
        }

        private int episode_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = child1 as LibraryItem;
            var item2 = child2 as LibraryItem;
            if (item1 != null && item2 != null) {
                return item1.episodes.first ().file.collate (item2.episodes.first ().file);
            }
            return 0;
        }

        private void add_item (Audience.Objects.Video episode) {
            if (view_episodes.get_children ().length () > 0 ) {
                var first = (view_episodes.get_children ().first ().data as Audience.LibraryItem);
                if (first != null && first.episodes.first ().video_file.get_parent ().get_path () == episode.video_file.get_parent ().get_path ()) {
                    view_episodes.add (new Audience.LibraryItem (episode, LibraryItemStyle.ROW));
                }
            }
        }

        private async void remove_item_from_path (string path ) {
            foreach (var child in view_episodes.get_children ()) {
                if ((child as LibraryItem).episodes.size == 0 || (child as LibraryItem).episodes.first ().video_file.get_path ().has_prefix (path)) {
                    child.dispose ();
                }
            }

            if (Audience.App.get_instance ().mainwindow.get_visible_child () == this && view_episodes.get_children ().length () == 0) {
                Audience.App.get_instance ().mainwindow.navigate_back ();
            }
        }
    }
}
