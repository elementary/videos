/*-
 * Copyright (c) 2013-2019 elementary Inc.
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
 *              Cody Garver <cody@elementaryos.org>
 *              Artem Anufrij <artem.anufrij@live.de>
 *              Corentin Noël <corentin@elementary.io>
 */

public class Audience.Window : Gtk.ApplicationWindow {
    private Adw.NavigationView navigation_view;
    private Granite.Toast app_notification;
    private EpisodesPage episodes_page;
    private LibraryPage library_page;
    private PlayerPage player_page;
    private WelcomePage welcome_page;

    public enum NavigationPage { WELCOME, LIBRARY, EPISODES }

    public signal void media_volumes_changed ();

    public const string ACTION_GROUP_PREFIX = "win";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string ACTION_BACK = "back";
    public const string ACTION_FULLSCREEN = "action-fullscreen";
    public const string ACTION_OPEN_FILE = "action-open-file";
    public const string ACTION_QUIT = "action-quit";
    public const string ACTION_SEARCH = "action-search";
    public const string ACTION_UNDO = "action-undo";

    private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_BACK, action_back },
        { ACTION_FULLSCREEN, action_fullscreen },
        { ACTION_OPEN_FILE, action_open_file },
        { ACTION_QUIT, action_quit },
        { ACTION_SEARCH, action_search },
        { ACTION_UNDO, action_undo }
    };

    static construct {
        action_accelerators[ACTION_FULLSCREEN] = "F";
        action_accelerators[ACTION_FULLSCREEN] = "F11";
        action_accelerators[ACTION_OPEN_FILE] = "<Control>O";
        action_accelerators[ACTION_QUIT] = "<Control>Q";
        action_accelerators[ACTION_SEARCH] = "<Control>F";
        action_accelerators[ACTION_UNDO] = "<Control>Z";
    }

    construct {
        add_action_entries (ACTION_ENTRIES, this);

        var application_instance = (Gtk.Application) GLib.Application.get_default ();
        foreach (var action in action_accelerators.get_keys ()) {
            application_instance.set_accels_for_action (
                ACTION_PREFIX + action, action_accelerators[action].to_array ()
            );
        }

        set_default_size (1000, 680);

        library_page = LibraryPage.get_instance ();

        welcome_page = new WelcomePage ();

        player_page = new PlayerPage ();

        episodes_page = new EpisodesPage ();

        navigation_view = new Adw.NavigationView ();
        navigation_view.add (welcome_page);

        app_notification = new Granite.Toast ("");

        var overlay = new Gtk.Overlay () {
            child = navigation_view
        };
        overlay.add_overlay (app_notification);

        titlebar = new Gtk.Grid () {
            visible = false
        };
        child = overlay;
        present ();

        var manager = Audience.Services.LibraryManager.get_instance ();

        manager.media_item_trashed.connect ((item) => {
            app_notification.title = _("Video '%s' Removed.").printf (item.title);

            /* we don't have access to trash when inside an flatpak sandbox
             * so we don't allow the user to restore in this case.
             */
            if (!is_sandboxed ()) {
                app_notification.set_default_action (_("Restore"));

                app_notification.default_action.disconnect (action_undo);
                app_notification.default_action.connect (action_undo);
            }

            app_notification.send_notification ();
        });

        library_page.show_episodes.connect ((item, setup_only) => {
            episodes_page.set_show (item);
            if (!setup_only) {
                navigation_view.push (episodes_page);
            }
        });

        navigation_view.notify["visible-page"].connect (() => {
            update_navigation ();
        });

        var playback_manager = PlaybackManager.get_default ();

        playback_manager.play_queue.items_changed.connect ((pos, removed, added) => {
            if (playback_manager.play_queue.get_n_items () == 1) {
                return;
            }

            app_notification.set_default_action (null);

            if (added == 1) {
                var title = Audience.get_title (playback_manager.play_queue.get_string (pos));
                app_notification.title = _("“%s” added to playlist").printf (title);
                app_notification.send_notification ();
            } else if (added > 1) {
                app_notification.title = ngettext ("%u item added to playlist", "%u items added to playlist", added).printf (added);
                app_notification.send_notification ();
            }
        });

        playback_manager.ended.connect (on_player_ended);

        var key_controller = new Gtk.EventControllerKey ();
        overlay.add_controller (key_controller);
        key_controller.key_released.connect (handle_key_press);

        var drop_target = new Gtk.DropTarget (typeof (Gdk.FileList), COPY);
        navigation_view.add_controller (drop_target);
        drop_target.drop.connect ((val) => {
            if (val.type () != typeof (Gdk.FileList)) {
                return false;
            }

            File[] files;
            var file_list = ((Gdk.FileList) val.get_boxed ()).get_files ();
            foreach (var file in file_list) {
                files += file;
            }

            open_files (files);

            return true;
        });
    }

    private void action_back () {
        navigation_view.pop ();
    }

    private void action_fullscreen () {
        if (fullscreened) {
            unfullscreen ();
        } else {
            fullscreen ();
        }
    }

    private void action_open_file () {
        run_open_file ();
    }

    private void action_quit () {
        destroy ();
    }

    private void action_search () {
        if (navigation_view.visible_page == library_page) {
            library_page.search ();
        } else if (navigation_view.visible_page == episodes_page) {
            episodes_page.search ();
        } else {
            Gdk.Display.get_default ().beep ();
        }
    }

    private void action_undo () {
        /* we don't have access to trash when inside an flatpak sandbox
         * so we don't allow the user to restore in this case.
         */
        if (!is_sandboxed ()) {
            Audience.Services.LibraryManager.get_instance ().undo_delete_item ();
        }
    }

    /** Returns true if the code parameter matches the keycode of the keyval parameter for
    * any keyboard group or level (in order to allow for non-QWERTY keyboards) **/
    public bool match_keycode (uint keyval, uint code) { //TODO: Test with non-QWERTY keyboard
        var display = Gdk.Display.get_default ();
        Gdk.KeymapKey [] keys;
        if (display.map_keyval (keyval, out keys)) {
            foreach (var key in keys) {
                if (code == key.keycode) {
                    return true;
                }
            }
        }

        return false;
    }

    public void handle_key_press (uint keyval, uint keycode, Gdk.ModifierType state) {
        if (keyval == Gdk.Key.Escape) {
            if (fullscreened) {
                unfullscreen ();
            } else {
                destroy ();
            }
        }

        if (navigation_view.visible_page == player_page) {
            if (match_keycode (Gdk.Key.space, keycode) || match_keycode (Gdk.Key.p, keycode)) {
                var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);
                ((SimpleAction) play_pause_action).activate (null);
            } else if (match_keycode (Gdk.Key.a, keycode)) {
                PlaybackManager.get_default ().next_audio ();
            } else if (match_keycode (Gdk.Key.s, keycode)) {
                PlaybackManager.get_default ().next_text ();
            }

            bool shift_pressed = SHIFT_MASK in state;
            switch (keyval) {
                case Gdk.Key.Down:
                    player_page.seek_jump_seconds (shift_pressed ? -5 : -60);
                    break;
                case Gdk.Key.Left:
                    player_page.seek_jump_seconds (shift_pressed ? -1 : -10);
                    break;
                case Gdk.Key.Right:
                    player_page.seek_jump_seconds (shift_pressed ? 1 : 10);
                    break;
                case Gdk.Key.Up:
                    player_page.seek_jump_seconds (shift_pressed ? 5 : 60);
                    break;
                case Gdk.Key.Page_Down:
                    player_page.seek_jump_seconds (-600); // 10 mins
                    break;
                case Gdk.Key.Page_Up:
                    player_page.seek_jump_seconds (600); // 10 mins
                    break;
                default:
                    break;
            }
        } else if (navigation_view.visible_page == welcome_page) {
            bool ctrl_pressed = CONTROL_MASK in state;
            if (match_keycode (Gdk.Key.p, keycode) || match_keycode (Gdk.Key.space, keycode)) {
                resume_last_videos ();
            } else if (ctrl_pressed && match_keycode (Gdk.Key.b, keycode)) {
                show_library ();
            }
        }
    }

    public void open_files (File[] files, bool clear_playlist_items = false, bool force_play = true) {
        if (clear_playlist_items) {
            PlaybackManager.get_default ().clear_playlist (false);
        }

        string[] videos = {};

        foreach (var file in files) {
            if (file.query_file_type (0) == FileType.DIRECTORY) {
                Audience.recurse_over_dir (file, (file_ret) => {
                    videos += file_ret.get_uri ();
                });
            } else {
                videos += file.get_uri ();
            }
        }

        PlaybackManager.get_default ().append_to_playlist (videos);

        if (force_play && videos.length > 0) {
            string videofile = videos [0];
            NavigationPage page = library_page.prepare_to_play (videofile);
            play_file (videofile, page);
        }
    }

    public void resume_last_videos () {
        if (settings.get_string ("current-video") != "") {
            play_file (settings.get_string ("current-video"), NavigationPage.WELCOME, false);
        } else {
            action_open_file ();
        }
    }

    public void show_library () {
        navigation_view.push (library_page);
    }

    public void run_open_file (bool clear_playlist = false, bool force_play = true) {
        var all_files_filter = new Gtk.FileFilter ();
        all_files_filter.set_filter_name (_("All files"));
        all_files_filter.add_pattern ("*");

        var video_filter = new Gtk.FileFilter ();
        video_filter.set_filter_name (_("Video files"));
        video_filter.add_mime_type ("video/*");

        var filters = new ListStore (typeof (Gtk.FileFilter));
        filters.append (video_filter);
        filters.append (all_files_filter);

        var file_dialog = new Gtk.FileDialog () {
            title = _("Open"),
            accept_label = _("_Open"),
            filters = filters,
            initial_folder = File.new_for_path (settings.get_string ("last-folder"))
        };

        file_dialog.open_multiple.begin (this, null, (obj, res) => {
            try {
                File[] files = {};

                var files_list = file_dialog.open_multiple.end (res);
                /* Do nothing when no files are selected.
                 * Gtk.FileDialog.open_multiple does not throw an error
                 * so handle this abnormal case by ourselves.
                 */
                uint num_files = files_list.get_n_items ();
                if (num_files < 1) {
                    return;
                }

                for (int i = 0; i < num_files; i++) {
                    files += (File)files_list.get_item (i);
                }

                open_files (files, clear_playlist, force_play);

                /* We already checked at least one file is selected so this won't fail,
                 * but guarantee safer access to the array in case
                 */
                return_if_fail (files.length > 0);
                /* Get the parent directory of the first File on behalf of opened files,
                 * because all of them should be in the same directory.
                 */
                var last_folder = files[0].get_parent ();
                settings.set_string ("last-folder", last_folder.get_path ());
            } catch (Error e) {
                warning ("Failed to open video files: %s", e.message);
            }
        });
    }

    private void on_player_ended () {
        navigation_view.pop ();
    }

    public void play_file (string uri, NavigationPage origin, bool from_beginning = true) {
        navigation_view.push (player_page);

        PlaybackManager.get_default ().play_file (uri, from_beginning);
    }

    private void update_navigation () {
        int64 position = PlaybackManager.get_default ().position;
        if (position > 0) {
            settings.set_int64 ("last-stopped", position);
        }

        var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);

        if (navigation_view.visible_page == player_page) {
            ((SimpleAction) play_pause_action).set_state (true);
        } else {
            ((SimpleAction) play_pause_action).set_state (false);
        }
    }
}
