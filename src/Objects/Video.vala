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

namespace Audience.Objects {

    public class Video : Object {

        public File VideoFile { get; private set; }
        public string Directory { get; private set; }
        public string Title { get; private set; }
        public Gdk.Pixbuf? Poster { get; private set; }

        public Video (string directory, string file) {
            this.Directory = directory;
            this.Title = file;
            VideoFile = File.new_for_path (this.get_path ());
            extract_infos ();
        }

        private void extract_infos () {
            // Check if Poster exists
            try {
                string poster_path = this.get_path () + ".jpg";
                this.Poster = get_poster_pixbuf(poster_path);

                if (this.Poster == null) {
                    poster_path = this.Directory + "/Poster.jpg";
                    this.Poster = get_poster_pixbuf(poster_path);
                }
                if (this.Poster == null) {
                    poster_path = this.Directory + "/poster.jpg";
                    this.Poster = get_poster_pixbuf(poster_path);
                }

                if (this.Poster == null) {
                    poster_path = this.Directory + "/Cover.jpg";
                    this.Poster = get_poster_pixbuf(poster_path);
                }

                if (this.Poster == null) {
                    poster_path = this.Directory + "/cover.jpg";
                    this.Poster = get_poster_pixbuf(poster_path);
                }

            } catch (Error e) {
                critical (e.message);
            }
        }

        private string get_path (){
            return Directory + "/" + Title;
        }

        public Gdk.Pixbuf? get_poster_pixbuf (string poster_path) {
            debug ("Poster: %s", poster_path);
            File poster = File.new_for_path (poster_path);
            if (poster.query_exists ()) {
                debug ("Poster EXISTS: %s", poster_path);
                return new Gdk.Pixbuf.from_file_at_scale (poster_path, -1, 240, true);

            }

            return null;
        }
    }
}
