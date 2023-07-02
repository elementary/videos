/*-
 * Copyright 2016-2021 elementary, Inc. (https://elementary.io)
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

public enum Audience.LibraryItemStyle {
    THUMBNAIL,
    ROW
}

public class Audience.LibraryItem : Gtk.FlowBoxChild {
    public Audience.Objects.Video video { get; construct; }
    public LibraryItemStyle item_style { get; construct; }

    public Gtk.Image poster { get; set; }
    public Gee.ArrayList<Audience.Objects.Video> episodes { get; private set; }


    private Audience.Services.LibraryManager manager;
    private Gtk.Box spinner_container;
    private Gtk.Label title_label;
    // private Gtk.Menu context_menu;
    private Gtk.Spinner spinner;
    private string episode_poster_path;
    private string poster_cache_file;

    public LibraryItem (Audience.Objects.Video video, LibraryItemStyle item_style) {
        Object (
            item_style: item_style,
            video: video
        );
    }

    construct {
        var video_file_parent = video.video_file.get_parent ();

        episode_poster_path = Path.build_filename (
            video_file_parent.get_path (),
            video_file_parent.get_basename () + ".jpg"
        );

        var hash = GLib.Checksum.compute_for_string (
            ChecksumType.MD5,
            video_file_parent.get_uri (),
            video_file_parent.get_uri ().length
        );
        poster_cache_file = Path.build_filename (App.get_instance ().get_cache_directory (), hash + ".jpg");

        episodes = new Gee.ArrayList<Audience.Objects.Video> ();
        manager = Audience.Services.LibraryManager.get_instance ();

        var grid = new Gtk.Grid () {
            valign = Gtk.Align.START,
            hexpand = true,
            vexpand = true
        };

        title_label = new Gtk.Label ("");

        // context_menu = new Gtk.Menu ();

        // var move_to_trash = new Gtk.MenuItem.with_label (_("Move to Trash"));
        // move_to_trash.activate.connect ( move_video_to_trash );

        if (item_style == LibraryItemStyle.THUMBNAIL) {
            margin_bottom = 12;

            title_label.wrap = true;
            title_label.max_width_chars = 0;
            title_label.justify = Gtk.Justification.CENTER;

            grid.halign = Gtk.Align.CENTER;
            grid.row_spacing = 12;

            // var new_cover = new Gtk.MenuItem.with_label (_("Set Artwork"));
            // context_menu.append (new_cover);
            // context_menu.append (new Gtk.SeparatorMenuItem ());

            poster = new Gtk.Image () {
                margin_top = 12,
                margin_start = 12,
                margin_end = 12,
                margin_bottom = 0
            };
            // poster.pixbuf = null;
            poster.get_style_context ().add_class (Granite.STYLE_CLASS_CARD);

            spinner = new Gtk.Spinner () {
                spinning = true,
                hexpand = true,
                vexpand = true,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                height_request = 32,
                width_request = 32
            };

            spinner_container = new Gtk.Box (VERTICAL, 0) {
                height_request = Audience.Services.POSTER_HEIGHT,
                width_request = Audience.Services.POSTER_WIDTH,
                margin_top = 12,
                margin_bottom = 0,
                margin_start = 12,
                margin_end = 12,
            };
            spinner_container.add_css_class (Granite.STYLE_CLASS_CARD);
            spinner_container.append (spinner);

            grid.attach (spinner_container, 0, 0);
            grid.attach (poster, 0, 0);
            grid.attach (title_label, 0, 1);

            // new_cover.activate.connect ( set_new_cover );
            map.connect (poster_visibility);
            // poster.notify ["pixbuf"].connect (poster_visibility);
        } else {
            grid.attach (title_label, 0, 0);
            grid.margin_top = 12;
            grid.margin_bottom = 12;
            grid.margin_start = 12;
            grid.margin_end = 12;
        }

        // context_menu.append (move_to_trash);
        // context_menu.show_all ();

        // var event_box = new Gtk.EventBox ();
        // event_box.button_press_event.connect (show_context_menu);
        // event_box.add (grid);

        child = grid;

        add_episode (video);

        video.title_changed.connect (() => {
             if (episodes.size == 1) {
                 title_label.label = video.title;
             } else {
                 title_label.label = video.container;
             }
        });

        video.poster_changed.connect (() => {
            if (item_style == LibraryItemStyle.THUMBNAIL && (episodes.size == 1 || true)) {
                poster.set_from_pixbuf (video.poster);
            }
        });
    }

    private void poster_visibility () {
        // if (poster.pixbuf != null) {
        //     spinner.active = false;
        //     spinner_container.visible = false;
        // } else {
        //     spinner.active = true;
        //     spinner_container.show ();
        //     poster.hide ();
        // }
    }

    // private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
    //     if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
    //         context_menu.popup_at_pointer (evt);
    //         return true;
    //     }
    //     return false;
    // }

    private void set_new_cover () {
        // var image_filter = new Gtk.FileFilter ();
        // image_filter.set_filter_name (_("Image files"));
        // image_filter.add_mime_type ("image/*");

        // var filechooser = new Gtk.FileChooserNative (
        //     _("Open"),
        //     Audience.App.get_instance ().mainwindow,
        //     Gtk.FileChooserAction.OPEN,
        //     _("_Open"),
        //     _("_Cancel")
        // );
        // filechooser.add_filter (image_filter);

        // if (filechooser.run () == Gtk.ResponseType.ACCEPT) {
        //     Gdk.Pixbuf? pixbuf = manager.get_poster_from_file (filechooser.get_filename ());
        //     if (pixbuf != null) {
        //         try {
        //             if (episodes.size == 1) {
        //                 pixbuf.save (episodes.first ().video_file.get_path () + ".jpg", "jpeg");
        //                 episodes.first ().set_new_poster (pixbuf);
        //                 episodes.first ().initialize_poster.begin ();
        //             } else {
        //                 manager.clear_cache.begin (poster_cache_file);
        //                 pixbuf.save (episode_poster_path, "jpeg");
        //                 create_episode_poster ();
        //             }
        //         } catch (Error e) {
        //             warning (e.message);
        //         }
        //     }
        // }
        // filechooser.destroy ();
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

    private void create_episode_poster () {
        if (FileUtils.test (poster_cache_file, FileTest.EXISTS)) {
            try {
                poster.set_from_pixbuf (new Gdk.Pixbuf.from_file (poster_cache_file));
            } catch (Error e) {
                warning (e.message);
            }
        } else if (FileUtils.test (episode_poster_path, FileTest.EXISTS)) {
            var pixbuf = manager.get_poster_from_file (episode_poster_path);
            poster.set_from_pixbuf (pixbuf);
            try {
                pixbuf.save (poster_cache_file, "jpeg");
            } catch (Error e) {
                warning (e.message);
            }
        }
    }
}
