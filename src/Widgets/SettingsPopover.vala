// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013-2014 Audience Developers (http://launchpad.net/pantheon-chat)
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
    private Gtk.ComboBoxText languages;
    private Gtk.ComboBoxText subtitles;
    private Gtk.FileChooserButton external_subtitle_file;
    private ClutterGst.Playback playback;

    public SettingsPopover (ClutterGst.Playback playback) {
        this.playback = playback;
        opacity = GLOBAL_OPACITY;

        languages = new Gtk.ComboBoxText ();
        subtitles = new Gtk.ComboBoxText ();

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

        external_subtitle_file = new Gtk.FileChooserButton (_("External Subtitles"), Gtk.FileChooserAction.OPEN);
        external_subtitle_file.add_filter (subtitle_files_filter);
        external_subtitle_file.add_filter (all_files_filter);

        var lang_label = new Gtk.Label (_("Audio:"));
        lang_label.halign = Gtk.Align.END;

        var sub_label = new Gtk.Label (_("Subtitles:"));
        sub_label.halign = Gtk.Align.END;

        var sub_ext_label = new Gtk.Label (_("External Subtitles:"));
        sub_ext_label.halign = Gtk.Align.END;

        var setupgrid  = new Gtk.Grid ();
        setupgrid.row_spacing = 6;
        setupgrid.margin = 6;
        setupgrid.attach (lang_label, 0, 1, 1, 1);
        setupgrid.attach (languages, 1, 1, 1, 1);
        setupgrid.attach (sub_label, 0, 2, 1, 1);
        setupgrid.attach (subtitles, 1, 2, 1, 1);
        setupgrid.attach (sub_ext_label, 0, 3, 1, 1);
        setupgrid.attach (external_subtitle_file, 1, 3, 1, 1);
        setupgrid.column_spacing = 12;

        external_subtitle_file.file_set.connect (() => {
            playback.set_subtitle_uri (external_subtitle_file.get_uri ());
        });

        playback.notify["subtitle_uri"].connect (() => {
            external_subtitle_file.select_uri (playback.subtitle_uri);
        });

        subtitles.changed.connect (() => {
            if (subtitles.active <= -1)
                return;

            if (subtitles.active_id == "none") {
                playback.subtitle_track = -1;
                return;
            }

            playback.subtitle_track = subtitles.active;
        });

        languages.changed.connect ( () => { //place it here to not get problems
            if (languages.active <= -1 || languages.active_id == "def")
                return;

            playback.audio_stream = languages.active;
        });

        add (setupgrid);
    }

    public void setup_text () {
        if (subtitles.model.iter_n_children (null) > 0)
            subtitles.remove_all ();

        playback.get_subtitle_tracks ().foreach ((lang) => {
            subtitles.append (lang, lang);
        });

        subtitles.append ("none", _("None"));
        subtitles.active = playback.subtitle_track;
        subtitles.sensitive = subtitles.model.iter_n_children (null) > 1;
    }

    public void setup_audio () {
        if (languages.model.iter_n_children (null) > 0)
            languages.remove_all ();

        playback.get_audio_streams ().foreach ((lang) => {
            languages.append (lang, lang);
        });

        languages.sensitive = languages.model.iter_n_children (null) > 0;
        if (!languages.sensitive) {
            languages.append ("def", _("Default"));
            languages.active = 0;
        } else {
            languages.active = playback.subtitle_track;
        }
    }

    public void next_audio () {
        int current = languages.active;
        if (current < languages.model.iter_n_children (null) - 1) {
            current++;
        } else {
            current = 0;
        }

        languages.active = current;
    }

    public void next_text () {
        int current = subtitles.active;
        if (current < subtitles.model.iter_n_children (null)) {
            current++;
        } else {
            current = 0;
        }

        subtitles.active = current;
    }
}
