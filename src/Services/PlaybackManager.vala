/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Audience.PlaybackManager : Object {
    public signal bool next ();
    public signal void clear_playlist (bool should_stop = true);
    public signal void play (File path);
    public signal void previous ();
    public signal void save_playlist ();
    public signal void set_current (string current_file);
    public signal void set_subtitle (string uri);
    public signal void stop ();
    public signal File? get_first_item ();

    private static PlaybackManager? _instance;
    public static PlaybackManager get_default () {
        if (_instance == null) {
            _instance = new PlaybackManager ();
        }

        return _instance;
    }

    private PlaybackManager () {}
}
