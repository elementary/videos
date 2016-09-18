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

        public File video_file { get; private set; }
        public string directory { get; private set; }
        public string file { get; private set; }

        public string title { get; private set; }
        public int year { get; private set; }

        public Gdk.Pixbuf? poster { get; private set; }

        private string mime_type;
        private string poster_cache_file;

        private uint dbus_handle = 0;

        public Video (string directory, string file, string mime_type) {
            manager = Audience.Services.LibraryManager.get_instance ();

            this.directory = directory;
            this.file = file;
            this.title = Audience.get_title (file);

            this.extract_infos ();

            this.mime_type = mime_type;
            video_file = File.new_for_path (this.get_path ());

            notify["poster"].connect (() => {
                poster_changed ();
            });
        }

        private void extract_infos () {
            // exclude YEAR from Title
            MatchInfo info;
            try {
                Regex regex = new Regex("\\(\\d\\d\\d\\d(?=(\\)$))");

                if (regex.match (this.title, 0, out info)) {
                    this.year = int.parse (info.fetch (0).substring (1, 4));
                    this.title = this.title.replace (info.fetch (0) + ")", "");
                }
            } catch (Error e) {
                warning (e.message);
            }
        }

        public async void initialize_poster () {
            try {
                string hash = GLib.Checksum.compute_for_string (ChecksumType.MD5, this.get_path (), this.get_path ().length);

                poster_cache_file = Path.build_filename (App.get_instance ().get_cache_directory (), hash + ".jpg");

                string poster_path = poster_cache_file;
                set_poster_from_file(poster_path);

                // POSTER in Cache exists
                if (this.poster != null) {
                    return;
                }

                // Try to find a POSTER in same folder of video file
                if (this.poster == null) {
                    poster_path = this.get_path () + ".jpg";
                    set_poster_from_file(poster_path);
                }

                if (this.poster == null) {
                    poster_path = Path.build_filename (this.directory, Audience.get_title (file) + ".jpg");
                    set_poster_from_file(poster_path);
                }

                foreach (string s in Audience.settings.poster_names) {
                    if (this.poster == null) {
                        poster_path = Path.build_filename (this.directory, s);
                        set_poster_from_file(poster_path);
                    } else {
                        break;
                    }
                }

                // POSTER found
                if (this.poster != null) {
                    this.poster.save (poster_cache_file, "jpeg");
                    return;
                }

                // Check if THUMBNAIL exists
                string? thumbnail_path = manager.get_thumbnail_path (video_file);
                if (thumbnail_path != null) {
                    set_poster_from_file (thumbnail_path);
                    return;
                }

                // Call DBUS for create a new THUMBNAIL
                manager.thumbler.finished.connect (thumbnail_created);
                dbus_handle = manager.thumbler.Queue (video_file.get_uri (), mime_type);

            } catch (Error e) {
                critical (e.message);
            }
        }

        private void thumbnail_created (uint handle) {

            if (dbus_handle == handle) {
                manager.thumbler.finished.disconnect (thumbnail_created);

                string? thumbnail_path = manager.get_thumbnail_path (video_file);
                if (thumbnail_path != null) {
                    set_poster_from_file (thumbnail_path);
                }
            }
        }

        public string get_path (){
            return Path.build_filename(directory, file);
        }

        public void set_poster_from_file (string poster_path) {

            if (File.new_for_path (poster_path).query_exists ()) {
                Gdk.Pixbuf pixbuf = null;

                try {
                    pixbuf = new Gdk.Pixbuf.from_file_at_scale (poster_path, -1, Audience.Services.POSTER_HEIGHT, true);
                } catch (Error e) {
                    warning (e.message);
                }

                if (pixbuf == null) {
                    return;
                }
                // Cut THUMBNAIL images
                int width = pixbuf.width;
                if (width > Audience.Services.POSTER_WIDTH) {
                    int x_offset = (width - Audience.Services.POSTER_WIDTH) / 2;
                    this.poster = new Gdk.Pixbuf.subpixbuf (pixbuf, x_offset, 0, Audience.Services.POSTER_WIDTH, Audience.Services.POSTER_HEIGHT);
                } else {
                    this.poster = pixbuf;
                }

            } else {
                this.poster = null;
            }
        }
    }
}
