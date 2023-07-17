/*-
 * Copyright 2016-2021 elementary, Inc.
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

public class Audience.EpisodesPage : Gtk.Box {
    public Gtk.Picture poster { get; private set; }

    private ListStore items;
    private Gtk.SearchEntry search_entry;
    private Gtk.HeaderBar header_bar;
    private Gtk.FlowBox view_episodes;
    private Granite.Placeholder alert_view;

    private Objects.Video poster_source;

    construct {
        items = new ListStore (typeof (LibraryItem));
        poster_source = null;

        var navigation_button = new Gtk.Button.with_label (_("Library")) {
            valign = Gtk.Align.CENTER
        };
        navigation_button.add_css_class (Granite.STYLE_CLASS_BACK_BUTTON);

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

        header_bar = new Gtk.HeaderBar () {
            show_title_buttons = true
        };
        header_bar.pack_start (navigation_button);
        header_bar.pack_end (search_entry);
        header_bar.pack_end (autoqueue_next);
        header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        poster = new Gtk.Picture () {
            height_request = Audience.Services.POSTER_HEIGHT,
            width_request = Audience.Services.POSTER_WIDTH,
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 24,
            margin_end = 0,
            valign = Gtk.Align.START
        };
        poster.add_css_class (Granite.STYLE_CLASS_CARD);

        view_episodes = new Gtk.FlowBox () {
            homogeneous = true,
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 24,
            margin_end = 24,
            max_children_per_line = 1,
            selection_mode = Gtk.SelectionMode.NONE,
            valign = Gtk.Align.START
        };
        view_episodes.set_filter_func (episodes_filter_func);
        view_episodes.bind_model (items, (item) => {
            return (LibraryItem)item;
        });

        var scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            child = view_episodes
        };

        alert_view = new Granite.Placeholder ("") {
            description = _("Try changing search terms."),
            icon = new ThemedIcon ("edit-find-symbolic"),
            visible = false
        };

        var grid = new Gtk.Grid () {
            hexpand = true,
            vexpand = true
        };
        grid.attach (poster, 0, 1);
        grid.attach (scrolled_window, 1, 1);
        grid.attach (alert_view, 1, 1);

        orientation = VERTICAL;
        append (header_bar);
        append (grid);

        navigation_button.clicked.connect (() => {
            ((Adw.Leaflet)get_ancestor (typeof (Adw.Leaflet))).navigate (Adw.NavigationDirection.BACK);
        });

        view_episodes.child_activated.connect (play_video);

        var manager = Audience.Services.LibraryManager.get_instance ();
        manager.video_file_deleted.connect (remove_item_from_path);
        manager.video_file_detected.connect (add_item);

        search_entry.search_changed.connect (filter);

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

    public void set_episodes_items (Gee.ArrayList<Audience.Objects.Video> episodes) {
        items.remove_all ();

        foreach (Audience.Objects.Video episode in episodes) {
            items.insert_sorted (new Audience.LibraryItem (episode, LibraryItemStyle.ROW), episode_sort_func);
        }

        if (poster_source != null) {
            poster_source.poster_changed.disconnect (update_poster);
        }
        poster_source = episodes.first ();
        update_poster (poster_source);
        poster_source.poster_changed.connect (update_poster);

        search_entry.text = "";
    }

    private void update_poster (Objects.Video episode) {
        poster.set_pixbuf (episode.poster);
    }

    private void play_video (Gtk.FlowBoxChild item) {
        var selected = (item as Audience.LibraryItem);
        var video = selected.episodes.first ();
        if (video.video_file.query_exists ()) {
            string uri = video.video_file.get_uri ();
            bool from_beginning = uri != settings.get_string ("current-video");

            var playback_manager = PlaybackManager.get_default ();
            playback_manager.clear_playlist ();
            playback_manager.append_to_playlist (video.video_file);

            var window = App.get_instance ().mainwindow;
            window.play_file (uri, Window.NavigationPage.EPISODES, from_beginning);

            if (settings.get_boolean ("autoqueue-next")) {
                // Add next from the current view to the queue
                uint played_index;
                items.find (selected, out played_index);
                for (played_index++; played_index < items.get_n_items (); played_index++) {
                    var library_item = (LibraryItem)items.get_item (played_index);
                    playback_manager.append_to_playlist (library_item.video.video_file);
                }
            }
        }
    }

    private void filter () {
         view_episodes.invalidate_filter ();
         if (!has_child ()) {
            alert_view.title = _("No Results for “%s”").printf (search_entry.text);
            alert_view.visible = true;
         } else {
            alert_view.visible = false;
         }
    }

    private bool episodes_filter_func (Gtk.FlowBoxChild child) {
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

    private int episode_sort_func (Object item1, Object item2) {
        var library_item1 = (LibraryItem)item1;
        var library_item2 = (LibraryItem)item2;
        if (library_item1 != null && library_item2 != null) {
            return library_item1.episodes.first ().file.collate (library_item2.episodes.first ().file);
        }
        return 0;
    }

    private void add_item (Audience.Objects.Video episode) {
        if (items.get_n_items () > 0 ) {
            var first = (LibraryItem)items.get_item (0);
            if (first != null && first.episodes.first ().video_file.get_parent ().get_path () == episode.video_file.get_parent ().get_path ()) {
                items.insert_sorted (new Audience.LibraryItem (episode, LibraryItemStyle.ROW), episode_sort_func);
            }
        }
    }

    private async void remove_item_from_path (string path ) {
        for (int i = 0; i < items.get_n_items (); i++) {
            var item = (LibraryItem)items.get_item (i);
            if (item.episodes.size == 0 || item.episodes.first ().video_file.get_path ().has_prefix (path)) {
                items.remove (i);
            }
        }

        var Leaflet = (Adw.Leaflet) get_ancestor (typeof (Adw.Leaflet));
        if (Leaflet.visible_child == this && items.get_n_items () == 0) {
            Leaflet.navigate (Adw.NavigationDirection.BACK);
        }
    }

    private bool has_child () {
        for (int i = 0; i < items.get_n_items (); i++) {
            var item = (LibraryItem)items.get_item (i);
            if (item.get_child_visible ()) {
                return true;
            }
        }
        return false;
    }
}
