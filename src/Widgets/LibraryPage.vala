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

    public class LibraryPage : Gtk.IconView {

        LibraryItem cell_renderer;
        Gtk.ListStore store;

        Gtk.TreeIter iter;

        LibraryManager manager;

        public LibraryPage () {
            store = new Gtk.ListStore (1, typeof (Audience.Objects.Video));

            cell_renderer = new LibraryItem ();
            pack_start (cell_renderer, false);
            add_attribute (cell_renderer, "Video", 0);
            item_padding = 0;
            margin = 24;
            this.set_model (store);

            manager = new LibraryManager ();
            manager.video_file_detected.connect (add_item);
            manager.begin_scan ();

            this.selection_changed.connect (() => {
                List<Gtk.TreePath> paths = get_selected_items ();
                Value val;

                Audience.Objects.Video video = null;

                foreach (Gtk.TreePath path in paths) {
                    bool tmp = store.get_iter (out iter, path);
                    assert (tmp == true);
                    store.get_value (iter, 0, out val);
                    video = val as Audience.Objects.Video;
                }

                if (video != null) {
                    App.get_instance ().mainwindow.play_file (video.VideoFile.get_uri ());
                }
            });
        }

        private void add_item (Audience.Objects.Video video){
            store.append(out iter);
            store.set(iter, 0, video);
        }

    }
}
