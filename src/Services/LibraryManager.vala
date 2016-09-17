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

    public class LibraryManager : Object {

        public signal void video_file_detected (Audience.Objects.Video video);

        string video_directory;

        public LibraryManager () {
            video_directory = GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS);
        }

        public void begin_scan () {
            detect_video_files.begin (video_directory);
        }

        public async void detect_video_files (string source) {
            File directory = File.new_for_path (source);

            var children = directory.enumerate_children (FileAttribute.STANDARD_CONTENT_TYPE, 0);

            if (children != null) {
                FileInfo file_info;
                while ((file_info = children.next_file ()) != null) {

                    if (file_info.get_file_type () == FileType.DIRECTORY) {
                        detect_video_files.begin (source + "/" + file_info.get_name ());
                        continue;
                    }

                    string mime_type = file_info.get_content_type ();

                    if (mime_type.length >=5 && mime_type.substring (0, 5) == "video") {

                        Audience.Objects.Video video = new Audience.Objects.Video (source, file_info.get_name ());

                        video.poster_detected.connect ((path) => {
                            video.Poster.save (video.Poster_Hash_Path, "jpeg");
                        });

                        video.extract_infos ();
                        video_file_detected (video);
                    }
                }
            }
        }
    }
}
