/*
 * Copyright 2013-2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

public class Audience.WelcomePage : Adw.NavigationPage {
    private string current_video;
    private Gtk.Button replay_button;
    private Gtk.Image replay_button_image;
    private Gtk.Label replay_button_title;
    private Gtk.Label replay_button_description;

    construct {
        var placeholder = new Granite.Placeholder (_("No Videos Open")) {
            description = _("Select a source to begin playing."),
            hexpand = true,
            vexpand = true
        };

        var open_button = placeholder.append_button (new ThemedIcon ("document-open"), _("Open file"), _("Open a saved file."));
        replay_button = placeholder.append_button (new ThemedIcon ("media-playlist-repeat"), _("Replay last video"), "");
        var library_button = placeholder.append_button (new ThemedIcon ("folder-videos"), _("Browse Library"), _("Watch a movie from your library"));

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (new HeaderBar ());
        box.append (placeholder);
        box.add_css_class (Granite.STYLE_CLASS_VIEW);

        child = box;
        title = _("Home");

        //A hacky way to update the labels and icon of the replay button
        var replay_button_grid = (Gtk.Grid)replay_button.child;
        replay_button_image = (Gtk.Image)replay_button_grid.get_first_child ();
        replay_button_title = (Gtk.Label)replay_button_image.get_next_sibling ();
        replay_button_description = (Gtk.Label)replay_button_title.get_next_sibling ();

        var library_manager = Services.LibraryManager.get_instance ();
        library_button.visible = library_manager.library_items.get_n_items () > 0;

        update_replay_button ();
        update_replay_title ();

        open_button.clicked.connect (() => {
            var window = (Audience.Window)get_root ();
            window.run_open_file ();
        });

        replay_button.clicked.connect (() => {
            var window = (Audience.Window)get_root ();
            PlaybackManager.get_default ().append_to_playlist ({ current_video });
            window.resume_last_videos ();
        });

        library_button.clicked.connect (() => {
            var window = (Audience.Window)get_root ();
            window.show_library ();
        });

        settings.changed["current-video"].connect (update_replay_button);

        settings.changed["last-stopped"].connect (update_replay_title);

        library_manager.library_items.items_changed.connect (() => {
            library_button.visible = library_manager.library_items.get_n_items () > 0;
        });
    }

    private void update_replay_button () {
        bool show_replay_button = false;

        current_video = settings.get_string ("current-video");
        if (current_video != "") {
            var last_file = File.new_for_uri (current_video);
            if (last_file.query_exists ()) {
                replay_button_description.label = Audience.get_title (last_file.get_basename ());

                show_replay_button = true;
            }
        }

        replay_button.visible = show_replay_button;
    }

    private void update_replay_title () {
        if (settings.get_int64 ("last-stopped") == 0) {
            replay_button_title.label = _("Replay last video");
            replay_button_image.set_from_icon_name ("media-playlist-repeat");
        } else {
            replay_button_title.label = _("Resume last video");
            replay_button_image.set_from_icon_name ("media-playback-start");
        }
    }
}
