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

namespace Audience.Objects {
    public class Video : Object {
        Audience.Services.LibraryManager manager;

        public signal void poster_changed (Video sender);
        public signal void title_changed (Video sender);
        public signal void thumbnail_changed ();
        public signal void trashed ();

        public File video_file { get; private set; }
        public string directory { get; construct set; }
        public string file { get; construct set; }

        public string title { get; private set; }
        public int year { get; private set; default = -1;}

        public Gdk.Pixbuf? poster { get; private set; default = null; }
        public Gdk.Pixbuf? thumbnail { get; private set; default = null; }
        public bool poster_initialized { get; private set; default = false; }

        public string mime_type { get; construct set; }
        public string poster_cache_file { get; private set; }

        public string hash_file_poster { get; construct set; }
        public string hash_episode_poster { get; construct set; }
        public string thumbnail_large_path { get; construct set;}
        public string thumbnail_normal_path { get; construct set;}

        public string container { get; construct set; default = ""; }

        public Video (string directory, string file, string mime_type) {
            Object (directory: directory, file: file, mime_type: mime_type);
        }

        construct {
            manager = Audience.Services.LibraryManager.get_instance ();
            manager.thumbler.finished.connect (dbus_finished);

            title = Audience.get_title (file);

            extract_metadata ();
            video_file = File.new_for_path (this.get_path ());

            if (directory != Environment.get_user_special_dir (UserDirectory.VIDEOS)) {
                container = Path.get_basename (directory);
            }

            hash_file_poster = GLib.Checksum.compute_for_string (ChecksumType.MD5, video_file.get_uri (), video_file.get_uri ().length);
            hash_episode_poster = GLib.Checksum.compute_for_string (ChecksumType.MD5, video_file.get_parent ().get_uri (), video_file.get_parent ().get_uri ().length);

            thumbnail_large_path = Path.build_filename (GLib.Environment.get_user_cache_dir (), "thumbnails", "large", hash_file_poster + ".png");
            thumbnail_normal_path = Path.build_filename (GLib.Environment.get_user_cache_dir (), "thumbnails", "normal", hash_file_poster + ".png");
            poster_cache_file = Path.build_filename (App.get_instance ().get_cache_directory (), hash_file_poster + ".jpg");

            notify["poster"].connect (() => {
                poster_changed (this);
            });
            notify["title"].connect (() => {
                title_changed (this);
            });
            notify["thumbnail"].connect (() => {
                thumbnail_changed ();
            });
        }

        private void extract_metadata () {
            // exclude YEAR from Title
            MatchInfo info;
            if (manager.regex_year.match (this.title, 0, out info)) {
                year = int.parse (info.fetch (0).substring (1, 4));
                title = this.title.replace (info.fetch (0) + ")", "").strip ();
            }
        }

        public async void initialize_poster () {
            poster_initialized = true;
            initialize_poster_thread.begin ((obj, res) => {
                poster = initialize_poster_thread.end (res);
                set_pixbufs ();
            });
        }

        private async Gdk.Pixbuf? initialize_poster_thread () {
            SourceFunc callback = initialize_poster_thread.callback;
            Gdk.Pixbuf? pixbuf = null;

            ThreadFunc<void*> run = () => {
                if (!FileUtils.test (thumbnail_large_path, FileTest.EXISTS) ||
                    !FileUtils.test (thumbnail_normal_path, FileTest.EXISTS)) {

                    // Call DBUS for create a new THUMBNAIL
                    Gee.ArrayList<string> uris = new Gee.ArrayList<string> ();
                    Gee.ArrayList<string> mimes = new Gee.ArrayList<string> ();

                    uris.add (video_file.get_uri ());
                    mimes.add (mime_type);

                    manager.thumbler.instand (uris, mimes, "large");
                    manager.thumbler.instand (uris, mimes, "normal");
                }

                string? poster_path = poster_cache_file;
                pixbuf = manager.get_poster_from_file (poster_path);

                // POSTER in Cache exists
                if (pixbuf != null) {
                    Idle.add ((owned) callback);
                    return null;
                }

                poster_path = get_native_poster_path ();
                if (poster_path != null) {
                    pixbuf = manager.get_poster_from_file (poster_path);
                }

                // POSTER found
                if (pixbuf != null) {
                    try {
                        pixbuf.save (poster_cache_file, "jpeg");
                    } catch (Error e) {
                        warning (e.message);
                    }
                    Idle.add ((owned) callback);
                    return null;
                }

                if (FileUtils.test (thumbnail_large_path, FileTest.EXISTS)) {
                    pixbuf = manager.get_poster_from_file (thumbnail_large_path);
                    Idle.add ((owned) callback);
                    return null;
                }

                Idle.add ((owned) callback);
                return null;
            };

            try {
                new Thread<void*>.try (null, (owned)run);
            } catch (Error e) {
                warning (e.message);
            }

            yield;

            return pixbuf;
        }

        private void dbus_finished (uint heandle) {
            set_pixbufs ();
        }

        public void set_pixbufs () {
            if (poster == null && FileUtils.test (thumbnail_large_path, FileTest.EXISTS)) {
                poster = manager.get_poster_from_file (thumbnail_large_path);
            }
            if (thumbnail == null && FileUtils.test (thumbnail_normal_path, FileTest.EXISTS)) {
                try {
                    thumbnail = new Gdk.Pixbuf.from_file (thumbnail_normal_path);
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }

        public string get_path () {
            return Path.build_filename (directory, file);
        }

        public string? get_native_poster_path () {
            string poster_path = this.get_path () + ".jpg";
            File file_poster = File.new_for_path (poster_path);

            if (file_poster.query_exists ())
                return poster_path;

            poster_path = Path.build_filename (this.directory, Audience.get_title (file) + ".jpg");
            file_poster = File.new_for_path (poster_path);

            if (file_poster.query_exists ())
               return poster_path;

            foreach (string s in Audience.settings.get_strv ("poster-names")) {
                poster_path = Path.build_filename (this.directory, s);
                file_poster = File.new_for_path (poster_path);
                if (file_poster.query_exists ())
                   return poster_path;
            }

            return null;
        }

        public void set_new_poster (Gdk.Pixbuf? new_poster) {
            manager.clear_cache.begin (this.poster_cache_file);
            poster = new_poster;
        }
    }
}
