
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
                var files = file_to_process.enumerate_children (FileAttribute.STANDARD_NAME, 0);
                FileInfo info;
                while ((info = files.next_file ()) != null) {
                    var file = GLib.File.new_for_uri (
                        file_to_process.get_uri ()  +"/"+info.get_name ());
                    recurse_over_dir (file,func);
                }
            } catch (Error e) { warning (e.message); }
        }
        else {
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
        int i=0;
        for (i=filename.length;i!=0;i--) {
            if (filename [i] == '.')
                break;       
        }
        return filename.substring (i+1);
    }

    public static string get_basename (string filename) {
        int start = 0, end = 0;
        for (start=filename.length; start != 0; start--) {
            if (filename[start] == '/') {
                start ++;
                break;
            }
            if (filename[start] == '.' && end == 0)
                end = start;
        }
        return filename.substring (start, end - start);
    }

    public static string seconds_to_time (int seconds) {
        int hours = seconds / 3600;
        int minutes = (seconds % 3600) / 60;
        seconds = seconds % 60;

        string time = (hours > 0) ? hours.to_string() + ":" : "";
        time += (((hours > 0) && (minutes < 10)) ? "0" : "") + minutes.to_string() + ":";
        time += ((seconds < 10) ? "0" : "") + seconds.to_string();
        return time;
    }

    public static bool has_dvd () {
        var disk_manager = DiskManager.get_default ();
        return disk_manager.get_volumes ().length () > 0;
    }
}