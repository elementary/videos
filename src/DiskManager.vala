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
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

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
            debug ("Drive changed: %s\n", drive.get_name ());
        });

        monitor.drive_connected.connect ((drive) => {
            debug ("Drive connected: %s", drive.get_name ());
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
            check_for_volume (volume);
            debug ("Volume added: %s", volume.get_name ());
        });

        monitor.volume_changed.connect ((volume) => {
            check_for_volume (volume);
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

    public GLib.List<Volume> get_media_volumes () {
        GLib.List<Volume> returnValue = new GLib.List<Volume> ();
        foreach (Volume volume in get_volumes ()) {
            if (has_dvd_media (volume))
                returnValue.append (volume);
        }
        return returnValue;
    }

    public bool has_media_volumes () {
        return (get_media_volumes ().length () > 0);
    }

    private void check_for_volume (Volume volume) {
        if (has_dvd_media (volume)) {
            volumes.append (volume);
            volume_found (volume);
        }
    }

    private bool has_dvd_media (Volume volume) {
        debug ("Check DVD media for: %s", volume.get_name ());
        if (volume.get_drive () != null && volume.get_drive ().has_media ()) {
            var root = volume.get_mount ().get_default_location ();
            if (root != null) {
                debug ("Activation root: %s", root.get_uri ());
                var video = root.get_child ("VIDEO_TS");
                var bdmv = root.get_child ("BDMV");
                var audio = root.get_child ("AUDIO_TS");
                if (audio.query_exists () || video.query_exists () || bdmv.query_exists ()) {
                    return true;
                }
            }
        }
        return false;
    }
}