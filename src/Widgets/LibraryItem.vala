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

    public class LibraryItem : Gtk.FlowBoxChild  {

        Gtk.Grid grid;
        public Audience.Objects.Video Video { get; private set; }

        Gtk.Image poster;
        Gtk.Label title;

        public LibraryItem (Audience.Objects.Video video) {
            this.Video = video;
            grid = new Gtk.Grid ();
            grid.halign = Gtk.Align.CENTER;
            grid.valign = Gtk.Align.START;
            
            poster = new Gtk.Image.from_pixbuf (video.Poster);
            poster.margin_top = poster.margin_left = poster.margin_right = 12;
            
            title = new Gtk.Label (video.Title);
            title.get_style_context ().add_class ("h4");

            grid.attach (poster, 0, 0, 1, 1);
            grid.attach (title, 0, 1, 1 ,1);
            
            this.add (grid);
        }
    }
}
