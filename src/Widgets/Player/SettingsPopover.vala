/*-
 * Copyright 2013-2021 elementary, Inc. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

public class Audience.Widgets.SettingsPopover : Gtk.Popover {
    public bool is_setup = false;

    private Gtk.ComboBoxText languages;
    private Gtk.ComboBoxText subtitles;
    private Gtk.Label external_subtitle_file_label;

    construct {
        languages = new Gtk.ComboBoxText ();
        subtitles = new Gtk.ComboBoxText ();

        external_subtitle_file_label = new Gtk.Label ("");

        var external_subtitle_file_image = new Gtk.Image.from_icon_name ("folder-symbolic");

        var external_subtitle_file_box = new Gtk.Box (HORIZONTAL, 3);
        external_subtitle_file_box.append (external_subtitle_file_label);
        external_subtitle_file_box.append (new Gtk.Separator (VERTICAL));
        external_subtitle_file_box.append (external_subtitle_file_image);

        var external_subtitle_file = new Gtk.Button () {
            child = external_subtitle_file_box
        };

        var lang_label = new Gtk.Label (_("Audio:")) {
            halign = Gtk.Align.END
        };

        var sub_label = new Gtk.Label (_("Subtitles:")) {
            halign = Gtk.Align.END
        };

        var sub_ext_label = new Gtk.Label (_("External Subtitles:")) {
            halign = Gtk.Align.END
        };

        var setupgrid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 6,
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6
        };
        setupgrid.attach (lang_label, 0, 1);
        setupgrid.attach (languages, 1, 1);
        setupgrid.attach (sub_label, 0, 2);
        setupgrid.attach (subtitles, 1, 2);
        setupgrid.attach (sub_ext_label, 0, 3);
        setupgrid.attach (external_subtitle_file, 1, 3);

        position = TOP;
        child = setupgrid;

        set_external_subtitel_label ();

        var playback_manager = PlaybackManager.get_default ();
        playback_manager.next_audio.connect (next_audio);
        playback_manager.next_text.connect (next_text);

        external_subtitle_file.clicked.connect (get_external_subtitle_file);

        playback_manager.notify["subtitle-uri"].connect (set_external_subtitel_label);

        playback_manager.uri_changed.connect (() => {
            is_setup = false;
        });

        subtitles.changed.connect (on_subtitles_changed);

        languages.changed.connect (on_languages_changed);

        map.connect (() => {
            setup ();
        });
    }

    private void set_external_subtitel_label () {
        var playback_manager = PlaybackManager.get_default ();
        if (playback_manager.subtitle_uri != "") {
            var file = File.new_for_uri (playback_manager.subtitle_uri);
            external_subtitle_file_label.label = file.get_basename ();
        } else {
            external_subtitle_file_label.label = _("None");
        }
    }

    private async void get_external_subtitle_file () {
        popdown ();

        var all_files_filter = new Gtk.FileFilter ();
        all_files_filter.set_filter_name (_("All files"));
        all_files_filter.add_pattern ("*");

        var subtitle_files_filter = new Gtk.FileFilter ();
        subtitle_files_filter.set_filter_name (_("Subtitle files"));
        subtitle_files_filter.add_mime_type ("application/smil"); // .smi
        subtitle_files_filter.add_mime_type ("application/x-subrip"); // .srt
        subtitle_files_filter.add_mime_type ("text/x-microdvd"); // .sub
        subtitle_files_filter.add_mime_type ("text/x-ssa"); // .ssa & .ass
        // exclude .asc, mimetype is generic "application/pgp-encrypted"

        var filters = new ListStore (typeof (Gtk.FileFilter));
        filters.append (subtitle_files_filter);
        filters.append (all_files_filter);

        var file_dialog = new Gtk.FileDialog () {
            title = _("Open"),
            accept_label = _("_Open"),
            filters = filters
        };

        try {
            var subtitle_file = yield file_dialog.open ((Gtk.Window)get_root (), null);

            PlaybackManager.get_default ().set_subtitle (subtitle_file.get_uri ());
        } catch (Error err) {
            warning ("Failed to select subtitle file: %s", err.message);
        }
    }

    private void setup () {
        if (!is_setup) {
            is_setup = true;
            setup_text ();
            setup_audio ();
        }
    }

    private void on_subtitles_changed () {
        if (subtitles.active < 0) {
            return;
        }

        if (subtitles.active_id == "none") {
            PlaybackManager.get_default ().set_subtitle_track (-1);
        } else {
            PlaybackManager.get_default ().set_subtitle_track (subtitles.active);
        }
    }

    private void on_languages_changed () {
        if (languages.active < 0 || languages.active_id == "def") {
            return;
        }

        PlaybackManager.get_default ().set_audio_track (languages.active);
    }

    private void setup_text () {
        subtitles.changed.disconnect (on_subtitles_changed);

        if (subtitles.model.iter_n_children (null) > 0) {
            subtitles.remove_all ();
        }

        var playback_manager = PlaybackManager.get_default ();

        uint track = 1;
        playback_manager.get_subtitle_tracks ().foreach ((lang) => {
            // FIXME: Using Track since lang is actually a bad pointer :/
            subtitles.append (lang, _("Track %u").printf (track++));
        });
        subtitles.append ("none", _("None"));

        int count = subtitles.model.iter_n_children (null);
        subtitles.sensitive = count > 1;
        if (subtitles.sensitive && (playback_manager.get_subtitle_track () >= 0)) {
            subtitles.active = playback_manager.get_subtitle_track ();
        } else {
            subtitles.active = count - 1;
        }

        subtitles.changed.connect (on_subtitles_changed);
    }

    private void setup_audio () {
        languages.changed.disconnect (on_languages_changed);

        if (languages.model.iter_n_children (null) > 0) {
            languages.remove_all ();
        }

        var playback_manager = PlaybackManager.get_default ();

        uint track = 1;
        playback_manager.get_audio_tracks ().foreach ((language_code) => {
            var audio_stream_lang = Gst.Tag.get_language_name (language_code);
            if (audio_stream_lang != null) {
                languages.append (language_code, audio_stream_lang);
            } else {
                languages.append (language_code, _("Track %u").printf (track));
            }
            track++;
        });

        int count = languages.model.iter_n_children (null);
        languages.sensitive = count > 1;
        if (languages.sensitive) {
            languages.active = playback_manager.get_audio_track ();
        } else {
            if (count != 0) {
                languages.remove_all ();
            }
            languages.append ("def", _("Default"));
            languages.active = 0;
        }

        languages.changed.connect (on_languages_changed);
    }

    private void next_audio () {
        setup ();
        int count = languages.model.iter_n_children (null);
        if (count > 0) {
            languages.active = (languages.active + 1) % count;
        }
    }

    private void next_text () {
        setup ();
        int count = subtitles.model.iter_n_children (null);
        if (count > 0) {
            subtitles.active = (subtitles.active + 1) % count;
        }
    }
}
