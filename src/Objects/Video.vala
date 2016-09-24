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

        public signal void poster_changed ();
        public signal void title_changed ();

        public File video_file { get; private set; }
        public string directory { get; construct set; }
        public string file { get; construct set; }

        public string title { get; private set; }
        public int year { get; private set; default = -1;}

        public Gdk.Pixbuf? poster { get; private set; }

        public string mime_type { get; construct set; }
        public string poster_cache_file { get; private set; }

        public string hash { get; construct set; }

        public Video (string directory, string file, string mime_type) {
            Object (directory: directory, file: file, mime_type: mime_type);
        }

        construct {
            manager = Audience.Services.LibraryManager.get_instance ();
            manager.thumbler.finished.connect (dbus_finished);

            this.title = Audience.get_title (file);

            this.extract_metadata ();
            video_file = File.new_for_path (this.get_path ());

            hash = GLib.Checksum.compute_for_string (ChecksumType.MD5, this.get_path (), this.get_path ().length);

            poster_cache_file = Path.build_filename (App.get_instance ().get_cache_directory (), hash + ".jpg");

            notify["poster"].connect (() => {
                poster_changed ();
            });
            notify["title"].connect (() => {
                title_changed ();
            });
        }

        private void extract_metadata () {
            // exclude YEAR from Title
            MatchInfo info;
            if (manager.regex_year.match (this.title, 0, out info)) {
                this.year = int.parse (info.fetch (0).substring (1, 4));
                this.title = this.title.replace (info.fetch (0) + ")", "").strip ();
            }
        }

        public async void initialize_poster () {
            initialize_poster_thread.begin ((obj, res) => {
                this.poster = initialize_poster_thread.end (res);
            });
        }

        public async Gdk.Pixbuf? initialize_poster_thread () {
            SourceFunc callback = initialize_poster_thread.callback;
            Gdk.Pixbuf? pixbuf = null;

            ThreadFunc<void*> run = () => {

                string? poster_path = poster_cache_file;
                pixbuf = get_poster_from_file (poster_path);

                // POSTER in Cache exists
                if (pixbuf != null) {
                    Idle.add ((owned) callback);
                    return null;
                }

                poster_path = get_native_poster_path ();
                if (poster_path != null) {
                    pixbuf = get_poster_from_file (poster_path);
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

                // Check if THUMBNAIL exists
                string? thumbnail_path = manager.get_thumbnail_path (video_file);
                if (thumbnail_path != null) {
                    pixbuf = get_poster_from_file (thumbnail_path);
                    Idle.add ((owned) callback);
                    return null;
                }

                // Call DBUS for create a new THUMBNAIL
                Gee.ArrayList<string> uris = new Gee.ArrayList<string> ();
                Gee.ArrayList<string> mimes = new Gee.ArrayList<string> ();

                uris.add (video_file.get_uri ());
                mimes.add (mime_type);

                manager.thumbler.Instand (uris, mimes);

                Idle.add ((owned) callback);
                return null;
            };

            try {
                new Thread<void*>.try (null, run);
            } catch (Error e) {
                error (e.message);
            }

            yield;

            return pixbuf;
        }

        private void dbus_finished (uint heandle) {
            if (poster == null) {
                string? thumbnail_path = manager.get_thumbnail_path (video_file);
                if (thumbnail_path != null) {
                    poster = get_poster_from_file (thumbnail_path);
                }
            }
        }

        public string get_path () {
            return Path.build_filename (directory, file);
        }

        public Gdk.Pixbuf? get_poster_from_file (string poster_path) {
            Gdk.Pixbuf pixbuf = null;
            if (File.new_for_path (poster_path).query_exists ()) {
                try {
                    pixbuf = new Gdk.Pixbuf.from_file_at_scale (poster_path, -1, Audience.Services.POSTER_HEIGHT, true);
                } catch (Error e) {
                    warning (e.message);
                }

                if (pixbuf == null) {
                    return null;
                }
                // Cut THUMBNAIL images
                int width = pixbuf.width;
                if (width > Audience.Services.POSTER_WIDTH) {
                    int x_offset = (width - Audience.Services.POSTER_WIDTH) / 2;
                    pixbuf = new Gdk.Pixbuf.subpixbuf (pixbuf, x_offset, 0, Audience.Services.POSTER_WIDTH, Audience.Services.POSTER_HEIGHT);
                }
            }

            return pixbuf;
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

            foreach (string s in Audience.settings.poster_names) {
                poster_path = Path.build_filename (this.directory, s);
                file_poster = File.new_for_path (poster_path);
                if (file_poster.query_exists ())
                   return poster_path;
            }

            return null;
        }

        public void rename_file (string new_title) {
            string new_file_name = new_title.strip ();

            string src_path = this.video_file.get_path ();
            string dest_path = Path.build_filename (Path.get_dirname (src_path), Path.get_basename (src_path).replace (title, new_file_name));

            File dest = File.new_for_path (dest_path);
            if (!dest.query_exists ()) {
                try {
                    video_file.move (dest, FileCopyFlags.NONE);
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }
    }
}
