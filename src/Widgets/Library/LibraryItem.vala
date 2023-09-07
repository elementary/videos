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

public class Audience.LibraryItem : Gtk.Box {
    private Gtk.Label title_label;
    private Gtk.Picture poster;
    private Gtk.Stack spinner_stack;

    private Objects.MediaItem item;

    construct {
        title_label = new Gtk.Label ("");

        var move_to_trash = new Gtk.Button () {
            child = new Gtk.Label (_("Move to Trash")) { halign = START }
        };
        move_to_trash.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        move_to_trash.clicked.connect (() => item.trash ());

        var context_menu_box = new Gtk.Box (VERTICAL, 0);
        context_menu_box.append (move_to_trash);

        var context_menu = new Gtk.Popover () {
            child = context_menu_box,
            halign = START,
            has_arrow = false,
            position = BOTTOM
        };
        context_menu.add_css_class (Granite.STYLE_CLASS_MENU);
        context_menu.set_parent (this);

        title_label.ellipsize = END;
        title_label.wrap = true;
        title_label.max_width_chars = 0;
        title_label.justify = CENTER;

        var new_cover = new Gtk.Button () {
            child = new Gtk.Label (_("Set Artwork")) { halign = START }
        };
        new_cover.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        context_menu_box.append (new Gtk.Separator (HORIZONTAL));
        context_menu_box.append (new_cover);

        poster = new Gtk.Picture () {
            hexpand = true,
            vexpand = true
        };

        var spinner = new Gtk.Spinner () {
            spinning = true,
            hexpand = true,
            vexpand = true,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            height_request = 32,
            width_request = 32
        };

        spinner_stack = new Gtk.Stack () {
            height_request = Audience.Services.POSTER_HEIGHT,
            width_request = Audience.Services.POSTER_WIDTH,
            halign = CENTER,
            valign = CENTER
        };
        spinner_stack.add_css_class (Granite.STYLE_CLASS_CARD);
        spinner_stack.add_named (spinner, "spinner");
        spinner_stack.add_named (poster, "poster");

        append (spinner_stack);
        append (title_label);

        // new_cover.clicked.connect (set_new_cover);
        map.connect (poster_visibility);
        poster.notify ["paintable"].connect (poster_visibility);

        orientation = VERTICAL;
        spacing = 12;
        hexpand = true;
        vexpand = true;
        margin_top = 12;
        margin_bottom = 12;
        margin_start = 12;
        margin_end = 12;

        var gesture_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        add_controller (gesture_click);
        gesture_click.released.connect ((n_press, x, y) => {
            context_menu.pointing_to = Gdk.Rectangle () {
                x = (int) x,
                y = (int) y
            };

            context_menu.popup ();
        });
    }

    public void bind (Objects.MediaItem item) {
        this.item = item;

        title_label.label = item.title;
        item.notify["poster"].connect (() => {
            poster.set_pixbuf (item.poster);
        });

        poster.set_pixbuf (item.poster);
        spinner_stack.visible_child_name = "poster";
    }

    private void poster_visibility () {
        // if (poster.paintable != null) {
        //     spinner_stack.visible_child_name = "poster";
        // } else {
        //     spinner_stack.visible_child_name = "spinner";
        // }
    }

    // private void move_video_to_trash () {
    //     // debug (episodes.size.to_string ());
    //     // if (episodes.size == 1) {
    //     //     var video = episodes.first ();
    //     //     video.trashed ();
    //     //     try {
    //     //         video.video_file.trash ();
    //     //         manager.deleted_items (video.video_file.get_path ());
    //     //     } catch (Error e) {
    //     //         warning (e.message);
    //     //     }
    //TODO: Do this in Show and maybe don't use show?
    //     // } else {
    //     //     try {
    //     //         episodes.first ().video_file.get_parent ().trash ();
    //     //         manager.deleted_items (episodes.first ().video_file.get_parent ().get_path ());
    //     //     } catch (Error e) {
    //     //         warning (e.message);
    //     //     }
    //     // }
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

        // filechooser.response.connect ((response) => {
        //     if (response == Gtk.ResponseType.ACCEPT) {
        //         Gdk.Pixbuf? pixbuf = manager.get_poster_from_file (filechooser.get_file ().get_path ());
        //         if (pixbuf != null) {
        //             try {
        //                 if (item.get_type () == typeof (Objects.Video)) {
        //                     var video = (Objects.Video) item;
        //                     pixbuf.save (video.video_file.get_path () + ".jpg", "jpeg");
        //                     video.set_new_poster (pixbuf);
        //                     video.initialize_poster.begin ();
        //                 } else {
        //                     // manager.clear_cache.begin (poster_cache_file);
        //                     // pixbuf.save (episode_poster_path, "jpeg");
        //                     // create_episode_poster ();
        //                 }
        //             } catch (Error e) {
        //                 warning (e.message);
        //             }
        //         }
        //     }

        //     filechooser.destroy ();
        // });

        // filechooser.show ();
    }
}

// public enum Audience.LibraryItemStyle {
//     THUMBNAIL,
//     ROW
// }

// public class Audience.LibraryItem : Gtk.Box {
//     public Audience.Objects.Video video { get; construct; }
//     public LibraryItemStyle item_style { get; construct; }
//     public string title { get; private set; }

//     public Gdk.Pixbuf poster { get; set; }
//     public Gee.ArrayList<Audience.Objects.Video> episodes { get; private set; }


//     private Audience.Services.LibraryManager manager;
//     // private Gtk.Stack spinner_stack;
//     // private Gtk.Label title_label;
//     // private Gtk.Popover context_menu;
//     private string episode_poster_path;
//     private string poster_cache_file;

//     public LibraryItem (Audience.Objects.Video video, LibraryItemStyle item_style) {
//         Object (
//             item_style: item_style,
//             video: video
//         );
//     }

//     construct {
//         var video_file_parent = video.video_file.get_parent ();

//         episode_poster_path = Path.build_filename (
//             video_file_parent.get_path (),
//             video_file_parent.get_basename () + ".jpg"
//         );

//         var hash = GLib.Checksum.compute_for_string (
//             ChecksumType.MD5,
//             video_file_parent.get_uri (),
//             video_file_parent.get_uri ().length
//         );
//         poster_cache_file = Path.build_filename (App.get_instance ().get_cache_directory (), hash + ".jpg");

//         episodes = new Gee.ArrayList<Audience.Objects.Video> ();
//         manager = Audience.Services.LibraryManager.get_instance ();

//         // title_label = new Gtk.Label ("");

//         // var move_to_trash = new Gtk.Button () {
//         //     child = new Gtk.Label (_("Move to Trash")) { halign = START }
//         // };
//         // move_to_trash.add_css_class (Granite.STYLE_CLASS_MENUITEM);
//         // move_to_trash.clicked.connect (move_video_to_trash);

//         // var context_menu_box = new Gtk.Box (VERTICAL, 0);
//         // context_menu_box.append (move_to_trash);

//         // context_menu = new Gtk.Popover () {
//         //     child = context_menu_box,
//         //     halign = START,
//         //     has_arrow = false,
//         //     position = BOTTOM
//         // };
//         // context_menu.add_css_class (Granite.STYLE_CLASS_MENU);
//         // context_menu.set_parent (this);

//         // if (item_style == LibraryItemStyle.THUMBNAIL) {
//         //     title_label.ellipsize = END;
//         //     title_label.wrap = true;
//         //     title_label.max_width_chars = 0;
//         //     title_label.justify = CENTER;

//         //     var new_cover = new Gtk.Button () {
//         //         child = new Gtk.Label (_("Set Artwork")) { halign = START }
//         //     };
//         //     new_cover.add_css_class (Granite.STYLE_CLASS_MENUITEM);
//         //     context_menu_box.append (new Gtk.Separator (HORIZONTAL));
//         //     context_menu_box.append (new_cover);

//         //     poster = new Gtk.Picture () {
//         //         hexpand = true,
//         //         vexpand = true
//         //     };

//         //     var spinner = new Gtk.Spinner () {
//         //         spinning = true,
//         //         hexpand = true,
//         //         vexpand = true,
//         //         halign = Gtk.Align.CENTER,
//         //         valign = Gtk.Align.CENTER,
//         //         height_request = 32,
//         //         width_request = 32
//         //     };

//         //     spinner_stack = new Gtk.Stack () {
//         //         height_request = Audience.Services.POSTER_HEIGHT,
//         //         width_request = Audience.Services.POSTER_WIDTH,
//         //         halign = CENTER,
//         //         valign = CENTER
//         //     };
//         //     spinner_stack.add_css_class (Granite.STYLE_CLASS_CARD);
//         //     spinner_stack.add_named (spinner, "spinner");
//         //     spinner_stack.add_named (poster, "poster");

//         //     append (spinner_stack);
//         //     append (title_label);

//         //     new_cover.clicked.connect (set_new_cover);
//         //     map.connect (poster_visibility);
//         //     poster.notify ["paintable"].connect (poster_visibility);
//         // } else {
//         //     append (title_label);
//         //     title_label.halign = START;
//         // }

//         orientation = VERTICAL;
//         spacing = 12;
//         hexpand = true;
//         vexpand = true;
//         margin_top = 12;
//         margin_bottom = 12;
//         margin_start = 12;
//         margin_end = 12;
//         append (new Gtk.Label ("test"));

//         // var gesture_click = new Gtk.GestureClick () {
//         //     button = Gdk.BUTTON_SECONDARY
//         // };
//         // add_controller (gesture_click);
//         // gesture_click.released.connect ((n_press, x, y) => {
//         //     context_menu.pointing_to = Gdk.Rectangle () {
//         //         x = (int) x,
//         //         y = (int) y
//         //     };

//         //     context_menu.popup ();
//         // });

//         add_episode (video);

//         video.title_changed.connect (() => {
//              if (episodes.size == 1) {
//                  title = video.title;
//              } else {
//                  title = video.container;
//              }
//         });

//         video.poster_changed.connect (() => {
//             // if (item_style == LibraryItemStyle.THUMBNAIL && (episodes.size == 1 || poster.paintable == null)) {
//             //     poster.set_pixbuf (video.poster);
//             // }
//         });
//     }

//     // private void poster_visibility () {
//     //     if (poster.paintable != null) {
//     //         spinner_stack.visible_child_name = "poster";
//     //     } else {
//     //         spinner_stack.visible_child_name = "spinner";
//     //     }
//     // }

//     private void set_new_cover () {
//         var image_filter = new Gtk.FileFilter ();
//         image_filter.set_filter_name (_("Image files"));
//         image_filter.add_mime_type ("image/*");

//         var filechooser = new Gtk.FileChooserNative (
//             _("Open"),
//             Audience.App.get_instance ().mainwindow,
//             Gtk.FileChooserAction.OPEN,
//             _("_Open"),
//             _("_Cancel")
//         );
//         filechooser.add_filter (image_filter);

//         filechooser.response.connect ((response) => {
//             if (response == Gtk.ResponseType.ACCEPT) {
//                 Gdk.Pixbuf? pixbuf = manager.get_poster_from_file (filechooser.get_file ().get_path ());
//                 if (pixbuf != null) {
//                     try {
//                         if (episodes.size == 1) {
//                             pixbuf.save (episodes.first ().video_file.get_path () + ".jpg", "jpeg");
//                             episodes.first ().set_new_poster (pixbuf);
//                             episodes.first ().initialize_poster.begin ();
//                         } else {
//                             manager.clear_cache.begin (poster_cache_file);
//                             pixbuf.save (episode_poster_path, "jpeg");
//                             create_episode_poster ();
//                         }
//                     } catch (Error e) {
//                         warning (e.message);
//                     }
//                 }
//             }

//             filechooser.destroy ();
//         });

//         filechooser.show ();
//     }

//     private void move_video_to_trash () {
//         debug (episodes.size.to_string ());
//         if (episodes.size == 1) {
//             var video = episodes.first ();
//             video.trashed ();
//             try {
//                 video.video_file.trash ();
//                 manager.deleted_items (video.video_file.get_path ());
//             } catch (Error e) {
//                 warning (e.message);
//             }
//         } else {
//             try {
//                 episodes.first ().video_file.get_parent ().trash ();
//                 manager.deleted_items (episodes.first ().video_file.get_parent ().get_path ());
//             } catch (Error e) {
//                 warning (e.message);
//             }
//         }
//     }

//     public void add_episode (Audience.Objects.Video episode) {
//         episode.trashed.connect (() => {
//             episodes.remove (episode);
//         });
//         episodes.add (episode);
//         if (episodes.size == 1) {
//             title = episode.title;
//         } else if (episodes.size == 2) {
//             title = episode.container;
//             create_episode_poster ();
//         }
//     }

//     private void create_episode_poster () {
//         if (FileUtils.test (poster_cache_file, FileTest.EXISTS)) {
//             try {
//                 poster = new Gdk.Pixbuf.from_file (poster_cache_file);
//             } catch (Error e) {
//                 warning (e.message);
//             }
//         } else if (FileUtils.test (episode_poster_path, FileTest.EXISTS)) {
//             poster = manager.get_poster_from_file (episode_poster_path);
//             try {
//                 poster.save (poster_cache_file, "jpeg");
//             } catch (Error e) {
//                 warning (e.message);
//             }
//         }
//     }
// }
