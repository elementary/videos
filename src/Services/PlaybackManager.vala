/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Audience.PlaybackManager : Object {
    public signal bool next ();
    public signal File? get_first_item ();
    public signal void clear_playlist (bool should_stop = true);
    public signal void item_added ();
    public signal void next_audio ();
    public signal void next_text ();
    public signal void play (File file);
    public signal void previous ();
    public signal void queue_file (File file);
    public signal void save_playlist ();
    public signal void set_current (string current_file);
    public signal void stop ();

    public string? subtitle_uri { get; set; }

    private static GLib.Once<PlaybackManager> instance;
    public static unowned PlaybackManager get_default () {
        return instance.once (() => { return new PlaybackManager (); });
    }

    private PlaybackManager () {}

    public void append_to_playlist (File file) {
        if (is_subtitle (file.get_uri ())) {
            subtitle_uri = file.get_uri ();
        } else {
            queue_file (file);
        }
    }

    private bool is_subtitle (string uri) {
        if (uri.length < 4 || uri.get_char (uri.length - 4) != '.') {
            return false;
        }

        foreach (unowned string ext in SUBTITLE_EXTENSIONS) {
            if (uri.down ().has_suffix (ext)) {
                return true;
            }
        }

        return false;
    }
}
