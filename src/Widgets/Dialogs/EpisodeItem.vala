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
    public class EpisodeItem : Gtk.FlowBoxChild {

        Gtk.Grid grid;
        Gtk.Label title_label;
        Gtk.Image thumbnail;

        public Audience.Objects.Video video { get; construct set; }

        public EpisodeItem (Audience.Objects.Video video) {
            Object (video: video);
        }

        construct {
            video.thumbnail_changed.connect (() => {
                if (video.thumbnail != null) {
                    thumbnail.pixbuf = video.thumbnail;
                }
            });

            grid = new Gtk.Grid ();
            grid.row_spacing = 12;
            grid.halign = Gtk.Align.CENTER;
            grid.valign = Gtk.Align.START;
            title_label = new Gtk.Label (video.title);
            title_label.justify = Gtk.Justification.CENTER;
            title_label.set_line_wrap (true);
            title_label.max_width_chars = 0;

            thumbnail = new Gtk.Image.from_pixbuf (video.thumbnail);
            thumbnail.get_style_context ().add_class ("card");
            thumbnail.margin_top = thumbnail.margin_left = thumbnail.margin_right = 12;
            
            grid.attach (thumbnail, 0, 0, 1, 1);
            grid.attach (title_label, 0, 1, 1, 1);

            add (grid);
            show_all ();
        }

        private int video_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = child1 as LibraryItem;
            var item2 = child2 as LibraryItem;
            if (item1 != null && item2 != null) {
                return item1.video.file.collate (item2.video.file);
            }
            return 0;
        }
    }
}
