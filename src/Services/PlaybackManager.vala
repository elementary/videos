/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Audience.PlaybackManager : Object {
    public signal void play (File path);
    public signal void stop ();
    public signal void next ();
    public signal void previous ();
    public signal void set_subtitle (string uri);
    public signal void clear_playlist (bool should_stop = true);
    public signal void save_playlist ();

    private static PlaybackManager? _instance;
    public static PlaybackManager get_default () {
        if (_instance == null) {
            _instance = new PlaybackManager ();
        }

        return _instance;
    }

    private PlaybackManager () {}
}
