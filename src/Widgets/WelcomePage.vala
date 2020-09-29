/*
 * Copyright 2013-2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class Audience.WelcomePage : Granite.Widgets.Welcome {
    private string current_video;
    private Granite.Widgets.WelcomeButton replay_button;

    public WelcomePage () {
        Object (
            title: _("No Videos Open"),
            subtitle: _("Select a source to begin playing.")
        );
    }

    construct {
        append ("document-open", _("Open file"), _("Open a saved file."));
        append ("media-playlist-repeat", _("Replay last video"), "");
        append ("media-cdrom", _("Play from Disc"), _("Watch a DVD or open a file from disc"));
        append ("folder-videos", _("Browse Library"), _("Watch a movie from your library"));

        var disk_manager = DiskManager.get_default ();
        set_item_visible (2, disk_manager.has_media_volumes ());

        var library_manager = Services.LibraryManager.get_instance ();
        set_item_visible (3, library_manager.has_items);

        replay_button = get_button_from_index (1);
        update_replay_button ();
        update_replay_title ();

        activated.connect ((index) => {
            var window = App.get_instance ().mainwindow;
            switch (index) {
                case 0:
                    // Open file
                    window.run_open_file (true);
                    break;
                case 1:
                    window.add_to_playlist (current_video, true);
                    window.resume_last_videos ();
                    break;
                case 2:
                    window.run_open_dvd ();
                    break;
                case 3:
                    window.show_library ();
            }
        });

        settings.changed["current-video"].connect (() => {
            update_replay_button ();
        });

        settings.changed["last-stopped"].connect (() => {
            update_replay_title ();
        });

        disk_manager.volume_found.connect ((vol) => {
            set_item_visible (2, disk_manager.has_media_volumes ());
        });

        disk_manager.volume_removed.connect ((vol) => {
            set_item_visible (2, disk_manager.has_media_volumes ());
        });

        library_manager.video_file_detected.connect ((vid) => {
            set_item_visible (3, true);
            show_all ();
        });

        library_manager.video_file_deleted.connect ((vid) => {
            set_item_visible (3, LibraryPage.get_instance ().has_items);
        });
    }

    private void update_replay_button () {
        bool show_replay_button = false;

        current_video = settings.get_string ("current-video");
        if (current_video != "") {
            var last_file = File.new_for_uri (current_video);
            if (last_file.query_exists () == true) {
                replay_button.description = get_title (last_file.get_basename ());

                show_replay_button = true;
            }
        }

        set_item_visible (1, show_replay_button);
    }

    private void update_replay_title () {
        if (settings.get_double ("last-stopped") == 0.0 || !settings.get_boolean ("resume-videos")) {
            replay_button.title = _("Replay last video");
            replay_button.icon.icon_name = ("media-playlist-repeat");
        } else {
            replay_button.title = _("Resume last video");
            replay_button.icon.icon_name = ("media-playback-start");
        }
    }
}
