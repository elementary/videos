// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013-2014 Audience Developers (http://launchpad.net/pantheon-chat)
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

[DBus (name = "org.gnome.SettingsDaemon.MediaKeys")]
public interface GnomeMediaKeys : GLib.Object {
    public abstract void GrabMediaPlayerKeys (string application, uint32 time) throws GLib.IOError;
    public abstract void ReleaseMediaPlayerKeys (string application) throws GLib.IOError;
    public signal void MediaPlayerKeyPressed (string application, string key);
}

[DBus (name = "org.gnome.SessionManager")]
public interface GnomeSessionManager : GLib.Object {
    public abstract bool isSessionRunning() throws GLib.IOError;
    public abstract uint32 Inhibit (string app_id, uint32 toplevel_xid, string reason, uint32 flags) throws GLib.IOError;
    public abstract void Uninhibit (uint32 inhibit_cookie) throws GLib.IOError;
}

namespace Audience {
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

    public static string get_extension (string filename) {
        for (uint i=filename.length; i!=0; i--) {
            if (filename[i] == '.')
                return filename.substring (i+1);
        }

        return filename;
    }

    public static string get_basename (string filename) {
        var basename = Path.get_basename (filename);

        var index_of_last_dot = basename.last_index_of (".");
        var launcher_base = (index_of_last_dot >= 0 ? basename.slice (0, index_of_last_dot) : basename);

        return launcher_base;
    }

    public static bool has_dvd () {
        return !DiskManager.get_default ().get_volumes ().is_empty;
    }

    public static bool file_exists (string uri) {
        var file = File.new_for_uri (uri);
        return file.query_exists ();
    }
}
