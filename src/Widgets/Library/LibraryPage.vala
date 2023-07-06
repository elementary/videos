/*-
 * Copyright 2016-2021 elementary, Inc. (https://elementary.io)
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
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 *
 */

public class Audience.LibraryPage : Gtk.Box {
    public signal void show_episodes (Audience.LibraryItem item, bool setup_only = false);

    public bool has_items {
        get {
            return view_movies.get_children ().length () > 0;
        }
    }

    private Audience.Services.LibraryManager manager;
    private Gtk.SearchEntry search_entry;
    private Granite.Widgets.AlertView alert_view;
    private Gtk.ScrolledWindow scrolled_window;
    private Gtk.FlowBox view_movies;
    private Gtk.Stack stack;
    private bool posters_initialized = false;

    public static LibraryPage instance = null;
    public static LibraryPage get_instance () {
        if (instance == null) {
            instance = new LibraryPage ();
        }
        return instance;
    }

    construct {
        var navigation_button = new Gtk.Button.with_label (_("Back")) {
            valign = Gtk.Align.CENTER
        };
        navigation_button.get_style_context ().add_class (Granite.STYLE_CLASS_BACK_BUTTON);

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Search Videos"),
            valign = CENTER
        };

        var autoqueue_next = new Granite.ModeSwitch.from_icon_name (
            "media-playlist-repeat-one-symbolic",
            "media-playlist-consecutive-symbolic"
        ) {
            primary_icon_tooltip_text = _("Play one video"),
            secondary_icon_tooltip_text = _("Automatically play next videos"),
            valign = Gtk.Align.CENTER
        };
        settings.bind ("autoqueue-next", autoqueue_next, "active", SettingsBindFlags.DEFAULT);

        var header_bar = new Hdy.HeaderBar () {
            show_close_button = true,
            title = _("Library")
        };
        header_bar.pack_start (navigation_button);
        header_bar.pack_end (search_entry);
        header_bar.pack_end (autoqueue_next);
        header_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        view_movies = new Gtk.FlowBox () {
            column_spacing = 12,
            row_spacing = 12,
            homogeneous = true,
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 24,
            margin_end = 24,
            selection_mode = Gtk.SelectionMode.NONE,
            valign = Gtk.Align.START
        };

        scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hexpand = true,
            vexpand = true,
            child = view_movies
        };

        alert_view = new Granite.Widgets.AlertView (
            "",
            _("Try changing search terms."),
            "edit-find-symbolic"
        );

        stack = new Gtk.Stack ();
        stack.add (scrolled_window);
        stack.add (alert_view);

        orientation = VERTICAL;
        add (header_bar);
        add (stack);

        view_movies.child_activated.connect (play_video);

        manager = Audience.Services.LibraryManager.get_instance ();
        manager.video_file_detected.connect (add_item);
        manager.video_file_deleted.connect (remove_item_from_path);

        manager.begin_scan ();

        map.connect (() => {
            if (!posters_initialized) {
                posters_initialized = true;
                poster_initialisation.begin ();
            }
            if (search_entry.text != "" && !has_child ()) {
                search_entry.text = "";
            }
        });

        view_movies.set_sort_func (video_sort_func);
        view_movies.set_filter_func (video_filter_func);

        navigation_button.clicked.connect (() => {
            ((Hdy.Deck)get_ancestor (typeof (Hdy.Deck))).navigate (Hdy.NavigationDirection.BACK);
        });

        search_entry.search_changed.connect (() => filter ());

        search_entry.key_press_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                search_entry.text = "";
            }

            return Gdk.EVENT_PROPAGATE;
        });
    }

    public void search () {
        search_entry.grab_focus ();
    }

    private void play_video (Gtk.FlowBoxChild item) {
        var selected = (item as Audience.LibraryItem);

        if (selected.episodes.size == 1) {
            string uri = selected.episodes.first ().video_file.get_uri ();
            bool same_video = uri == settings.get_string ("current-video");
            bool playback_complete = settings.get_double ("last-stopped") == 0.0;
            bool from_beginning = !same_video || playback_complete;

            if (from_beginning) {
                PlaybackManager.get_default ().clear_playlist ();
            }

            PlaybackManager.get_default ().append_to_playlist (File.new_for_uri (uri));

            var window = (Audience.Window) ((Gtk.Application) Application.get_default ()).active_window;
            window.play_file (uri, Window.NavigationPage.LIBRARY, from_beginning);
        } else {
            show_episodes (selected);
        }
    }

    public void add_item (Audience.Objects.Video video) {
        foreach (unowned var child in view_movies.get_children ()) {
            if (video.container != null && ((LibraryItem) child).episodes.first ().container == video.container) {
                ((LibraryItem) child).add_episode (video);
                return;
            }
        }

        var new_container = new Audience.LibraryItem (video, LibraryItemStyle.THUMBNAIL);
        view_movies.add (new_container);

        if (posters_initialized) {
            video.initialize_poster.begin ();
            new_container.show_all ();
        }
    }

    private async void remove_item (LibraryItem item) {
        foreach (var video in item.episodes) {
            manager.clear_cache.begin (video.poster_cache_file);
        }

        item.dispose ();
    }

    private async void remove_item_from_path (string path ) {
        foreach (unowned var child in view_movies.get_children ()) {
            if (((LibraryItem)(child)).episodes.size == 0 ||
                ((LibraryItem)(child)).episodes.first ().video_file.get_path ().has_prefix (path)) {

                remove_item.begin (child as LibraryItem);
            }
        }

        var deck = (Hdy.Deck) get_ancestor (typeof (Hdy.Deck));
        if (deck.visible_child == this && view_movies.get_children ().length () == 0) {
            deck.navigate (Hdy.NavigationDirection.BACK);
        }
    }

    private async void poster_initialisation () {
        foreach (var child in view_movies.get_children ()) {
            var first_episode = ((LibraryItem)(child)).episodes.first ();
            if (!first_episode.poster_initialized) {
                first_episode.initialize_poster.begin ();
            }
        }
    }

    private bool video_filter_func (Gtk.FlowBoxChild child) {
        if (search_entry.text.length == 0) {
            return true;
        }

        string[] filter_elements = search_entry.text.split (" ");
        var video_title = ((LibraryItem)(child)).get_title ();

        foreach (string filter_element in filter_elements) {
            if (!video_title.down ().contains (filter_element.down ())) {
                return false;
            }
        }
        return true;
    }

    private int video_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
        var item1 = (LibraryItem)child1;
        var item2 = (LibraryItem)child2;
        if (item1 != null && item2 != null) {
            return item1.get_title ().collate (item2.get_title ());

        }
        return 0;
    }

    public void filter () {
        view_movies.invalidate_filter ();

        if (!has_child ()) {
            stack.visible_child = alert_view;
            alert_view.title = _("No Results for “%s”").printf (search_entry.text);
        } else {
            stack.visible_child = scrolled_window;
        }
    }

    public bool has_child () {
        if (view_movies.get_children ().length () > 0) {
           foreach (unowned Gtk.Widget child in view_movies.get_children ()) {
               if (child.get_child_visible ()) {
                   return true;
               }
            }
        }
        return false;
    }

    public Audience.Window.NavigationPage prepare_to_play (string file) {
        if (!File.new_for_uri (file).has_prefix (File.new_for_path (Environment.get_user_special_dir (UserDirectory.VIDEOS)))) {
            return Window.NavigationPage.WELCOME;
        }

        foreach (var child in view_movies.get_children ()) {
            var item = child as LibraryItem;
            var episodes = item.episodes;
            foreach (var episode in episodes) {
                string ep_file = episode.video_file.get_uri ();
                if (ep_file == file) {
                    if (episodes.size > 1) {
                        var first_episode = episodes.first ();
                        if (!first_episode.poster_initialized) {
                            first_episode.initialize_poster.begin ();
                        }
                        show_episodes (item, true);
                        return Window.NavigationPage.EPISODES;
                    } else {
                        return Window.NavigationPage.LIBRARY;
                    }
                }
            }
        }
        return Window.NavigationPage.WELCOME;
    }
}
