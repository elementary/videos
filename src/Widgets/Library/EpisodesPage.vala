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

public class Audience.EpisodesPage : Gtk.Grid {
    public Gtk.Image poster { get; private set; }

    private Gtk.FlowBox view_episodes;
    // private Granite.Widgets.AlertView alert_view;
    private Gee.ArrayList<Audience.Objects.Video> shown_episodes;

    private string query;
    private Objects.Video poster_source;

    construct {
        query = "";
        poster_source = null;

        poster = new Gtk.Image () {
            margin = 24,
            margin_end = 0,
            valign = Gtk.Align.START
        };
        poster.get_style_context ().add_class (Granite.STYLE_CLASS_CARD);

        view_episodes = new Gtk.FlowBox () {
            homogeneous = true,
            margin = 24,
            max_children_per_line = 1,
            selection_mode = Gtk.SelectionMode.NONE,
            valign = Gtk.Align.START
        };
        view_episodes.set_sort_func (episode_sort_func);
        view_episodes.set_filter_func (episodes_filter_func);

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            expand = true
        };
        scrolled_window.add (view_episodes);

        // alert_view = new Granite.Widgets.AlertView (
        //     "",
        //     _("Try changing search terms."),
        //     "edit-find-symbolic"
        // );
        // alert_view.get_style_context ().remove_class (Gtk.STYLE_CLASS_VIEW);
        // alert_view.no_show_all = true;

        expand = true;
        attach (poster, 0, 1);
        attach (scrolled_window, 1, 1);
        // attach (alert_view, 1, 1);

        view_episodes.child_activated.connect (play_video);

        var manager = Audience.Services.LibraryManager.get_instance ();
        manager.video_file_deleted.connect (remove_item_from_path);
        manager.video_file_detected.connect (add_item);
    }

    public void set_episodes_items (Gee.ArrayList<Audience.Objects.Video> episodes) {
        view_episodes.forall ((item) => {
            item.dispose ();
        });
        shown_episodes = new Gee.ArrayList<Audience.Objects.Video> ();
        foreach (Audience.Objects.Video episode in episodes) {
            view_episodes.add (new Audience.LibraryItem (episode, LibraryItemStyle.ROW));
            shown_episodes.add (episode);
        }
        shown_episodes.sort ((a, b) => {
            var item1 = (Audience.Objects.Video)a;
            var item2 = (Audience.Objects.Video)b;
            if (item1 != null && item2 != null) {
                return item1.file.collate (item2.file);
            }
            return 0;
        });
        if (poster_source != null) {
            poster_source.poster_changed.disconnect (update_poster);
        }
        poster_source = episodes.first ();
        update_poster (poster_source);
        poster_source.poster_changed.connect (update_poster);
    }

    private void update_poster (Objects.Video episode) {
        poster.pixbuf = episode.poster;
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

            if (window.autoqueue_next_active ()) {
                // Add next from the current view to the queue
                int played_index = shown_episodes.index_of (video);
                foreach (Audience.Objects.Video episode in shown_episodes.slice (played_index, shown_episodes.size)) {
                    playback_manager.append_to_playlist (episode.video_file);
                }
            }
        }
    }

    public void filter (string text) {
         query = text.strip ();
         view_episodes.invalidate_filter ();
         if (!has_child ()) {
            alert_view.no_show_all = false;
            alert_view.show_all ();
            alert_view.title = _("No Results for “%s”").printf (text);
            alert_view.show ();
         } else {
            alert_view.hide ();
         }
    }

    private bool episodes_filter_func (Gtk.FlowBoxChild child) {
        if (query.length == 0) {
            return true;
        }

        string[] filter_elements = query.split (" ");
        var video_title = ((LibraryItem)(child)).get_title ();

        foreach (string filter_element in filter_elements) {
            if (!video_title.down ().contains (filter_element.down ())) {
                return false;
            }
        }
        return true;
    }

    private int episode_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
        var item1 = (LibraryItem)child1;
        var item2 = (LibraryItem)child2;
        if (item1 != null && item2 != null) {
            return item1.episodes.first ().file.collate (item2.episodes.first ().file);
        }
        return 0;
    }

    private void add_item (Audience.Objects.Video episode) {
        if (view_episodes.get_children ().length () > 0 ) {
            var first = (view_episodes.get_children ().first ().data as Audience.LibraryItem);
            if (first != null && first.episodes.first ().video_file.get_parent ().get_path () == episode.video_file.get_parent ().get_path ()) {
                view_episodes.add (new Audience.LibraryItem (episode, LibraryItemStyle.ROW));
            }
        }
    }

    private async void remove_item_from_path (string path ) {
        foreach (var child in view_episodes.get_children ()) {
            if (((LibraryItem)(child)).episodes.size == 0 ||
                ((LibraryItem)(child)).episodes.first ().video_file.get_path ().has_prefix (path)) {
                child.dispose ();
            }
        }

        var leaflet = (Adw.Leaflet) get_ancestor (typeof (Adw.Leaflet));
        if (leaflet.visible_child == this && view_episodes.get_children ().length () == 0) {
            leaflet.navigate (Hdy.NavigationDirection.BACK);
        }
    }

    private bool has_child () {
        if (view_episodes.get_children ().length () > 0) {
           foreach (unowned Gtk.Widget child in view_episodes.get_children ()) {
               if (child.get_child_visible ()) {
                   return true;
               }
            }
        }
        return false;
    }
}
