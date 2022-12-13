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
    private Hdy.Deck deck;
    private Granite.Widgets.Toast app_notification;
    private Granite.ModeSwitch autoqueue_next;
    private EpisodesPage episodes_page;
    private Gtk.HeaderBar header;
    private LibraryPage library_page;
    private Gtk.Button navigation_button;
    private Gtk.SearchEntry search_entry;
    private WelcomePage welcome_page;
    private PlayerPage player_page;

    public enum NavigationPage { WELCOME, LIBRARY, EPISODES }

    // For better translation
    const string NAVIGATION_BUTTON_WELCOMESCREEN = N_("Back");
    const string NAVIGATION_BUTTON_LIBRARY = N_("Library");
    const string NAVIGATION_BUTTON_EPISODES = N_("Episodes");

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
        action_accelerators[ACTION_BACK] = "<Alt>Left";
        action_accelerators[ACTION_BACK] = "Back";
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

        window_position = Gtk.WindowPosition.CENTER;
        gravity = Gdk.Gravity.CENTER;
        set_default_size (1000, 680);

        header = new Gtk.HeaderBar ();
        header.set_show_close_button (true);
        header.get_style_context ().add_class ("compact");

        navigation_button = new Gtk.Button.with_label (NAVIGATION_BUTTON_WELCOMESCREEN) {
            valign = Gtk.Align.CENTER
        };
        navigation_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

        navigation_button.clicked.connect (() => {
            deck.navigate (Hdy.NavigationDirection.BACK);
        });

        header.pack_start (navigation_button);

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Videos");
        search_entry.valign = Gtk.Align.CENTER;
        search_entry.search_changed.connect (() => {
            if (deck.visible_child == episodes_page ) {
                episodes_page.filter (search_entry.text);
            } else {
                library_page.filter (search_entry.text);
            }
        });

        header.pack_end (search_entry);

        autoqueue_next = new Granite.ModeSwitch.from_icon_name ("media-playlist-repeat-one-symbolic", "media-playlist-consecutive-symbolic");
        autoqueue_next.primary_icon_tooltip_text = _("Play one video");
        autoqueue_next.secondary_icon_tooltip_text = _("Automatically play next videos");
        autoqueue_next.valign = Gtk.Align.CENTER;
        settings.bind ("autoqueue-next", autoqueue_next, "active", SettingsBindFlags.DEFAULT);

        header.pack_end (autoqueue_next);

        set_titlebar (header);

        library_page = LibraryPage.get_instance ();
        library_page.map.connect (() => {
            if (search_entry.text != "" && !library_page.has_child ()) {
                search_entry.text = "";
            }
            if (library_page.last_filter != "") {
                search_entry.text = library_page.last_filter;
                library_page.last_filter = "";
            }
        });

        library_page.show_episodes.connect ((item, setup_only) => {
            episodes_page.set_episodes_items (item.episodes);
            episodes_page.poster.pixbuf = item.poster.pixbuf;
            if (!setup_only) {
                episodes_page.show_all ();

                deck.add (episodes_page);
                deck.visible_child = episodes_page;

                title = item.get_title ();
                search_entry.text = "";
                autoqueue_next.visible = true;
            }
        });

        welcome_page = new WelcomePage ();

        player_page = new PlayerPage ();

        player_page.map.connect (() => {
            app_notification.visible = false;
        });
        player_page.unmap.connect (() => {
            app_notification.visible = true;
        });

        episodes_page = new EpisodesPage ();

        deck = new Hdy.Deck () {
            can_swipe_back = true
        };
        deck.add (welcome_page);

        var manager = Audience.Services.LibraryManager.get_instance ();
        app_notification = new Granite.Widgets.Toast ("");

        /* we don't have access to trash when inside an flatpak sandbox
         * so we don't allow the user to restore in this case.
         */
        if (!is_sandboxed ()) {
            app_notification.set_default_action (_("Restore"));

            app_notification.default_action.connect (() => {
                action_undo ();
            });
        }

        var overlay = new Gtk.Overlay ();
        overlay.add (deck);
        overlay.add_overlay (app_notification);

        add (overlay);
        show_all ();

        navigation_button.hide ();
        search_entry.visible = false;
        autoqueue_next.visible = false;

        manager.video_moved_to_trash.connect ((video) => {
            app_notification.title = _("Video '%s' Removed.").printf (Path.get_basename (video));
            app_notification.send_notification ();
        });

        deck.notify["visible-child"].connect (() => {
            update_navigation ();
        });

        deck.notify["transition-running"].connect (() => {
            update_navigation ();
        });

        Gtk.TargetEntry uris = {"text/uri-list", 0, 0};
        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, {uris}, Gdk.DragAction.MOVE);
        drag_data_received.connect ((ctx, x, y, sel, info, time) => {
            var files = new Array<File> ();
            foreach (var uri in sel.get_uris ()) {
                var file = File.new_for_uri (uri);
                files.append_val (file);
            }

            open_files (files.data, false, false);
        });

        player_page.button_press_event.connect ((event) => {
            // double left click
            if (event.button == Gdk.BUTTON_PRIMARY && event.type == Gdk.EventType.2BUTTON_PRESS) {
                action_fullscreen ();
            }

            // right click
            if (event.button == Gdk.BUTTON_SECONDARY) {
                var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);
                ((SimpleAction) play_pause_action).activate (null);
            }

            return base.button_press_event (event);
        });

        search_entry.key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                search_entry.text = "";
            }

            return Gdk.EVENT_PROPAGATE;
        });

        var playback_manager = PlaybackManager.get_default ();

        //playlist wants us to open a file
        playback_manager.play.connect ((file) => {
            open_files ({ File.new_for_uri (file.get_uri ()) });
        });

        playback_manager.ended.connect (on_player_ended);

        window_state_event.connect ((e) => {
            if (Gdk.WindowState.FULLSCREEN in e.changed_mask) {
                player_page.fullscreened = Gdk.WindowState.FULLSCREEN in e.new_window_state;
                header.visible = !player_page.fullscreened;

                if (!player_page.fullscreened) {
                    unmaximize ();
                }
            }

            if (Gdk.WindowState.MAXIMIZED in e.changed_mask) {
                bool currently_maximixed = Gdk.WindowState.MAXIMIZED in e.new_window_state;

                if (deck.visible_child == player_page && currently_maximixed) {
                   fullscreen ();
                }
            }

            return false;
        });

        configure_event.connect (event => {
            player_page.hide_popovers ();
            return Gdk.EVENT_PROPAGATE;
        });

        motion_notify_event.connect (event => {
            show_mouse_cursor ();
            return Gdk.EVENT_PROPAGATE;
        });
    }

    private void action_back () {
        deck.navigate (Hdy.NavigationDirection.BACK);
    }

    private void action_fullscreen () {
        if (deck.visible_child == player_page) {
            if (player_page.fullscreened) {
                unfullscreen ();
            } else {
                fullscreen ();
            }
        }
    }

    private void action_open_file () {
        run_open_file ();
    }

    private void action_quit () {
        destroy ();
    }

    private void action_search () {
        if (search_entry.visible) {
            search_entry.grab_focus ();
        } else {
            Gdk.beep ();
        }
    }

    private void action_undo () {
        /* we don't have access to trash when inside an flatpak sandbox
         * so we don't allow the user to restore in this case.
         */
        if (!is_sandboxed ()) {
            Audience.Services.LibraryManager.get_instance ().undo_delete_item ();
            app_notification.reveal_child = false;

            if (deck.visible_child != episodes_page) {
                deck.visible_child = library_page;
            }
        }
    }

    /** Returns true if the code parameter matches the keycode of the keyval parameter for
    * any keyboard group or level (in order to allow for non-QWERTY keyboards) **/
#if VALA_0_42
    public bool match_keycode (uint keyval, uint code) {
#else
    public bool match_keycode (int keyval, uint code) {
#endif
        Gdk.KeymapKey [] keys;
        Gdk.Keymap keymap = Gdk.Keymap.get_for_display (Gdk.Display.get_default ());
        if (keymap.get_entries_for_keyval (keyval, out keys)) {
            foreach (var key in keys) {
                if (code == key.keycode) {
                    return true;
                }
            }
        }

        return false;
    }

    public override bool key_press_event (Gdk.EventKey e) {
        uint keycode = e.hardware_keycode;

        if (deck.visible_child == player_page) {
            if (match_keycode (Gdk.Key.space, keycode)) {
                var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);
                ((SimpleAction) play_pause_action).activate (null);
                return true;
            } else if (match_keycode (Gdk.Key.p, keycode)) {
                var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);
                ((SimpleAction) play_pause_action).activate (null);
            } else if (match_keycode (Gdk.Key.a, keycode)) {
                PlaybackManager.get_default ().next_audio ();
            } else if (match_keycode (Gdk.Key.s, keycode)) {
                PlaybackManager.get_default ().next_text ();
            }

            bool shift_pressed = Gdk.ModifierType.SHIFT_MASK in e.state;
            switch (e.keyval) {
                case Gdk.Key.Escape:
                    if (player_page.fullscreened) {
                        unfullscreen ();
                    } else {
                        destroy ();
                    }
                    return true;
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
        } else if (deck.visible_child == welcome_page) {
            bool ctrl_pressed = (e.state & Gdk.ModifierType.CONTROL_MASK) != 0;
            if (match_keycode (Gdk.Key.p, keycode) || match_keycode (Gdk.Key.space, keycode)) {
                resume_last_videos ();
                return true;
            } else if (ctrl_pressed && match_keycode (Gdk.Key.b, keycode)) {
                show_library ();
                return true;
            }
        }

        return base.key_press_event (e);
    }

    public void open_files (File[] files, bool clear_playlist_items = false, bool force_play = true) {
        if (clear_playlist_items) {
            PlaybackManager.get_default ().clear_playlist (false);
        }

        string[] videos = {};
        foreach (var file in files) {
            if (file.query_file_type (0) == FileType.DIRECTORY) {
                Audience.recurse_over_dir (file, (file_ret) => {
                    PlaybackManager.get_default ().append_to_playlist (file);
                    videos += file_ret.get_uri ();
                });
            } else {
                PlaybackManager.get_default ().append_to_playlist (file);
                videos += file.get_uri ();
            }
        }

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

    public void run_open_dvd () {
        read_first_disk.begin ();
    }

    public void show_library () {
        navigation_button.label = _(NAVIGATION_BUTTON_WELCOMESCREEN);
        navigation_button.show ();

        library_page.show_all ();

        deck.add (library_page);
        deck.visible_child = library_page;
    }

    public void run_open_file (bool clear_playlist = false, bool force_play = true) {
        var all_files_filter = new Gtk.FileFilter ();
        all_files_filter.set_filter_name (_("All files"));
        all_files_filter.add_pattern ("*");

        var video_filter = new Gtk.FileFilter ();
        video_filter.set_filter_name (_("Video files"));
        video_filter.add_mime_type ("video/*");

        var file = new Gtk.FileChooserNative (
            _("Open"),
            this,
            Gtk.FileChooserAction.OPEN,
            _("_Open"),
            _("_Cancel")
        );
        file.select_multiple = true;
        file.set_current_folder (settings.get_string ("last-folder"));
        file.add_filter (video_filter);
        file.add_filter (all_files_filter);

        if (file.run () == Gtk.ResponseType.ACCEPT) {
            File[] files = {};
            foreach (File item in file.get_files ()) {
                files += item;
            }

            open_files (files, clear_playlist, force_play);
            settings.set_string ("last-folder", file.get_current_folder ());
        }

        file.destroy ();
    }

    private async void read_first_disk () {
        var disk_manager = DiskManager.get_default ();
        if (disk_manager.get_volumes ().is_empty) {
            return;
        }

        var volume = disk_manager.get_volumes ().first ();
        if (volume.can_mount () == true && volume.get_mount ().can_unmount () == false) {
            try {
                yield volume.mount (MountMountFlags.NONE, null);
            } catch (Error e) {
                critical (e.message);
            }
        }

        var root = volume.get_mount ().get_default_location ();
        play_file (root.get_uri ().replace ("file:///", "dvd:///"), NavigationPage.WELCOME);
    }

    private void on_player_ended () {
        deck.navigate (Hdy.NavigationDirection.BACK);
        unfullscreen ();
    }

    public void play_file (string uri, NavigationPage origin, bool from_beginning = true) {
        player_page.show_all ();

        deck.add (player_page);
        deck.visible_child = player_page;

        player_page.play_file (uri, from_beginning);
        if (is_maximized) {
            fullscreen ();
        }
    }

    private void update_navigation () {
        double progress = PlaybackManager.get_default ().get_progress ();
        if (progress > 0) {
            settings.set_double ("last-stopped", progress);
        }

        var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);
        ((SimpleAction) play_pause_action).set_state (false);

        if (!deck.transition_running) {
            /* Changing the player_page playing properties triggers a number of signals/bindings and
             * pipeline needs time to react so wrap subsequent code in an Idle loop.
             */
            Idle.add (() => {
                get_window ().set_cursor (null);

                if (deck.visible_child == welcome_page) {
                    title = _("Videos");
                    search_entry.visible = false;
                } else if (deck.visible_child == library_page) {
                    title = _("Library");
                    search_entry.visible = true;
                } else if (deck.visible_child == episodes_page) {
                    search_entry.visible = true;
                } else if (deck.visible_child == player_page) {
                    search_entry.visible = false;
                    navigation_button.visible = true;

                    ((SimpleAction) play_pause_action).set_state (true);
                }

                var previous_child = deck.get_adjacent_child (Hdy.NavigationDirection.BACK);
                if (previous_child == welcome_page) {
                    navigation_button.label = _(NAVIGATION_BUTTON_WELCOMESCREEN);
                    autoqueue_next.visible = false;
                } else if (previous_child == library_page) {
                    navigation_button.label = _(NAVIGATION_BUTTON_LIBRARY);
                    autoqueue_next.visible = true;
                } else if (previous_child == episodes_page) {
                    navigation_button.label = _(NAVIGATION_BUTTON_EPISODES);
                    autoqueue_next.visible = true;
                } else {
                    navigation_button.hide ();
                    search_entry.visible = false;
                    autoqueue_next.visible = false;
                }

                var next_child = deck.get_adjacent_child (Hdy.NavigationDirection.FORWARD);
                if (next_child != null) {
                    deck.remove (next_child);
                }

                return Source.REMOVE;
            });
        }
    }

    public void hide_mouse_cursor () {
        var cursor = new Gdk.Cursor.for_display (get_window ().get_display (), Gdk.CursorType.BLANK_CURSOR);
        get_window ().set_cursor (cursor);
    }

    public void show_mouse_cursor () {
        get_window ().set_cursor (null);
    }

    public bool autoqueue_next_active () {
        return autoqueue_next.active;
    }
}
