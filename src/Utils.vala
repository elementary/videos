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
        uint end = 0;
        for (uint start=filename.length; start != 0; start--) {
            if (filename[start] == '/') {
                start ++;
                return filename.substring (start, end - start);
            }

            if (filename[start] == '.' && end == 0)
                end = start;
        }

        return filename.substring (0, end);
    }

    public static string seconds_to_time (int seconds) {
        int hours = seconds / 3600;
        string min = normalize_time ((seconds % 3600) / 60);
        string sec = normalize_time (seconds % 60);

        if (hours > 0) {
            return ("%d:%s:%s".printf (hours, min, sec));
        } else {
            return ("%s:%s".printf (min, sec));
        }
    }

    public static string normalize_time (int time) {
        if (time < 10) {
            return "0%d".printf (time);
        } else {
            return "%d".printf (time);
        }
    }

    public static bool has_dvd () {
        var disk_manager = DiskManager.get_default ();
        return disk_manager.get_volumes ().length () > 0;
    }
}