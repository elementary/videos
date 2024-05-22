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

public class Audience.EpisodesPage : Adw.NavigationPage {
    private Gtk.Picture poster;
    private Gtk.FilterListModel filter_model;
    private Gtk.SearchEntry search_entry;
    private Granite.Placeholder alert_view;

    construct {
        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Search Videos"),
            valign = CENTER
        };

        var autoqueue_next = new Granite.ModeSwitch.from_icon_name (
            "media-playlist-repeat-one-symbolic",
            "media-playlist-consecutive-symbolic"
        ) {
            halign = END,
            primary_icon_tooltip_text = _("Play one video"),
            secondary_icon_tooltip_text = _("Automatically play next videos")
        };
        settings.bind ("autoqueue-next", autoqueue_next, "active", SettingsBindFlags.DEFAULT);

        var header_bar = new HeaderBar ();

        poster = new Gtk.Picture () {
            hexpand = true,
            content_fit = COVER
        };
        poster.add_css_class (Granite.STYLE_CLASS_CARD);
        poster.add_css_class (Granite.STYLE_CLASS_ROUNDED);

        var aspect_ratio = (float) 16 / 9;

        var aspect_frame = new Gtk.AspectFrame (0.5f, 0.5f, aspect_ratio, false) {
            child = poster,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };

        filter_model = new Gtk.FilterListModel (null, new Gtk.CustomFilter (episodes_filter_func));
        var selection_model = new Gtk.NoSelection (filter_model);

        var factory = new Gtk.SignalListItemFactory ();

        var view_episodes = new Gtk.GridView (selection_model, factory) {
            hexpand = true,
            orientation = HORIZONTAL,
            single_click_activate = true
        };
        view_episodes.add_css_class (Granite.STYLE_CLASS_BACKGROUND);

        alert_view = new Granite.Placeholder ("") {
            description = _("Try changing search terms."),
            icon = new ThemedIcon ("edit-find-symbolic"),
            visible = false
        };

        var grid = new Gtk.Grid () {
            row_spacing = 12
        };
        grid.attach (search_entry, 0, 0);
        grid.attach (view_episodes, 0, 1);
        grid.attach (alert_view, 0, 1);

        var scrolled_window = new Gtk.ScrolledWindow () {
            child = grid,
            hscrollbar_policy = NEVER
        };

        var toolbarview = new Adw.ToolbarView () {
            content = scrolled_window
        };
        toolbarview.add_top_bar (header_bar);
        toolbarview.add_top_bar (aspect_frame);
        toolbarview.add_bottom_bar (autoqueue_next);

        child = toolbarview;
        title = _("Episodes");
        add_css_class ("episodes");

        factory.setup.connect ((obj) => {
            var item = (Gtk.ListItem) obj;
            item.child = new LibraryItem () {
                valign = START
            };
        });

        factory.bind.connect ((obj) => {
            var item = (Gtk.ListItem) obj;
            ((LibraryItem) item.child).bind ((Objects.MediaItem) item.item);
        });

        view_episodes.activate.connect (play_video);

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

    public void set_show (Objects.MediaItem item) {
        filter_model.model = item.children;
        poster.set_pixbuf (item.poster);
    }

    private void play_video (uint position) {
        var video = (Objects.MediaItem) filter_model.get_item (position);

        string[] videos = { video.uri };

        if (settings.get_boolean ("autoqueue-next")) {
            // Add next from the current view to the queue
            for (position++; position < filter_model.get_n_items (); position++) {
                videos += ((Objects.MediaItem) filter_model.get_item (position)).uri;
            }
        }

        var playback_manager = PlaybackManager.get_default ();
        playback_manager.clear_playlist ();
        playback_manager.append_to_playlist (videos);

        bool from_beginning = video.uri != settings.get_string ("current-video");

        var window = App.get_instance ().mainwindow;
        window.play_file (video.uri, Window.NavigationPage.EPISODES, from_beginning);
    }

    private void filter () {
         filter_model.model.items_changed (0, filter_model.model.get_n_items (), filter_model.model.get_n_items ());
         if (filter_model.get_n_items () == 0) {
            alert_view.title = _("No Results for “%s”").printf (search_entry.text);
            alert_view.visible = true;
         } else {
            alert_view.visible = false;
         }
    }

    private bool episodes_filter_func (Object obj) {
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
}
