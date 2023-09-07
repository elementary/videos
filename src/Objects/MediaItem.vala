/*-
 * Copyright 2016-2023 elementary, Inc.
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
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 *
 */

// This can be a show or a video
public class Audience.Objects.MediaItem : Object {
    public signal void trashed ();

    public string? uri { get; construct; default = null; }
    public MediaItem? parent { get; construct; }
    public ListStore children { get; construct; }

    public string title { get; construct set; }
    public Gdk.Pixbuf? poster { get; construct set; default = null; }

    public string mime_type { get; construct; }

    private Audience.Services.LibraryManager manager;
    private string hash_file_poster;
    private string thumbnail_large_path;
    private string thumbnail_normal_path;

    public MediaItem.show (string title, string? uri = null) {
        Object (title: title, uri: uri);
    }

    public MediaItem.video (string uri, string title, MediaItem? parent, string mime_type) {
        Object (uri: uri, title: title, parent: parent, mime_type: mime_type);
    }

    construct {
        children = new ListStore (typeof (MediaItem));
        manager = Audience.Services.LibraryManager.get_instance ();
        manager.thumbler.finished.connect (() => update_poster ());

        manager.video_file_deleted.connect ((_uri) => {
            if (uri == _uri) {
                trashed ();
            }
        });

        // exclude YEAR from Title
        MatchInfo info;
        if (manager.regex_year.match (this.title, 0, out info)) {
            title = this.title.replace (info.fetch (0) + ")", "").strip ();
        }

        hash_file_poster = GLib.Checksum.compute_for_string (ChecksumType.MD5, uri ?? title);

        var poster_file = get_native_poster_file ();
        if (poster_file.query_exists ()) {
            poster = manager.get_poster_from_file (poster_file.get_path ());
        } else if (uri != null) {
            thumbnail_large_path = Path.build_filename (GLib.Environment.get_user_cache_dir (), "thumbnails", "large", hash_file_poster + ".png");
            thumbnail_normal_path = Path.build_filename (GLib.Environment.get_user_cache_dir (), "thumbnails", "normal", hash_file_poster + ".png");

            if (!FileUtils.test (thumbnail_large_path, FileTest.EXISTS) ||
                !FileUtils.test (thumbnail_normal_path, FileTest.EXISTS)) {

                // Call DBUS to create a new THUMBNAIL
                Gee.ArrayList<string> uris = new Gee.ArrayList<string> ();
                Gee.ArrayList<string> mimes = new Gee.ArrayList<string> ();

                uris.add (uri);
                mimes.add (mime_type);

                manager.thumbler.instand (uris, mimes, "large");
                manager.thumbler.instand (uris, mimes, "normal");
            } else {
                update_poster ();
            }
        }

        if (parent != null) {
            parent.add_item (this);
        }
    }

    public void add_item (MediaItem item) {
        item.trashed.connect (() => {
            uint position;
            children.find (item, out position);
            children.remove (position);
        });

        children.insert_sorted (item, Services.LibraryManager.library_item_sort_func);
    }

    private void update_poster (Gdk.Pixbuf? new_poster = null) {
        if (poster != null) {
            return;
        }

        if (new_poster != null) {
            poster = new_poster;
        } else if (FileUtils.test (thumbnail_large_path, FileTest.EXISTS)) {
            poster = manager.get_poster_from_file (thumbnail_large_path);
            if (parent != null) {
                parent.update_poster (poster);
            }
        }
    }

    public async void set_custom_poster (File new_poster_file) {
        Gdk.Pixbuf? new_poster = manager.get_poster_from_file (new_poster_file.get_path ());

        if (new_poster == null) {
            return;
        }

        poster = new_poster;
        try {
            yield new_poster_file.copy_async (get_native_poster_file (), OVERWRITE);
        } catch (Error e) {
            warning ("Failed to copy custom poster: %s", e.message);
        }
    }

    private File get_native_poster_file () {
        return File.new_build_filename (GLib.Environment.get_user_data_dir (), hash_file_poster + ".jpg");
    }

    public void trash () {
        for (int i = 0; i < children.get_n_items (); i++) {
            ((MediaItem) children.get_item (i)).trash ();
        }

        if (uri != null) {
            try {
                var file = File.new_for_uri (uri);
                file.trash ();
            } catch (Error e) {
                warning (e.message);
            }
        }

        trashed ();
    }
}
