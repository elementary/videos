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
            return items.get_n_items () > 0;
        }
    }

    private ListStore items;
    private Audience.Services.LibraryManager manager;
    private Gtk.SearchEntry search_entry;
    private Granite.Placeholder alert_view;
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
        items = new ListStore (typeof (LibraryItem));

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Search Videos"),
            valign = CENTER
        };

        var header_bar = new HeaderBar ();
        header_bar.header_bar.pack_end (search_entry);

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
        view_movies.set_sort_func (video_sort_func);
        view_movies.set_filter_func (video_filter_func);
        view_movies.bind_model (items, (item) => {
            return (LibraryItem)item;
        });

        scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            child = view_movies
        };

        alert_view = new Granite.Placeholder ("") {
            description = _("Try changing search terms."),
            icon = new ThemedIcon ("edit-find-symbolic")
        };

        stack = new Gtk.Stack ();
        stack.add_child (scrolled_window);
        stack.add_child (alert_view);

        orientation = VERTICAL;
        append (header_bar);
        append (stack);

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

        search_entry.search_changed.connect (() => filter ());

        var search_entry_key_controller = new Gtk.EventControllerKey ();
        search_entry.add_controller (search_entry_key_controller);
        search_entry_key_controller.key_pressed.connect ((keyval) => {
            if (keyval == Gdk.Key.Escape) {
                search_entry.text = "";
                return true;
            }
            return false;
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
            bool playback_complete = settings.get_int64 ("last-stopped") == 0.0;
            bool from_beginning = !same_video || playback_complete;

            if (from_beginning) {
                PlaybackManager.get_default ().clear_playlist ();
            }

            PlaybackManager.get_default ().append_to_playlist ({ uri });

            var window = (Audience.Window) ((Gtk.Application) Application.get_default ()).active_window;
            window.play_file (uri, Window.NavigationPage.LIBRARY, from_beginning);
        } else {
            show_episodes (selected);
        }
    }

    public void add_item (Audience.Objects.Video video) {
        for (int i = 0; i < items.get_n_items (); i++) {
            var item = (LibraryItem)items.get_item (i);
            if (video.container != "" && item.episodes.first ().container == video.container) {
                item.add_episode (video);
                view_movies.invalidate_sort ();
                return;
            }
        }

        var new_container = new Audience.LibraryItem (video, LibraryItemStyle.THUMBNAIL);
        items.append (new_container);

        if (posters_initialized) {
            video.initialize_poster.begin ();
        }
    }

    private async void remove_item (LibraryItem item) {
        foreach (var video in item.episodes) {
            manager.clear_cache.begin (video.poster_cache_file);
        }

        uint pos;
        items.find (item, out pos);
        items.remove (pos);
    }

    private async void remove_item_from_path (string path ) {
        for (int i = 0; i < items.get_n_items (); i++) {
            var item = (LibraryItem)items.get_item (i);
            if (item.episodes.size == 0 || item.episodes.first ().video_file.get_path ().has_prefix (path)) {
                remove_item.begin (item);
            }
        }

        var leaflet = (Adw.Leaflet) get_ancestor (typeof (Adw.Leaflet));
        if (leaflet.visible_child == this && items.get_n_items () == 0) {
            leaflet.navigate (Adw.NavigationDirection.BACK);
        }
    }

    private async void poster_initialisation () {
        for (int i = 0; i < items.get_n_items (); i++) {
            var item = (LibraryItem)items.get_item (i);
            var first_episode = item.episodes.first ();
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

    private int video_sort_func (Object item1, Object item2) {
        var library_item1 = (LibraryItem)item1;
        var library_item2 = (LibraryItem)item2;
        if (library_item1 != null && library_item2 != null) {
            return library_item1.get_title ().collate (library_item2.get_title ());
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
        for (int i = 0; i < items.get_n_items (); i++) {
            var item = (LibraryItem)items.get_item (i);
            if (item.get_child_visible ()) {
                return true;
            }
        }

        return false;
    }

    public Audience.Window.NavigationPage prepare_to_play (string file) {
        if (!File.new_for_uri (file).has_prefix (File.new_for_path (Environment.get_user_special_dir (UserDirectory.VIDEOS)))) {
            return Window.NavigationPage.WELCOME;
        }

        for (int i = 0; i < items.get_n_items (); i++) {
            var item = (LibraryItem)items.get_item (i);
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
