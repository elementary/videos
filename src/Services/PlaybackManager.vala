/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Audience.PlaybackManager : Object {
    public signal bool next ();
    public signal File? get_first_item ();
    public signal void clear_playlist (bool should_stop = true);
    public signal void item_added ();
    public signal void play (File file);
    public signal void previous ();
    public signal void queue_file (File file);
    public signal void save_playlist ();
    public signal void set_current (string current_file);
    public signal void set_subtitle (string uri);
    public signal void stop ();

    private static PlaybackManager? _instance;
    public static PlaybackManager get_default () {
        if (_instance == null) {
            _instance = new PlaybackManager ();
        }

        return _instance;
    }

    private PlaybackManager () {}
}
