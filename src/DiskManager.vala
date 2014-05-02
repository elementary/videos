
public class Audience.DiskManager : GLib.Object {
    public signal void volume_found (Volume volume);
    public signal void volume_removed (Volume volume);

    private static DiskManager disk_manager = null;
    public static DiskManager get_default () {
        if (disk_manager == null) {
            disk_manager = new DiskManager ();
        }
        return disk_manager;
    }

    private GLib.VolumeMonitor monitor;
    private List<Volume> volumes;

    private DiskManager () {
        monitor = GLib.VolumeMonitor.get ();
        volumes = monitor.get_volumes ();

        monitor.drive_changed.connect ((drive) => {
            stdout.printf ("Drive changed: %s\n", drive.get_name ());
            if (drive.is_media_check_automatic ()) {
                if (drive.has_media ()) {
                    
                }
            }
        });

        monitor.drive_connected.connect ((drive) => {
            debug ("Drive connected: %s", drive.get_name ());
            if (drive.is_media_check_automatic ()) {
                if (drive.has_media ()) {
                    
                }
            }
        });

        monitor.drive_disconnected.connect ((drive) => {
            debug ("Drive disconnected: %s", drive.get_name ());
        });

        monitor.drive_eject_button.connect ((drive) => {
            debug ("Drive eject-button: %s", drive.get_name ());
        });

        monitor.drive_stop_button.connect ((drive) => {
            debug ("Drive stop-button:%s", drive.get_name ());
        });

        monitor.volume_added.connect ((volume) => {
            if (volume.get_drive ().is_media_check_automatic ()) {
                if (volume.get_drive ().has_media ()) {
                    volumes.append (volume);
                    volume_found (volume);
                }
            }
            debug ("Volume added: %s", volume.get_name ());
        });

        monitor.volume_changed.connect ((volume) => {
            if (volume.get_drive ().is_media_check_automatic ()) {
                if (volume.get_drive ().has_media ()) {
                    volumes.append (volume);
                    volume_found (volume);
                }
            }
            debug ("Volume changed: %s", volume.get_name ());
        });

        monitor.volume_removed.connect ((volume) => {
            volumes.remove (volume);
            volume_removed (volume);
            debug ("Volume removed: %s", volume.get_name ());
        });
    }
    
    public GLib.List<Volume> get_volumes () {
        return volumes.copy ();
    }
}