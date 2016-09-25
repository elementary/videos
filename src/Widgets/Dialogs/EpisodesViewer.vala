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

namespace Audience.Dialogs {
    public class EpisodesViewer : Gtk.Dialog {

        public Gee.ArrayList<Audience.Objects.Video> episodes {get; construct set;}

        Gtk.Label container_label;
        Gtk.Image poster;
        Gtk.Grid grid;
        Gtk.ScrolledWindow scrolled_window;
        Gtk.FlowBox view_episodes;

        public EpisodesViewer (Gee.ArrayList<Audience.Objects.Video> episodes) {
            Object (episodes: episodes);
        }

        construct {
            set_default_size (700, 720);
            poster = new Gtk.Image.from_pixbuf (episodes.first ().poster);
            poster.margin = 24;
            poster.margin_top = 12;
            poster.get_style_context ().add_class ("card");

            view_episodes = new Gtk.FlowBox ();
            view_episodes.margin = 24;
            view_episodes.homogeneous = true;
            view_episodes.row_spacing = 12;
            view_episodes.column_spacing = 12;
            view_episodes.valign = Gtk.Align.START;
            view_episodes.selection_mode = Gtk.SelectionMode.NONE;
            view_episodes.set_sort_func (episode_sort_func);
            view_episodes.child_activated.connect (play_video);

            container_label = new Gtk.Label (null);
            container_label.hexpand = true;
            container_label.get_style_context ().add_class ("h1");
            container_label.wrap = true;
            container_label.valign = Gtk.Align.CENTER;
            container_label.set_max_width_chars (30);
            container_label.label = episodes.first ().container;

            scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.expand = true;
            scrolled_window.add (view_episodes);

            grid = new Gtk.Grid ();
            grid.expand = true;
            grid.attach (poster, 0, 0, 1, 1);
            grid.attach (container_label, 1, 0, 1, 1);
            grid.attach (scrolled_window, 0, 1, 2, 1);
            crate_episods_items ();

            Gtk.Box content = get_content_area () as Gtk.Box;
            content.pack_start (grid);
        }

        private void crate_episods_items () {
            foreach (Audience.Objects.Video episode in episodes) {
                view_episodes.add (new Audience.EpisodeItem (episode));
            }
        }

        private int episode_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = child1 as EpisodeItem;
            var item2 = child2 as EpisodeItem;
            if (item1 != null && item2 != null) {
                return item1.video.file.collate (item2.video.file);
            }
            return 0;
        }

        private void play_video (Gtk.FlowBoxChild item) {
            var selected = (item as Audience.EpisodeItem);

            if (selected.video.video_file.query_exists ()) {
                bool from_beginning = selected.video.video_file.get_uri () != settings.current_video;
                App.get_instance ().mainwindow.play_file (selected.video.video_file.get_uri (), from_beginning);
                close();
            }
        }
    }
}
