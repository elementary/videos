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

        public signal void video_file_detected (Audience.Objects.Video video);
        public signal void video_file_deleted (string path);
        public signal void video_moved_to_trash (string path);
        public signal void finished ();

        public Regex regex_year { get; construct set; }
        public DbusThumbnailer thumbler { get; construct set; }

        public bool has_items { get; private set; }
        public bool is_scanning { get; private set; }

        public ListStore library_items { get; construct; } // Has toplevel items i.e. shows and standalone videos

        private HashTable<string, Objects.MediaItem> shows;
        private Gee.ArrayList<string> poster_hash;
        private Gee.ArrayList<DirectoryMonitoring> monitoring_directories;
        private Gee.Queue<string> unchecked_directories;

        private Gee.ArrayList<string> trashed_files;

        private Gst.PbUtils.Discoverer discoverer;

        public static LibraryManager instance = null;
        public static LibraryManager get_instance () {
            if (instance == null) {
                instance = new LibraryManager ();
            }

            return instance;
        }

        construct {
            try {
                discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));
                discoverer.discovered.connect (create_new_video_object);
            } catch (Error e) {
                warning (e.message);
            }

            library_items = new ListStore (typeof (Objects.MediaItem));
            shows = new HashTable<string, Objects.MediaItem> (str_hash, str_equal);
            trashed_files = new Gee.ArrayList<string> ();
            poster_hash = new Gee.ArrayList<string> ();
            monitoring_directories = new Gee.ArrayList<DirectoryMonitoring> ();
            unchecked_directories = new Gee.UnrolledLinkedList<string> ();
            try {
                regex_year = new Regex ("\\(\\d\\d\\d\\d(?=(\\)$))");
            } catch (Error e) {
                warning (e.message);
            }
            thumbler = new DbusThumbnailer ();

            finished.connect (() => { clear_unused_cache_files.begin (); });
        }

        public void begin_scan () {
            unchecked_directories.offer (Environment.get_user_special_dir (UserDirectory.VIDEOS));
            detect_video_files.begin ();
        }

        private void monitored_directory_changed (FileMonitor monitor, File src, File? dest, FileMonitorEvent event) {
            if (event == GLib.FileMonitorEvent.DELETED) {
                video_file_deleted (src.get_path ());
                foreach (DirectoryMonitoring item in monitoring_directories) {
                    if (item.path == src.get_path ()) {
                        item.monitor.cancel ();
                    }
                }
            }
            else if (event == GLib.FileMonitorEvent.CHANGES_DONE_HINT) {
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
                    string src_path = src.get_path ();
                    // create_video_object (file_info, Path.get_dirname (src_path), Path.get_basename (src_path));
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
            discoverer.start ();
            has_items = true;

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
                            discoverer.discover_uri_async (file.get_uri ());
                            // create_video_object (file_info, source);
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

            finished ();
            is_scanning = false;
        }

        private bool is_file_valid (FileInfo file_info) {
            string mime_type = file_info.get_content_type ();
            return !file_info.get_is_hidden () && mime_type.contains ("video");
        }

        private void create_new_video_object (Gst.PbUtils.DiscovererInfo info, Error? err) {
            var file = File.new_for_uri (info.get_uri ());

            var title = get_title (file.get_path ());

            unowned Gst.TagList? tag_list = info.get_tags ();
            if (tag_list == null) {
                warning ("Tag list is null");
            } else {
                string? _title = null;
                tag_list.get_string (Gst.Tags.TITLE, out _title);
                if (_title != null) {
                    title = _title;
                }
            }

            Objects.MediaItem? item = null;
            if (file.get_parent ().get_path () != Environment.get_user_special_dir (UserDirectory.VIDEOS)) {
                var parent_file = file.get_parent ();
                var parent_name = get_title (parent_file.get_path ());
                if (!(parent_name in shows)) {
                    shows[parent_name] = new Objects.MediaItem.show (parent_name);
                    library_items.insert_sorted (shows[parent_name], library_item_sort_func);
                }
                item = new Audience.Objects.MediaItem.video (file.get_uri (), title, shows[parent_name]);
            } else {
                item = new Audience.Objects.MediaItem.video (file.get_uri (), title, null);
                library_items.insert_sorted (item, library_item_sort_func);
            }

            has_items = true;
        }

        public static int library_item_sort_func (Object item1, Object item2) {
            var library_item1 = (Objects.MediaItem) item1;
            var library_item2 = (Objects.MediaItem) item2;
            if (library_item1 != null && library_item2 != null) {
                return library_item1.title.collate (library_item2.title);
            }

            return 0;
        }

        public async void clear_cache (string cache_file) {
            File file = File.new_for_path (cache_file);
            if (file.query_exists ()) {
                try {
                    yield file.delete_async (Priority.DEFAULT, null);
                } catch (Error e) {
                    warning (e.message);
                }
            }
        }

        public async void clear_unused_cache_files () {
            File directory = File.new_for_path (((Audience.App) Application.get_default ()).get_cache_directory ());
            directory.enumerate_children_async.begin (FileAttribute.STANDARD_NAME, 0, Priority.DEFAULT, null, (obj, res) => {
                try {
                    FileEnumerator children = directory.enumerate_children_async.end (res);
                    FileInfo file_info;
                    while ((file_info = children.next_file ()) != null) {
                        if (!poster_hash.contains (file_info.get_name ())) {
                            File to_delete = children.get_child (file_info);
                            Process.spawn_command_line_async ("rm " + to_delete.get_path ());
                        }
                    }
                } catch (Error e) {
                    warning (e.message);
                }
            });
        }

        public void deleted_items (string path) {
            trashed_files.add (path);
            video_moved_to_trash (path);
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
