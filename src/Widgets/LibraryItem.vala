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
        public Audience.Objects.Video video { get; construct set; }

        Gtk.Image poster;
        Gtk.Label title;
        Gtk.Spinner spinner;
        Gtk.Grid spinner_container;

        public LibraryItem (Audience.Objects.Video video) {
            Object (video: video);
        }

        construct {
            margin_bottom = 12;

            video.poster_changed.connect (() => {
                if (video.poster != null) {
                    spinner.active = false;
                    spinner_container.hide ();
                    if (poster == null) {
                        poster = new Gtk.Image ();
                        poster.margin_top = poster.margin_left = poster.margin_right = 12;
                        poster.get_style_context ().add_class ("card");
                        grid.attach (poster, 0, 0, 1, 1);
                    }

                    poster.pixbuf = video.poster;
                    poster.show ();
                } else {
                    spinner.active = true;
                    spinner_container.show ();
                    if (poster != null) {
                        poster.hide ();
                    }
                }
            });

            video.title_changed.connect (() => {
                title.label = video.title;
                title.show ();
            });

            spinner_container = new Gtk.Grid ();
            spinner_container.height_request = Audience.Services.POSTER_HEIGHT;
            spinner_container.width_request = Audience.Services.POSTER_WIDTH;
            spinner_container.margin_top = spinner_container.margin_left = spinner_container.margin_right = 12;
            spinner_container.get_style_context ().add_class ("card");
            
            spinner = new Gtk.Spinner ();
            spinner.expand = true;
            spinner.active = true;
            spinner.valign = Gtk.Align.CENTER;
            spinner.halign = Gtk.Align.CENTER;
            spinner.height_request = 32;
            spinner.width_request = 32;

            spinner_container.add (spinner);

            grid = new Gtk.Grid ();
            grid.halign = Gtk.Align.CENTER;
            grid.valign = Gtk.Align.START;
            grid.row_spacing = 12;

            title = new Gtk.Label (video.title);
            title.justify = Gtk.Justification.CENTER;
            title.set_line_wrap (true);
            title.max_width_chars = 0;


            grid.attach (spinner_container, 0, 0, 1, 1);
            grid.attach (title, 0, 1, 1 ,1);

            this.add (grid);
        }
    }
}
