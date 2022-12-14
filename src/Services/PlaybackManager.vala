/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Audience.PlaybackManager : Object {
    public signal bool next ();
    public signal File? get_first_item ();
    public signal void clear_playlist (bool should_stop = true);
    public signal void ended ();
    public signal void item_added ();
    public signal void next_audio ();
    public signal void next_text ();
    public signal void play (File file);
    public signal void previous ();
    public signal void queue_file (File file);
    public signal void save_playlist ();
    public signal void set_current (string current_file);

    public ClutterGst.Playback playback { get; private set; }
    public string? subtitle_uri { get; private set; }

    public unowned Gst.Pipeline pipeline {
        get {
            return (Gst.Pipeline) playback.get_pipeline ();
        }
    }

    private uint inhibit_token = 0;
    private ulong ready_handler_id = 0;

    private static GLib.Once<PlaybackManager> instance;
    public static unowned PlaybackManager get_default () {
        return instance.once (() => { return new PlaybackManager (); });
    }

    private PlaybackManager () {}

    construct {
        playback = new ClutterGst.Playback ();
        playback.set_seek_flags (ClutterGst.SeekFlags.ACCURATE);

        GLib.Application.get_default ().action_state_changed.connect ((name, new_state) => {
            if (name == Audience.App.ACTION_PLAY_PAUSE) {
                playback.playing = new_state.get_boolean ();
            }
        });

        playback.notify["playing"].connect (() => {
            unowned var app = (Gtk.Application) Application.get_default ();

            var play_pause_action = app.lookup_action (Audience.App.ACTION_PLAY_PAUSE);
            ((SimpleAction) play_pause_action).set_state (playback.playing);

            if (playback.playing) {
                if (inhibit_token != 0) {
                    app.uninhibit (inhibit_token);
                }

                inhibit_token = app.inhibit (
                    app.get_active_window (),
                    Gtk.ApplicationInhibitFlags.IDLE | Gtk.ApplicationInhibitFlags.SUSPEND,
                    _("A video is playing")
                );
            } else if (inhibit_token != 0) {
                app.uninhibit (inhibit_token);
                inhibit_token = 0;
            }
        });

        playback.eos.connect (() => {
            Idle.add (() => {
                playback.progress = 0;
                if (!next ()) {
                    var repeat_action = Application.get_default ().lookup_action (Audience.App.ACTION_REPEAT);
                    if (repeat_action.get_state ().get_boolean ()) {
                        var file = get_first_item ();
                        ((Audience.Window) App.get_instance ().active_window).open_files ({ file });
                    } else {
                        playback.playing = false;
                        settings.set_double ("last-stopped", 0);
                        ended ();
                    }
                }
                return false;
            });
        });

        /* playback.subtitle_uri does not seem to notify so connect directly to the playback_manager.pipeline */
        pipeline.notify["suburi"].connect (() => {
            if (subtitle_uri != playback.subtitle_uri) {
                subtitle_uri = playback.subtitle_uri;
            }
        });
    }

    ~PlaybackManager () {
        // FIXME:should find better way to decide if its end of playlist
        if (playback.progress > 0.99) {
            settings.set_double ("last-stopped", 0);
        } else if (playback.uri != "") {
            /* The progress is only valid if the uri has not been reset as the current video setting is not
             * updated.  The playback.uri has been reset when the window is destroyed from the Welcome page */
            settings.set_double ("last-stopped", playback.progress);
        }

        save_playlist ();

        if (inhibit_token != 0) {
            ((Gtk.Application) GLib.Application.get_default ()).uninhibit (inhibit_token);
            inhibit_token = 0;
        }
    }

    public double get_progress () {
        return playback.progress;
    }

    public void stop () {
        settings.set_double ("last-stopped", 0);
        settings.set_strv ("last-played-videos", {});
        settings.set_string ("current-video", "");

        /* We do not want to emit an "ended" signal if already ended - it can cause premature
         * ending of next video and other side-effects
         */
        if (playback.playing) {
            playback.playing = false;
            playback.progress = 1.0;
            ended ();
        }
    }

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

    public void set_subtitle (string uri) {
        var progress = playback.progress;
        var is_playing = playback.playing;

        /* Temporarily connect to the ready signal so that we can restore the progress setting
         * after resetting the pipeline in order to set the subtitle uri */
        ready_handler_id = playback.ready.connect (() => {
            playback.progress = progress;
            // Pause video if it was in Paused state before adding the subtitle
            if (!is_playing) {
                pipeline.set_state (Gst.State.PAUSED);
            }

            playback.disconnect (ready_handler_id);
        });

        pipeline.set_state (Gst.State.NULL); // Does not work otherwise
        playback.set_subtitle_uri (uri);
        pipeline.set_state (Gst.State.PLAYING);

        settings.set_string ("current-external-subtitles-uri", uri);
    }
}
