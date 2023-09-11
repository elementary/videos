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

namespace Audience.Services {
    public const int POSTER_WIDTH = 170;
    public const int POSTER_HEIGHT = 240;

    public class LibraryManager : Object {
        public signal void media_item_trashed (Objects.MediaItem item);
        public signal void video_file_deleted (string uri);
        public signal void finished ();

        public Regex regex_year { get; construct set; }
        public DbusThumbnailer thumbler { get; construct set; }

        public bool is_scanning { get; private set; }

        public ListStore library_items { get; construct; } // Has toplevel items i.e. shows and standalone videos

        private HashTable<string, Objects.MediaItem> shows;
        private Gee.ArrayList<DirectoryMonitoring> monitoring_directories;
        private Gee.Queue<string> unchecked_directories;

        private Gee.ArrayList<string> trashed_files;

        public static LibraryManager instance = null;
        public static LibraryManager get_instance () {
            if (instance == null) {
                instance = new LibraryManager ();
            }

            return instance;
        }

        construct {
            library_items = new ListStore (typeof (Objects.MediaItem));
            shows = new HashTable<string, Objects.MediaItem> (str_hash, str_equal);
            trashed_files = new Gee.ArrayList<string> ();
            monitoring_directories = new Gee.ArrayList<DirectoryMonitoring> ();
            unchecked_directories = new Gee.UnrolledLinkedList<string> ();
            try {
                regex_year = new Regex ("\\(\\d\\d\\d\\d(?=(\\)$))");
            } catch (Error e) {
                warning (e.message);
            }
            thumbler = new DbusThumbnailer ();
        }

        public void begin_scan () {
            unchecked_directories.offer (Environment.get_user_special_dir (UserDirectory.VIDEOS));
            detect_video_files.begin ();
        }

        private void monitored_directory_changed (FileMonitor monitor, File src, File? dest, FileMonitorEvent event) {
            if (event == GLib.FileMonitorEvent.DELETED) {
                video_file_deleted (src.get_uri ());
                foreach (DirectoryMonitoring item in monitoring_directories) {
                    if (item.path == src.get_path ()) {
                        item.monitor.cancel ();
                    }
                }
            } else if (event == GLib.FileMonitorEvent.CHANGES_DONE_HINT) {
                FileInfo file_info;
                try {
                    file_info = src.query_info (FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_IS_HIDDEN + "," + FileAttribute.STANDARD_TYPE, 0);
                } catch (Error e) {
                    warning (e.message);
                    return;
                }
                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    unchecked_directories.offer (src.get_path ());
                    if (!is_scanning) {
                        detect_video_files.begin ();
                    }
                } else if (is_file_valid (file_info)) {
                    create_video_object (src);
                }
            }
        }

        private void monitor_directory (string path, File directory) {
            try {
                DirectoryMonitoring dir_monitor = new DirectoryMonitoring (path, directory.monitor (FileMonitorFlags.NONE, null));
                dir_monitor.monitor.changed.connect (monitored_directory_changed);
                monitoring_directories.add (dir_monitor);
            } catch (Error e) {
                warning (e.message);
            }
        }

        public async void detect_video_files () throws GLib.Error {
            is_scanning = true;

            while (!unchecked_directories.is_empty) {
                string source = unchecked_directories.poll ();
                Idle.add (detect_video_files.callback);
                yield;

                try {
                    File directory = File.new_for_path (source);
                    var children = directory.enumerate_children (FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_IS_HIDDEN, 0);

                    bool videos_found = false;
                    FileInfo file_info;
                    while ((file_info = children.next_file ()) != null) {
                        if (file_info.get_file_type () == FileType.DIRECTORY) {
                            unchecked_directories.offer (source + "/" + file_info.get_name ());
                            continue;
                        }

                        if (is_file_valid (file_info)) {
                            var file = File.new_build_filename (source, file_info.get_name ());
                            create_video_object (file);
                            videos_found = true;
                        }
                    }
                    if (videos_found) {
                        monitor_directory (source, directory);
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            }

            is_scanning = false;
        }

        private bool is_file_valid (FileInfo file_info) {
            string mime_type = file_info.get_content_type ();
            return !file_info.get_is_hidden () && mime_type.contains ("video");
        }

        private void create_video_object (File file) {
            var title = get_title (file.get_path ());

            if (file.get_parent ().get_path () != Environment.get_user_special_dir (UserDirectory.VIDEOS)) {
                var parent_file = file.get_parent ();
                var parent_name = get_title (parent_file.get_path ());

                if (!(parent_name in shows)) {
                    shows[parent_name] = new Objects.MediaItem.show (parent_name);
                    library_items.insert_sorted (shows[parent_name], library_item_sort_func);
                    shows[parent_name].trashed.connect (() => remove_item (shows.take (parent_name)));
                }

                shows[parent_name].add_item (new Audience.Objects.MediaItem.video (file.get_uri (), title, shows[parent_name]));
            } else {
                var item = new Audience.Objects.MediaItem.video (file.get_uri (), title, null);
                library_items.insert_sorted (item, library_item_sort_func);
                item.trashed.connect (() => remove_item (item));
            }
        }

        public static int library_item_sort_func (Object item1, Object item2) {
            var library_item1 = (Objects.MediaItem) item1;
            var library_item2 = (Objects.MediaItem) item2;
            if (library_item1 != null && library_item2 != null) {
                return library_item1.title.collate (library_item2.title);
            }

            return 0;
        }

        public void remove_item (Objects.MediaItem item) {
            if (item.uri != null) {
                trashed_files.add (item.uri);
                media_item_trashed (item);
            }

            uint position;
            if (library_items.find (item, out position)) {
                library_items.remove (position);
            }
        }

        public void undo_delete_item () {
            if (trashed_files.size > 0) {
                string restore = trashed_files.last ();
                File trash = File.new_for_uri ("trash:///");
                try {
                    var children = trash.enumerate_children (FileAttribute.TRASH_ORIG_PATH + "," + FileAttribute.STANDARD_NAME, 0);
                    FileInfo file_info;
                    while ((file_info = children.next_file ()) != null) {
                        string orinal_path = file_info.get_attribute_as_string (FileAttribute.TRASH_ORIG_PATH);
                        if (orinal_path == restore) {
                            File restore_file = children.get_child (file_info);
                            restore_file.move (File.new_for_path (restore), 0);
                            trashed_files.remove (restore);
                            return;
                        }
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }

        public Gdk.Pixbuf? get_poster_from_file (string poster_path) {
            Gdk.Pixbuf? pixbuf = null;
            if (FileUtils.test (poster_path, FileTest.EXISTS)) {
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
    }
}
