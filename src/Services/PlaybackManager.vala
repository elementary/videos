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
    public signal void uri_changed (string uri);

    public Gtk.MediaFile playback { get; private set; }
    public string? subtitle_uri { get; private set; }

    private uint inhibit_token = 0;
    private ulong ready_handler_id = 0;

    private static GLib.Once<PlaybackManager> instance;
    public static unowned PlaybackManager get_default () {
        return instance.once (() => { return new PlaybackManager (); });
    }

    private PlaybackManager () {}

    construct {
        unowned var default_application = (Gtk.Application) Application.get_default ();
        playback = Gtk.MediaFile.empty ();

        default_application.action_state_changed.connect ((name, new_state) => {
            if (name == Audience.App.ACTION_PLAY_PAUSE) {
                playback.playing = new_state.get_boolean ();
            }
        });

        playback.notify["playing"].connect (() => {
            var play_pause_action = default_application.lookup_action (Audience.App.ACTION_PLAY_PAUSE);
            ((SimpleAction) play_pause_action).set_state (playback.playing);

            if (playback.playing) {
                if (inhibit_token != 0) {
                    default_application.uninhibit (inhibit_token);
                }

                inhibit_token = default_application.inhibit (
                    default_application.active_window,
                    Gtk.ApplicationInhibitFlags.IDLE | Gtk.ApplicationInhibitFlags.SUSPEND,
                    _("A video is playing")
                );
            } else if (inhibit_token != 0) {
                default_application.uninhibit (inhibit_token);
                inhibit_token = 0;
            }
        });

        playback.notify["ended"].connect (() => {
            if (!playback.ended) {
                return;
            }

            if (!next ()) {
                var repeat_action = default_application.lookup_action (Audience.App.ACTION_REPEAT);
                if (repeat_action.get_state ().get_boolean ()) {
                    var file = get_first_item ();
                    ((Audience.Window) default_application.active_window).open_files ({ file });
                } else {
                    settings.set_int64 ("last-stopped", 0);
                    ended ();
                }
            }
        });

        // playback.eos.connect (() => {
        //     Idle.add (() => {
        //         playback.progress = 0;
        //         if (!next ()) {
        //             var repeat_action = default_application.lookup_action (Audience.App.ACTION_REPEAT);
        //             if (repeat_action.get_state ().get_boolean ()) {
        //                 var file = get_first_item ();
        //                 ((Audience.Window) default_application.active_window).open_files ({ file });
        //             } else {
        //                 pipeline.set_state (Gst.State.NULL);
        //                 settings.set_double ("last-stopped", 0);
        //                 ended ();
        //             }
        //         }
        //         return false;
        //     });
        // });

        // /* playback.subtitle_uri does not seem to notify so connect directly to the pipeline */
        // pipeline.notify["suburi"].connect (() => {
        //     if (subtitle_uri != playback.subtitle_uri) {
        //         subtitle_uri = playback.subtitle_uri;
        //     }
        // });

        // playback.notify ["uri"].connect (() => {
        //     uri_changed (playback.uri);
        // });
    }

    ~PlaybackManager () {
        // // FIXME:should find better way to decide if its end of playlist
        // if (playback.progress > 0.99) {
        //     settings.set_double ("last-stopped", 0);
        // } else if (playback.uri != "") {
        //     /* The progress is only valid if the uri has not been reset as the current video setting is not
        //      * updated.  The playback.uri has been reset when the window is destroyed from the Welcome page */
        //     settings.set_double ("last-stopped", playback.progress);
        // }

        save_playlist ();

        if (inhibit_token != 0) {
            ((Gtk.Application) GLib.Application.get_default ()).uninhibit (inhibit_token);
            inhibit_token = 0;
        }
    }

    public void play_file (string uri, bool from_beginning = true) {
        debug ("Opening %s", uri);
        var file = File.new_for_uri (uri);
        try {
            var info = file.query_info (GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," + GLib.FileAttribute.STANDARD_NAME, 0);
            unowned string content_type = info.get_content_type ();

            if (!GLib.ContentType.is_a (content_type, "video/*")) {
                debug ("Unrecognized file format: %s", content_type);
                var unsupported_file_dialog = new UnsupportedFileDialog (uri, info.get_name (), content_type);
                unsupported_file_dialog.present ();

                unsupported_file_dialog.response.connect (type => {
                    if (type == Gtk.ResponseType.CANCEL) {
                        // Play next video if available or else go to welcome page
                        if (!next ()) {
                            ended ();
                        }
                    }

                    unsupported_file_dialog.destroy ();
                });
            }
        } catch (Error e) {
            debug (e.message);
        }

        playback.set_file (file);

        ((Gtk.Application) Application.get_default ()).active_window.title = get_title (uri);

        /* Set progress before subtitle uri else it gets reset to zero */
        if (from_beginning) {
            playback.seek (0);
        } else {
            set_progress (settings.get_int64 ("last-stopped"));
        }

        if (!from_beginning) { //We are resuming the current video - fetch the current subtitles
            /* Should not bind to this setting else may cause loop */
            set_subtitle (settings.get_string ("current-external-subtitles-uri"));
        } else {
            set_subtitle (get_subtitle_for_uri (uri));
        }

        playback.play_now ();
        Gtk.RecentManager.get_default ().add_item (uri);

        settings.set_string ("current-video", uri);
    }

    public void stop () {
        settings.set_int64 ("last-stopped", 0);
        settings.set_strv ("last-played-videos", {});
        settings.set_string ("current-video", "");

        /* We do not want to emit an "ended" signal if already ended - it can cause premature
         * ending of next video and other side-effects
         */
        if (playback.playing) {
            playback.stream_ended ();
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
        // if (uri.length < 4 || uri.get_char (uri.length - 4) != '.') {
        //     return false;
        // }

        // foreach (unowned string ext in SUBTITLE_EXTENSIONS) {
        //     if (uri.down ().has_suffix (ext)) {
        //         return true;
        //     }
        // }

        return false;
    }

    // public unowned List<string> get_audio_tracks () {
    //     return playback.get_audio_streams ();
    // }

    // public unowned List<string> get_subtitle_tracks () {
    //     return playback.get_subtitle_tracks ();
    // }

    // public string get_uri () {
    //     return playback.uri;
    // }

    public bool get_playing () {
         return playback.playing;
    }

    public int64 get_duration () {
        return playback.duration;
    }

    // public int get_audio_track () {
    //     return playback.audio_stream;
    // }

    // public void set_audio_track (int track) {
    //     playback.audio_stream = track;
    // }

    public int64 get_progress () {
        return playback.timestamp;
    }

    public void set_progress (int64 timestamp) {
        playback.seek (timestamp);
    }

    // public int get_subtitle_track () {
    //     return playback.subtitle_track;
    // }

    // public void set_subtitle_track (int track) {
    //     playback.subtitle_track = track;
    // }

    public void set_subtitle (string uri) {
        // var progress = playback.progress;
        // var is_playing = playback.playing;

        // /* Temporarily connect to the ready signal so that we can restore the progress setting
        //  * after resetting the pipeline in order to set the subtitle uri */
        // ready_handler_id = playback.ready.connect (() => {
        //     playback.progress = progress;
        //     // Pause video if it was in Paused state before adding the subtitle
        //     if (!is_playing) {
        //         pipeline.set_state (Gst.State.PAUSED);
        //     }

        //     playback.disconnect (ready_handler_id);
        // });

        // pipeline.set_state (Gst.State.NULL); // Does not work otherwise
        // playback.set_subtitle_uri (uri);
        // pipeline.set_state (Gst.State.PLAYING);

        // settings.set_string ("current-external-subtitles-uri", uri);
    }

    private string get_subtitle_for_uri (string uri) {
        /* This assumes that the subtitle file has the same basename as the video file but with
         * one of the subtitle extensions, and is in the same folder. */
        // string without_ext;
        // int last_dot = uri.last_index_of (".", 0);
        // int last_slash = uri.last_index_of ("/", 0);

        // if (last_dot < last_slash) {//we dont have extension
        //     without_ext = uri;
        // } else {
        //     without_ext = uri.slice (0, last_dot);
        // }

        // foreach (string ext in SUBTITLE_EXTENSIONS) {
        //     string sub_uri = without_ext + "." + ext;
        //     if (File.new_for_uri (sub_uri).query_exists ()) {
        //         return sub_uri;
        //     }
        // }

        return "";
    }
}
