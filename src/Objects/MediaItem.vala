/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 */

/* This can be a show or a video */
public class Audience.Objects.MediaItem : Object {
    public signal void trashed ();

    public string? uri { get; construct; default = null; }
    public MediaItem? parent { get; construct; }
    public ListStore children { get; construct; }

    public int show_episode_number { get; private set; }
    public int show_season_number { get; private set; }
    public string? show_name { get; private set; }
    public string title { get; construct set; }
    public Gdk.Pixbuf? poster { get; construct set; default = null; }

    private static Gst.PbUtils.Discoverer discoverer;
    private Audience.Services.LibraryManager manager;
    private File custom_poster_file;
    private string thumbnail_large_path;

    public MediaItem.show (string title, string? uri = null) {
        Object (title: title, uri: uri);
    }

    public MediaItem.video (string uri, string title, MediaItem? parent) {
        Object (uri: uri, title: title, parent: parent);
    }

    static construct {
        try {
            discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));
            discoverer.finished.connect (discoverer.stop);
        } catch (Error e) {
            critical ("Could not create Gst discoverer object: %s", e.message);
        }
    }

    construct {
        children = new ListStore (typeof (MediaItem));
        manager = Audience.Services.LibraryManager.get_instance ();
        manager.thumbler.finished.connect (() => set_best_poster ());

        manager.video_file_deleted.connect ((_uri) => {
            if (uri != null && uri == _uri) {
                trashed ();
            }
        });

        // exclude YEAR from Title
        MatchInfo info;
        if (manager.regex_year.match (title, 0, out info)) {
            title = title.replace (info.fetch (0) + ")", "").strip ();
        }

        var hash_file_poster = GLib.Checksum.compute_for_string (ChecksumType.MD5, uri ?? title);

        custom_poster_file = File.new_build_filename (GLib.Environment.get_user_data_dir (), hash_file_poster + ".jpg");
        thumbnail_large_path = Path.build_filename (GLib.Environment.get_user_cache_dir (), "thumbnails", "large", hash_file_poster + ".png");

        if (custom_poster_file.query_exists ()) {
            poster = manager.get_poster_from_file (custom_poster_file.get_path ());
        } else if (uri != null && !set_best_poster ()) {
            // Call DBUS to create a new THUMBNAIL
            Gee.ArrayList<string> uris = new Gee.ArrayList<string> ();
            Gee.ArrayList<string> mimes = new Gee.ArrayList<string> ();

            uris.add (uri);

            try {
                var file_info = File.new_for_uri (uri).query_info (FileAttribute.STANDARD_CONTENT_TYPE, 0);
                mimes.add (file_info.get_content_type ());
            } catch (Error e) {
                warning ("Failed to query file info: %s", e.message);
            }

            manager.thumbler.instand (uris, mimes, "large");
        }

        discoverer.start ();
        discoverer.discovered.connect (update_metadata);
        discoverer.discover_uri_async (uri);
    }

    private void update_metadata (Gst.PbUtils.DiscovererInfo info, Error? err) {
        if (info.get_uri () == uri) {
            switch (info.get_result ()) {
                case URI_INVALID:
                    critical ("Couldn't read metadata for '%s': invalid URI.", info.get_uri ());
                    return;
                case ERROR:
                    critical ("Couldn't read metadata for '%s': %s", info.get_uri (), err.message);
                    return;
                case TIMEOUT:
                    critical ("Couldn't read metadata for '%s': Discovery timed out.", info.get_uri ());
                    return;
                case BUSY:
                    critical ("Couldn't read metadata for '%s': Already discovering a file.", info.get_uri ());
                    return;
                case MISSING_PLUGINS:
                    critical ("Couldn't read metadata for '%s': Missing plugins.", info.get_uri ());
                    return;
                default:
                    break;
            }

            unowned Gst.TagList? tag_list = info.get_tags ();
            if (tag_list == null) {
                return;
            }

            string _show_name;
            tag_list.get_string (Gst.Tags.SHOW_NAME, out _show_name);
            show_name = _show_name;

            int _show_episode_number;
            tag_list.get_int (Gst.Tags.SHOW_EPISODE_NUMBER, out _show_episode_number);
            show_episode_number = _show_episode_number;

            int _show_season_number;
            tag_list.get_int (Gst.Tags.SHOW_SEASON_NUMBER, out _show_season_number);
            show_season_number = _show_season_number;

            string _title;
            tag_list.get_string (Gst.Tags.TITLE, out _title);
            if (_title != null) {
                title = _title;
            }
        }
    }

    private bool set_best_poster () {
        File[] possible_files = {};

        var file = File.new_for_uri (uri);
        var dir = file.get_parent ();

        possible_files += dir.get_child (file.get_basename () + ".jpg");
        possible_files += dir.get_child (title + ".jpg");

        foreach (var poster_name in Audience.settings.get_strv ("poster-names")) {
            possible_files += dir.get_child (poster_name);
        }

        possible_files += File.new_for_path (thumbnail_large_path);

        foreach (var possible_file in possible_files) {
            if (possible_file.query_exists ()) {
                poster = manager.get_poster_from_file (possible_file.get_path ());
                if (parent != null) {
                    parent.update_poster (poster);
                }
                return true;
            }
        }

        return false;
    }

    public void add_item (MediaItem item) {
        item.trashed.connect (() => {
            uint position;
            if (children.find (item, out position)) {
                children.remove (position);
            }
        });

        children.insert_sorted (item, Services.LibraryManager.library_item_sort_func);
    }

    public void update_poster (Gdk.Pixbuf new_poster) {
        if (poster != null) {
            return;
        }

        poster = new_poster;
    }

    public async void set_custom_poster (File new_poster_file) {
        Gdk.Pixbuf? new_poster = manager.get_poster_from_file (new_poster_file.get_path ());

        if (new_poster == null) {
            return;
        }

        poster = new_poster;
        try {
            yield new_poster_file.copy_async (custom_poster_file, OVERWRITE);
        } catch (Error e) {
            warning ("Failed to copy custom poster: %s", e.message);
        }
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
