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

        Gtk.FlowBox view;

        LibraryManager manager;

        public LibraryPage () {

            view = new Gtk.FlowBox ();
            view.margin = 24;
            view.valign = Gtk.Align.START;
            view.child_activated.connect ((item) => {
                Audience.LibraryItem video = item as Audience.LibraryItem;
                App.get_instance ().mainwindow.play_file (video.Video.VideoFile.get_uri ());
            });

            manager = new LibraryManager ();
            manager.video_file_detected.connect (add_item);
            manager.begin_scan ();

            this.add (view);
        }

        private void add_item (Audience.Objects.Video video){
            view.add (new Audience.LibraryItem (video));
        }

    }
}
