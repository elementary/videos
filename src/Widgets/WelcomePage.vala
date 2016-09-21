namespace Audience {
    public class WelcomePage : Granite.Widgets.Welcome {
        private DiskManager disk_manager;
        private Services.LibraryManager library_manager;
        public WelcomePage () {
            base (_("No Videos Open"), _("Select a source to begin playing."));
        }

        construct {
            append ("document-open", _("Open file"), _("Open a saved file."));

            var filename = settings.current_video;
            var last_file = File.new_for_uri (filename);
            bool show_last_file = settings.current_video != "";
            if (last_file.query_exists () == false) {
                show_last_file = false;
            }

            if (settings.last_stopped == 0.0 || !settings.resume_videos) {
                append ("media-playlist-repeat", _("Replay last video"), get_title (last_file.get_basename ()));
            } else {
                append ("media-playback-start", _("Resume last video"), get_title (last_file.get_basename ()));
            }

            set_item_visible (1, show_last_file);

            //look for dvd
            disk_manager = DiskManager.get_default ();
            disk_manager.volume_found.connect ((vol) => {
                set_item_visible (2, disk_manager.has_media_volumes ());
            });

            disk_manager.volume_removed.connect ((vol) => {
                set_item_visible (2, disk_manager.has_media_volumes ());
            });

            library_manager = Services.LibraryManager.get_instance ();
            library_manager.video_file_detected.connect ((vid) => {
                set_item_visible (3, true);
                this.show_all ();
            });

            append ("media-cdrom", _("Play from Disc"), _("Watch a DVD or open a file from disc"));
            set_item_visible (2, disk_manager.has_media_volumes ());

            append ("folder-videos", _("Browse Library"), _("Watch a movie from your library"));
            set_item_visible (3, library_manager.has_items);

            activated.connect ((index) => {
                var window = App.get_instance ().mainwindow;
                switch (index) {
                    case 0:
                        // Open file
                        window.run_open_file (true);
                        break;
                    case 1:
                        window.resume_last_videos ();
                        break;
                    case 2:
                        window.run_open_dvd ();
                        break;
                    case 3:
                        window.show_library ();
                }
            });
        }

        public void refresh () {
            var replay_button = get_button_from_index (1);
            var disk_button = get_button_from_index (2);

            var filename = settings.current_video;
            var last_file = File.new_for_uri (filename);

            replay_button.title = _("Replay last video");
            replay_button.description = get_title (last_file.get_basename ());
            replay_button.icon.icon_name = ("media-playlist-repeat");

            bool show_last_file = settings.current_video != "";
            if (last_file.query_exists () == false) {
                show_last_file = false;
            }

            set_item_visible (1, show_last_file);
            set_item_visible (2, disk_manager.has_media_volumes ());
        }
    }
}
