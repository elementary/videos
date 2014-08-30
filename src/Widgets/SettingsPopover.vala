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

    public SettingsPopover () {
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
        setupgrid.column_homogeneous = true;
        setupgrid.column_spacing = 12;

        external_subtitle_file.file_set.connect (() => {
            VideoPlayer.get_default ().set_subtitle_uri (external_subtitle_file.get_uri ());
        });

        VideoPlayer.get_default ().external_subtitle_changed.connect ((uri) => {
            external_subtitle_file.select_uri (uri);
        });

        subtitles.changed.connect (() => {
            if (subtitles.active_id == null)
                return;

            var id = int.parse (subtitles.active_id);
            VideoPlayer.get_default ().current_text = id;
        });

        languages.changed.connect ( () => { //place it here to not get problems
            if (languages.active_id == null)
                return;

            VideoPlayer.get_default ().current_audio = int.parse (languages.active_id);
        });

        add (setupgrid);
    }

    public void setup_text () {
        subtitles.sensitive = false;
        if (subtitles.model.iter_n_children (null) > 0)
            subtitles.remove_all ();

        int n_text;
        VideoPlayer.get_default ().playbin.get ("n-text", out n_text);
        for (var i=0; i<n_text; i++) {
            Gst.TagList tags = null;
            Signal.emit_by_name (VideoPlayer.get_default ().playbin, "get-text-tags", i, out tags);
            if (tags == null)
                continue;

            string desc;
            string readable = null;
            tags.get_string (Gst.Tags.LANGUAGE_CODE, out desc);
            if (desc == null)
                tags.get_string (Gst.Tags.CODEC, out desc);

            if (desc != null) {
                readable = Gst.Tag.get_language_name (desc);
                var language = Gst.Tag.get_language_name (desc);
                subtitles.append (i.to_string (), language == null ? desc : language);
                subtitles.sensitive = true;
            }
        }

        subtitles.append ("-1", _("None"));
        subtitles.active_id = VideoPlayer.get_default ().current_text.to_string ();
    }

    public void setup_audio () {
        languages.sensitive = false;
        if (languages.model.iter_n_children (null) > 0)
            languages.remove_all ();

        int n_audio;
        VideoPlayer.get_default ().playbin.get ("n-audio", out n_audio);
        for (var i=0; i<n_audio; i++) {
            Gst.TagList tags = null;
            Signal.emit_by_name (VideoPlayer.get_default ().playbin, "get-audio-tags", i, out tags);
            if (tags == null)
                continue;

            string desc;
            string readable = null;
            tags.get_string (Gst.Tags.LANGUAGE_CODE, out desc);
            if (desc == null)
                tags.get_string (Gst.Tags.CODEC, out desc);

            if (desc != null) {
                readable = Gst.Tag.get_language_name (desc);
                languages.append (i.to_string (), readable == null ? desc : readable);
            }
        }

        var audio_items = languages.model.iter_n_children (null);
        if (audio_items <= 0) {
            languages.append ("def", _("Default"));
            languages.active = 0;
        } else {
            if (audio_items != 1)
                languages.sensitive = true;

            languages.active_id = VideoPlayer.get_default ().current_audio.to_string ();
        }
    }

    public void next_audio () {
        int current = int.parse (languages.active_id);
        if (current < languages.model.iter_n_children (null) - 1) {
            current++;
        } else {
            current = 0;
        }

        languages.active_id = current.to_string ();
    }

    public void next_text () {
        int current = int.parse (subtitles.active_id);
        if (current < subtitles.model.iter_n_children (null)) {
            current++;
        } else {
            current = 0;
        }

        subtitles.active_id = current.to_string ();
    }
}
