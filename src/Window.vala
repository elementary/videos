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

public class Audience.Window : Gtk.Window {
    private Granite.Widgets.AlertView alert_view;
    private Granite.Widgets.Toast app_notification;
    private Granite.ModeSwitch autoqueue_next;
    private EpisodesPage episodes_page;
    private Gtk.HeaderBar header;
    private LibraryPage library_page;
    private Gtk.Stack main_stack;
    private NavigationButton navigation_button;
    private Gtk.SearchEntry search_entry;
    private WelcomePage welcome_page;
    private ZeitgeistManager zeitgeist_manager;

    public PlayerPage player_page { get; private set; }

    public enum NavigationPage { WELCOME, LIBRARY, EPISODES }

    // For better translation
    const string NAVIGATION_BUTTON_WELCOMESCREEN = N_("Back");
    const string NAVIGATION_BUTTON_LIBRARY = N_("Library");
    const string NAVIGATION_BUTTON_EPISODES = N_("Episodes");

    public signal void media_volumes_changed ();

    public Window () {

    }

    construct {
        zeitgeist_manager = new ZeitgeistManager ();
        window_position = Gtk.WindowPosition.CENTER;
        gravity = Gdk.Gravity.CENTER;
        set_default_size (1000, 680);

        header = new Gtk.HeaderBar ();
        header.set_show_close_button (true);
        header.get_style_context ().add_class ("compact");

        navigation_button = new NavigationButton ();
        navigation_button.clicked.connect (() => {
            navigate_back ();
        });

        header.pack_start (navigation_button);

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Videos");
        search_entry.valign = Gtk.Align.CENTER;
        search_entry.search_changed.connect (() => {
            if (main_stack.visible_child == episodes_page ) {
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
            search_entry.visible = true;
            if (search_entry.text != "" && !library_page.has_child ()) {
                search_entry.text = "";
            }
            if (library_page.last_filter != "") {
                search_entry.text = library_page.last_filter;
                library_page.last_filter = "";
            }
        });

        library_page.unmap.connect (() => {
            if (main_stack.visible_child != alert_view && main_stack.visible_child != episodes_page) {
                search_entry.visible = false;
            }
        });

        library_page.filter_result_changed.connect (has_result => {
            if (!has_result) {
                show_alert (_("No Results for “%s”").printf (search_entry.text), _("Try changing search terms."), "edit-find-symbolic");
            } else if (main_stack.visible_child != library_page ) {
                hide_alert ();
            }
        });

        library_page.show_episodes.connect ((item, setup_only) => {
            episodes_page.set_episodes_items (item.episodes);
            episodes_page.poster.pixbuf = item.poster.pixbuf;
            if (!setup_only) {
                navigation_button.label = _(NAVIGATION_BUTTON_LIBRARY);
                main_stack.set_visible_child (episodes_page);
                title = item.get_title ();
                search_entry.text = "";
                autoqueue_next.visible = true;
            }
        });

        welcome_page = new WelcomePage ();

        player_page = new PlayerPage ();
        player_page.ended.connect (on_player_ended);
        player_page.unfullscreen_clicked.connect (() => {
            unfullscreen ();
        });

        player_page.notify["playing"].connect (() => {
            set_keep_above (player_page.playing && settings.get_boolean ("stay-on-top"));
        });

        player_page.map.connect (() => {
            app_notification.visible = false;
        });
        player_page.unmap.connect (() => {
            app_notification.visible = true;
        });

        alert_view = new Granite.Widgets.AlertView ("", "", "");
        alert_view.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        alert_view.set_vexpand (true);
        alert_view.no_show_all = true;

        episodes_page = new EpisodesPage ();
        episodes_page.map.connect (() => {
            search_entry.visible = true;
        });

        main_stack = new Gtk.Stack ();
        main_stack.expand = true;
        main_stack.add_named (welcome_page, "welcome");
        main_stack.add_named (player_page, "player");
        main_stack.add_named (library_page, "library");
        main_stack.add_named (episodes_page, "episodes");
        main_stack.add_named (alert_view, "alert");
        main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

        app_notification = new Granite.Widgets.Toast ("");
        app_notification.set_default_action (_("Restore"));
        app_notification.default_action.connect (() => {
            library_page.manager.undo_delete_item ();
            if (main_stack.visible_child != episodes_page) {
                main_stack.set_visible_child (library_page);
            }
        });

        var overlay = new Gtk.Overlay ();
        overlay.add (main_stack);
        overlay.add_overlay (app_notification);

        add (overlay);
        show_all ();

        navigation_button.hide ();
        search_entry.visible = false;
        autoqueue_next.visible = false;
        main_stack.set_visible_child_full ("welcome", Gtk.StackTransitionType.NONE);

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
                if (player_page.fullscreened) {
                    unfullscreen ();
                } else {
                    fullscreen ();
                }
            }

            // right click
            if (event.button == Gdk.BUTTON_SECONDARY) {
                player_page.playing = !player_page.playing;
            }

            return base.button_press_event (event);
        });

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

                if (main_stack.get_visible_child () == player_page && currently_maximixed) {
                   fullscreen ();
                }
            }

            return false;
        });

        configure_event.connect (event => {
            player_page.hide_preview_popover ();
            player_page.bottom_bar.playlist_popover.popdown ();
            return Gdk.EVENT_PROPAGATE;
        });

        motion_notify_event.connect (event => {
            show_mouse_cursor ();
            return Gdk.EVENT_PROPAGATE;
        });
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
        bool ctrl_pressed = (e.state & Gdk.ModifierType.CONTROL_MASK) != 0;
        if ((e.state & Gdk.ModifierType.MOD1_MASK) != 0 && e.keyval == Gdk.Key.Left) {
            navigation_button.clicked ();
            return true;
        }

        if (main_stack.visible_child == player_page) {
            if (match_keycode (Gdk.Key.space, keycode)) {
                player_page.playing = !player_page.playing;
                return true;
            } else if (match_keycode (Gdk.Key.p, keycode)) {
                player_page.playing = !player_page.playing;
            } else if (match_keycode (Gdk.Key.a, keycode)) {
                player_page.next_audio ();
            } else if (match_keycode (Gdk.Key.s, keycode)) {
                player_page.next_text ();
            } else if (match_keycode (Gdk.Key.f, keycode)) {
                if (player_page.fullscreened) {
                    unfullscreen ();
                } else {
                    fullscreen ();
                }
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
        } else if (main_stack.visible_child == welcome_page) {
            if (match_keycode (Gdk.Key.p, keycode) || match_keycode (Gdk.Key.space, keycode)) {
                resume_last_videos ();
                return true;
            } else if (ctrl_pressed && match_keycode (Gdk.Key.o, keycode)) {
                run_open_file ();
                return true;
            } else if (ctrl_pressed && match_keycode (Gdk.Key.q, keycode)) {
                destroy ();
                return true;
            } else if (ctrl_pressed && match_keycode (Gdk.Key.b, keycode)) {
                show_library ();
                return true;
            }
        } else if (search_entry.visible) {
            if (ctrl_pressed && match_keycode (Gdk.Key.f, keycode)) {
                search_entry.grab_focus ();
            } else if (ctrl_pressed && match_keycode (Gdk.Key.z, keycode)) {
                library_page.manager.undo_delete_item ();
                app_notification.reveal_child = false;
            } else if (match_keycode (Gdk.Key.Escape, keycode)) {
                search_entry.text = "";
            } else if (!search_entry.is_focus && e.str.strip ().length > 0) {
                search_entry.grab_focus ();
            }
        }

        return base.key_press_event (e);
    }

    public void open_files (File[] files, bool clear_playlist_items = false, bool force_play = true) {
        if (clear_playlist_items) {
            clear_playlist ();
        }

        string[] videos = {};
        foreach (var file in files) {
            if (file.query_file_type (0) == FileType.DIRECTORY) {
                Audience.recurse_over_dir (file, (file_ret) => {
                    player_page.append_to_playlist (file);
                    videos += file_ret.get_uri ();
                });
            } else {
                player_page.append_to_playlist (file);
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
            run_open_file ();
        }
    }

    public void run_open_dvd () {
        read_first_disk.begin ();
    }

    public void show_library () {
        navigation_button.label = _(NAVIGATION_BUTTON_WELCOMESCREEN);
        navigation_button.show ();
        main_stack.visible_child = library_page;
        library_page.scrolled_window.grab_focus ();
    }

    public void add_to_playlist (string uri, bool preserve_playlist) {
        if (!preserve_playlist) {
            clear_playlist ();
        }

        player_page.append_to_playlist (File.new_for_uri (uri));
        settings.set_string ("current-video", uri);
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

    public bool is_privacy_mode_enabled () {
        var privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");
        bool privacy_mode = !privacy_settings.get_boolean ("remember-recent-files") || !privacy_settings.get_boolean ("remember-app-usage");

        if (privacy_mode) {
            return true;
        }

        return zeitgeist_manager.app_into_blacklist (GLib.Application.get_default ().application_id);
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
        navigate_back ();
        unfullscreen ();
    }

    public void play_file (string uri, NavigationPage origin, bool from_beginning = true) {
        search_entry.visible = false;
        navigation_button.visible = true;
        switch (origin) {
            default:
            case NavigationPage.WELCOME:
                navigation_button.label = _(NAVIGATION_BUTTON_WELCOMESCREEN);
                break;
            case NavigationPage.LIBRARY:
                navigation_button.label = _(NAVIGATION_BUTTON_LIBRARY);
                break;
            case NavigationPage.EPISODES:
                navigation_button.label = _(NAVIGATION_BUTTON_EPISODES);
                autoqueue_next.visible = true;
                break;
        }

        main_stack.set_visible_child_full ("player", Gtk.StackTransitionType.SLIDE_LEFT);
        player_page.play_file (uri, from_beginning);
        if (is_maximized) {
            fullscreen ();
        }

        if (settings.get_boolean ("stay-on-top") && !settings.get_boolean ("playback-wait")) {
            set_keep_above (true);
        }

        welcome_page.refresh ();
    }

    public void clear_playlist () {
        player_page.get_playlist_widget ().clear_items ();
    }

    public void append_to_playlist (File file) {
        player_page.append_to_playlist (file);
    }

    public void navigate_back () {
        double progress = player_page.get_progress ();
        if (progress > 0) {
            settings.set_double ("last-stopped", progress);
        }
        if (player_page.playing) {
            player_page.playing = false;
            player_page.reset_played_uri ();
        }
        title = _("Videos");
        get_window ().set_cursor (null);

        if (navigation_button.label == _(NAVIGATION_BUTTON_LIBRARY)) {
            navigation_button.label = _(NAVIGATION_BUTTON_WELCOMESCREEN);
            main_stack.set_visible_child_full ("library", Gtk.StackTransitionType.SLIDE_RIGHT);
            autoqueue_next.visible = false;
        } else if (navigation_button.label == _(NAVIGATION_BUTTON_EPISODES)) {
            navigation_button.label = _(NAVIGATION_BUTTON_LIBRARY);
            main_stack.set_visible_child_full ("episodes", Gtk.StackTransitionType.SLIDE_RIGHT);
            autoqueue_next.visible = true;
        } else {
            navigation_button.hide ();
            main_stack.set_visible_child (welcome_page);
            search_entry.visible = false;
            autoqueue_next.visible = false;
        }
        welcome_page.refresh ();
    }

    public void hide_alert () {
        alert_view.no_show_all = true;
        main_stack.set_visible_child_full ("library", Gtk.StackTransitionType.NONE);
        alert_view.hide ();
    }

    public void show_alert (string primary_text, string secondary_text, string icon_name) {
        alert_view.no_show_all = false;
        alert_view.show_all ();
        alert_view.title = primary_text;
        alert_view.description = secondary_text;
        alert_view.icon_name = icon_name;
        main_stack.set_visible_child_full ("alert", Gtk.StackTransitionType.NONE);
    }

    public void set_app_notification (string text) {
        app_notification.title = text;
        app_notification.send_notification ();
    }

    public Gtk.Widget get_visible_child () {
        return main_stack.visible_child;
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
