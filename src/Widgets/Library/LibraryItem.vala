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

    public enum LibraryItemStyle { THUMBNAIL, ROW }

    public class LibraryItem : Gtk.FlowBoxChild  {
        Audience.Services.LibraryManager manager;

        public Gee.ArrayList<Audience.Objects.Video> episodes { get; private set; }
        public LibraryItemStyle item_style { get; construct set; }

        Gtk.EventBox event_box;
        Gtk.Grid grid;
        public Gtk.Image poster { get; set; }
        Gtk.Label title_label;
        Gtk.Spinner spinner;
        Gtk.Grid spinner_container;
        Gtk.Menu context_menu;
        Gtk.MenuItem new_cover;
        Gtk.MenuItem move_to_trash;

        public string episode_poster_path { get; construct set; }
        public string poster_cache_file { get; construct set; }
        public string hash { get; construct set; }

        public LibraryItem (Audience.Objects.Video video, LibraryItemStyle item_style) {
            Object (item_style: item_style);
            episodes = new Gee.ArrayList<Audience.Objects.Video> ();
            add_episode (video);
            video.title_changed.connect (video_title_changed);
            video.poster_changed.connect (video_poster_changed);

            hash = GLib.Checksum.compute_for_string (ChecksumType.MD5, video.video_file.get_parent ().get_uri (), video.video_file.get_parent ().get_uri ().length);
            episode_poster_path = Path.build_filename (video.video_file.get_parent ().get_path (), video.video_file.get_parent ().get_basename () + ".jpg");
            poster_cache_file = Path.build_filename (App.get_instance ().get_cache_directory (), hash + ".jpg");
        }

        construct {
            manager = Audience.Services.LibraryManager.get_instance ();

            grid = new Gtk.Grid ();
            grid.valign = Gtk.Align.START;
            grid.expand = true;

            title_label = new Gtk.Label ("");

            context_menu = new Gtk.Menu ();

            move_to_trash = new Gtk.MenuItem.with_label (_("Move to Trash"));
            move_to_trash.activate.connect ( move_video_to_trash );

            if (item_style == LibraryItemStyle.THUMBNAIL) {
                margin_bottom = 12;

                title_label.set_line_wrap (true);
                title_label.max_width_chars = 0;
                title_label.justify = Gtk.Justification.CENTER;

                grid.halign = Gtk.Align.CENTER;
                grid.row_spacing = 12;

                new_cover = new Gtk.MenuItem.with_label (_("Set Artwork"));
                new_cover.activate.connect ( set_new_cover );
                context_menu.append (new_cover);
                context_menu.append (new Gtk.SeparatorMenuItem ());

                poster = new Gtk.Image ();
                poster.margin_top = poster.margin_left = poster.margin_right = 12;
                poster.get_style_context ().add_class ("card");
                poster.pixbuf = null;
                poster.notify ["pixbuf"].connect (poster_visibility);

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

                grid.attach (spinner_container, 0, 0, 1, 1);
                grid.attach (poster, 0, 0, 1, 1);
                grid.attach (title_label, 0, 1, 1 ,1);

                map.connect (poster_visibility);
            } else {
                grid.halign = Gtk.Align.FILL;
                grid.attach (title_label, 0, 0, 1 ,1);
                grid.margin = 12;
            }

            context_menu.append (move_to_trash);
            context_menu.show_all ();

            event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);
            event_box.add (grid);

            add (event_box);
            show_all ();
        }

        private void poster_visibility () {
            if (poster.pixbuf != null) {
                spinner.active = false;
                spinner_container.hide ();
                poster.show_all ();
            } else {
                spinner.active = true;
                spinner_container.show ();
                poster.hide ();
            }
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                context_menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }

        private void video_poster_changed (Audience.Objects.Video video) {
            if (item_style == LibraryItemStyle.THUMBNAIL && (episodes.size == 1 || poster.pixbuf == null)) {
                poster.pixbuf = video.poster;
            }
        }

        private void video_title_changed (Audience.Objects.Video video) {
             if (episodes.size == 1) {
                 title_label.label = video.title;
             } else {
                 title_label.label = video.container;
             }
             title_label.show ();
        }

        private void set_new_cover () {
            var file = new Gtk.FileChooserDialog (_("Open"), Audience.App.get_instance ().mainwindow, Gtk.FileChooserAction.OPEN, _("_Cancel"), Gtk.ResponseType.CANCEL, _("_Open"), Gtk.ResponseType.ACCEPT);

            var image_filter = new Gtk.FileFilter ();
            image_filter.set_filter_name (_("Image files"));
            image_filter.add_mime_type ("image/*");

            file.add_filter (image_filter);

            if (file.run () == Gtk.ResponseType.ACCEPT) {
                Gdk.Pixbuf? pixbuf = manager.get_poster_from_file (file.get_file ().get_path ());
                if (pixbuf != null) {
                    try {
                        if (episodes.size == 1) {
                            pixbuf.save (episodes.first ().video_file.get_path() + ".jpg", "jpeg");
                            episodes.first ().set_new_poster (pixbuf);
                            episodes.first ().initialize_poster.begin ();
                        } else {
                            manager.clear_cache.begin (poster_cache_file);
                            pixbuf.save (episode_poster_path, "jpeg");
                            create_episode_poster ();
                        }
                    } catch (Error e) {
                        warning (e.message);
                    }
                }
            }
            file.destroy ();
        }

        private void move_video_to_trash () {
            debug (episodes.size.to_string ());
            if (episodes.size == 1) {
                var video = episodes.first ();
                video.trashed ();
                try {
                    video.video_file.trash ();
                    manager.deleted_items (video.video_file.get_path ());
                } catch (Error e) {
                    warning (e.message);
                }
            } else {
                try {
                    episodes.first ().video_file.get_parent ().trash ();
                    manager.deleted_items (episodes.first ().video_file.get_parent ().get_path ());
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }

        public void add_episode (Audience.Objects.Video episode) {
            episode.trashed.connect (() => {
                episodes.remove (episode);
            });
            episodes.add (episode);
            if (episodes.size == 1) {
                title_label.label = episode.title;
            } else if (episodes.size == 2) {
                title_label.label = episode.container;
                create_episode_poster ();
            }
        }

        public string get_title () {
            return title_label.label;
        }

        public void create_episode_poster () {
            if (FileUtils.test (poster_cache_file, FileTest.EXISTS)) {
                try {
                    poster.pixbuf = new Gdk.Pixbuf.from_file (poster_cache_file);
                } catch (Error e) {
                    warning (e.message);
                }
            } else if (FileUtils.test (episode_poster_path, FileTest.EXISTS)) {
                poster.pixbuf = manager.get_poster_from_file (episode_poster_path);
                try {
                    poster.pixbuf.save (poster_cache_file, "jpeg");
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }
    }
}
