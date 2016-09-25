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

        Gtk.EventBox event_box;
        Gtk.Grid grid;
        public Audience.Objects.Video video { get; construct set; }

        public Gee.ArrayList<Audience.Objects.Video> episodes { get; construct set; }

        Gtk.Image poster;

        Gtk.Label title_label;

        Gtk.Spinner spinner;
        Gtk.Grid spinner_container;

        Gtk.Menu context_menu;
        Gtk.MenuItem new_cover;
        Gtk.MenuItem move_to_trash;

        public LibraryItem (Audience.Objects.Video video) {
            Object (video: video);
        }

        construct {
            episodes = new Gee.ArrayList<Audience.Objects.Video> ();
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
                if (get_episodes_counter () == 1) {
                    title_label.label = video.title;
                } else {
                    title_label.label = video.container;
                }
                title_label.show ();
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

            title_label = new Gtk.Label (video.title);
            title_label.justify = Gtk.Justification.CENTER;
            title_label.set_line_wrap (true);
            title_label.max_width_chars = 0;

            grid.attach (spinner_container, 0, 0, 1, 1);
            grid.attach (title_label, 0, 1, 1 ,1);

            context_menu = new Gtk.Menu ();
            new_cover = new Gtk.MenuItem.with_label (_("Set Artwork"));
            new_cover.activate.connect ( set_new_cover );
            move_to_trash = new Gtk.MenuItem.with_label (_("Move to Trash"));
            move_to_trash.activate.connect ( move_video_to_trash );

            context_menu.append (new_cover);
            context_menu.append (new Gtk.SeparatorMenuItem ());
            context_menu.append (move_to_trash);
            context_menu.show_all ();

            event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);
            event_box.add (grid);

            this.add (event_box);
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                context_menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }

            return false;
        }

        private void set_new_cover () {
            var file = new Gtk.FileChooserDialog (_("Open"), Audience.App.get_instance ().mainwindow, Gtk.FileChooserAction.OPEN,
                _("_Cancel"), Gtk.ResponseType.CANCEL, _("_Open"), Gtk.ResponseType.ACCEPT);

            var image_filter = new Gtk.FileFilter ();
            image_filter.set_filter_name (_("Image files"));
            image_filter.add_mime_type ("image/*");

            file.add_filter (image_filter);

            if (file.run () == Gtk.ResponseType.ACCEPT) {
                Gdk.Pixbuf? pixbuf = video.get_poster_from_file (file.get_file ().get_path ());
                if (pixbuf != null) {
                    try {
                        pixbuf.save (video.video_file.get_path() + ".jpg", "jpeg");
                        video.set_new_poster (pixbuf);
                    } catch (Error e) {
                        warning (e.message);
                    }
                    video.initialize_poster.begin ();
                }
            }

            file.destroy ();
        }

        public int get_episodes_counter () {
            return episodes.size;
        }

        private void move_video_to_trash () {
            video.trash ();
        }
        
        public void add_episode (Audience.Objects.Video episode) {
            episodes.add (episode);
            if (get_episodes_counter () == 1) {
                title_label.label = video.title;
            } else {
                title_label.label = video.container;
            }
        }
    }
}
