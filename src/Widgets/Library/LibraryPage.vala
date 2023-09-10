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
    public signal void show_episodes (Objects.MediaItem item, bool setup_only = false);

    public bool has_items {
        get {
            return view_movies.model.get_n_items () > 0;
        }
    }

    private Audience.Services.LibraryManager manager;
    private Gtk.SearchEntry search_entry;
    private Granite.Placeholder alert_view;
    private Gtk.ScrolledWindow scrolled_window;
    private Gtk.GridView view_movies;
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

        var header_bar = new Gtk.HeaderBar () {
            show_title_buttons = true,
        };
        header_bar.pack_start (navigation_button);
        header_bar.pack_end (search_entry);
        header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        var filter_model = new Gtk.FilterListModel (Services.LibraryManager.get_instance ().library_items, new Gtk.CustomFilter (video_filter_func));
        var selection_model = new Gtk.NoSelection (filter_model);

        var factory = new Gtk.SignalListItemFactory ();

        view_movies = new Gtk.GridView (selection_model, factory) {
            // column_spacing = 12,
            // row_spacing = 12,
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 24,
            margin_end = 24,
            single_click_activate = true,
            valign = Gtk.Align.START
        };
        view_movies.add_css_class (Granite.STYLE_CLASS_BACKGROUND);

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

        factory.setup.connect ((obj) => {
            var item = (Gtk.ListItem) obj;
            item.child = new LibraryItem (THUMBNAIL);
        });

        factory.bind.connect ((obj) => {
            var item = (Gtk.ListItem) obj;
            ((LibraryItem) item.child).bind ((Objects.MediaItem) item.item);
        });

        view_movies.activate.connect (play_video);

        manager = Audience.Services.LibraryManager.get_instance ();

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

        navigation_button.clicked.connect (() => {
            ((Adw.Leaflet)get_ancestor (typeof (Adw.Leaflet))).navigate (Adw.NavigationDirection.BACK);
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

    private void play_video (uint position) {
        var selected = (Objects.MediaItem) view_movies.model.get_item (position);

        if (selected.children.get_n_items () == 0) {
            string uri = selected.uri;
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

    private async void poster_initialisation () {
        // for (int i = 0; i < items.get_n_items (); i++) {
        //     var item = (LibraryItem)items.get_item (i);
        //     var first_episode = item.episodes.first ();
        //     if (!first_episode.poster_initialized) {
        //         first_episode.initialize_poster.begin ();
        //     }
        // }
    }

    private bool video_filter_func (Object obj) {
        if (search_entry.text.length == 0) {
            return true;
        }

        string[] filter_elements = search_entry.text.split (" ");
        var video_title = ((Objects.MediaItem) obj).title;

        foreach (string filter_element in filter_elements) {
            if (!video_title.down ().contains (filter_element.down ())) {
                return false;
            }
        }
        return true;
    }

    public void filter () {
        manager.library_items.items_changed (0, manager.library_items.get_n_items (), manager.library_items.get_n_items ());

        if (view_movies.model.get_n_items () == 0) {
            stack.visible_child = alert_view;
            alert_view.title = _("No Results for “%s”").printf (search_entry.text);
        } else {
            stack.visible_child = scrolled_window;
        }
    }

    public bool has_child () {
        return view_movies.model.get_n_items () > 0;
    }

    public Audience.Window.NavigationPage prepare_to_play (string file) {
        if (!File.new_for_uri (file).has_prefix (File.new_for_path (Environment.get_user_special_dir (UserDirectory.VIDEOS)))) {
            return Window.NavigationPage.WELCOME;
        }

        for (int i = 0; i < manager.library_items.get_n_items (); i++) {
            var item = (Objects.MediaItem) manager.library_items.get_item (i);

            if (item.uri != null && item.uri == file) {
                return Window.NavigationPage.LIBRARY;
            }

            if (item.children.get_n_items () > 0) {
                for (int j = 0; j < item.children.get_n_items (); j++) {
                    var episode = (Objects.MediaItem) item.children.get_item (j);
                    if (episode.uri == file) {
                        show_episodes (item, true);
                        return Window.NavigationPage.EPISODES;
                    }
                }
            }
        }

        return Window.NavigationPage.WELCOME;
    }
}
