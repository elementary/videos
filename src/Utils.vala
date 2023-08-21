/*-
 * Copyright (c) 2013-2019 elementary, Inc. (https://elementary.io)
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
 * Authored by: Tom Beckmann <tomjonabc@gmail.com>
 */

namespace Audience {
    private const int DISCOVERER_TIMEOUT = 5;

    public delegate void FuncOverDir (File file_under_dir);
    public static void recurse_over_dir (File file_to_process, FuncOverDir func) {
        if (file_to_process.query_file_type (0) == FileType.DIRECTORY) {
            try {
                var files = file_to_process.enumerate_children (FileAttribute.STANDARD_NAME + "," + FileAttribute.ACCESS_CAN_READ, FileQueryInfoFlags.NONE);
                FileInfo info;
                while ((info = files.next_file ()) != null) {
                    var file = GLib.File.new_for_uri (file_to_process.get_uri () + "/" + info.get_name ());
                    recurse_over_dir (file, func);
                }
            } catch (Error e) {
                critical (e.message);
            }
        } else {
            func (file_to_process);
        }
    }
    public static string get_title (string filename) {
        var title = get_basename (filename);
        title = Uri.unescape_string (title);
        title = title.replace ("_", " ").replace (".", " ").replace ("  ", " ");

        return title;
    }

    public static string get_basename (string filename) {
        var basename = Path.get_basename (filename);

        var index_of_last_dot = basename.last_index_of (".");
        var launcher_base = (index_of_last_dot >= 0 ? basename.slice (0, index_of_last_dot) : basename);

        return launcher_base;
    }

    public static Gst.PbUtils.DiscovererInfo? get_discoverer_info (string uri) {
        Gst.PbUtils.Discoverer discoverer = null;
        try {
            discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (DISCOVERER_TIMEOUT * Gst.SECOND));
        } catch (Error e) {
            debug ("Could not create Gst discoverer object: %s", e.message);
        }

        Gst.PbUtils.DiscovererInfo discoverer_info = null;
        try {
            discoverer_info = discoverer.discover_uri (uri);
        } catch (Error e) {
            debug ("Discoverer Error %d: %s\n", e.code, e.message);
        }

        return discoverer_info;
    }

    public static bool is_sandboxed () {
        return FileUtils.test ("/.flatpak-info", FileTest.EXISTS);
    }

    private static bool file_equal_func (Object a, Object b) {
        if (a is File && b is File) {
            return ((File) a).get_uri () == ((File) b).get_uri ();
        }

        return false;
    }
}
