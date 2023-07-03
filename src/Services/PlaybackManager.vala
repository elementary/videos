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

    public Gdk.Paintable paintable {
        get {
            return _paintable;
        }
    }

    private Gdk.Paintable _paintable;
    private dynamic Gst.Element playbin;
    private string? subtitle_uri;
    private bool playing = false;

    private uint inhibit_token = 0;
    private ulong ready_handler_id = 0;

    private static GLib.Once<PlaybackManager> instance;
    public static unowned PlaybackManager get_default () {
        return instance.once (() => { return new PlaybackManager (); });
    }

    construct {
        unowned var default_application = (Gtk.Application) Application.get_default ();

        var gtksink = Gst.ElementFactory.make ("gtk4paintablesink", "sink");
        gtksink.get ("paintable", out _paintable);

        playbin = (Gst.Pipeline)Gst.ElementFactory.make ("playbin", "playbin");
        playbin.video_sink = gtksink;

        if (playbin != null) {
            print ("success");
            if (paintable != null) {
                print ("paintalb success");
            } else {
                print ("paintalb Failed");
            }
        } else {
            print ("Failed");
        }

        var bus = playbin.get_bus ();
        bus.add_signal_watch ();

        bus.message.connect ((message) => {
            switch (message.type) {
                case EOS:
                    if (!next ()) {
                        var repeat_action = default_application.lookup_action (Audience.App.ACTION_REPEAT);
                        if (repeat_action.get_state ().get_boolean ()) {
                            var file = get_first_item ();
                            ((Audience.Window) default_application.active_window).open_files ({ file });
                        } else {
                            playbin.set_state (Gst.State.NULL);
                            settings.set_int64 ("last-stopped", 0);
                            ended ();
                        }
                    }
                    break;

                case STATE_CHANGED:
                    Gst.State old_state;
                	Gst.State new_state;
                	Gst.State pending_state;

                	message.parse_state_changed (out old_state, out new_state, out pending_state);

                    playing = new_state == Gst.State.PLAYING;

                    var play_pause_action = default_application.lookup_action (Audience.App.ACTION_PLAY_PAUSE);
                    // ((SimpleAction) play_pause_action).set_state (playing);

                    if (playing) {
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
                    break;

                default:
                    print ("default");
                    break;
            }
        });

        playbin.notify ["suburi"].connect (() => {
            if (subtitle_uri != (string)playbin.suburi) {
                subtitle_uri = playbin.suburi;
            }
        });

        playbin.notify ["uri"].connect (() => {
            uri_changed (playbin.uri);
        });

        default_application.action_state_changed.connect ((name, new_state) => {
            if (name == Audience.App.ACTION_PLAY_PAUSE) {
                playbin.set_state (new_state.get_boolean () ? Gst.State.PLAYING : Gst.State.PAUSED);
            }
        });
    }

    ~PlaybackManager () {
        // FIXME:should find better way to decide if its end of playlist
        if (get_position () == get_duration ()) {
            settings.set_int64 ("last-stopped", 0);
        } else if ((string)playbin.uri != "") {
            /* The progress is only valid if the uri has not been reset as the current video setting is not
             * updated.  The playbin.uri has been reset when the window is destroyed from the Welcome page */
            settings.set_int64 ("last-stopped", get_position ());
        }

        save_playlist ();

        if (inhibit_token != 0) {
            ((Gtk.Application) GLib.Application.get_default ()).uninhibit (inhibit_token);
            inhibit_token = 0;
        }
    }

    public void play_file (string uri, bool from_beginning = true) {
        print ("play");
        debug ("Opening %s", uri);
        playbin.set_state (Gst.State.NULL);
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

        playbin.uri = uri;

        ((Gtk.Application) Application.get_default ()).active_window.title = get_title (uri);

        /* Set progress before subtitle uri else it gets reset to zero */
        if (from_beginning) {
            playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH, 0);
        } else {
            set_position (settings.get_int64 ("last-stopped"));
        }

        if (!from_beginning) { //We are resuming the current video - fetch the current subtitles
            /* Should not bind to this setting else may cause loop */
            set_subtitle (settings.get_string ("current-external-subtitles-uri"));
        } else {
            set_subtitle (get_subtitle_for_uri (uri));
        }

        playbin.set_state (Gst.State.PLAYING);
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
        if (playing) {
            playbin.set_state (Gst.State.NULL);
            set_position (get_duration ());
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

    // public unowned List<string> get_audio_tracks () {
    //     return playbin.get_audio_streams ();
    // }

    // public unowned List<string> get_subtitle_tracks () {
    //     return playbin.get_subtitle_tracks ();
    // }

    public string get_uri () {
        return playbin.uri;
    }

    public bool get_playing () {
        return playing;
    }

    public int64 get_duration () {
        int64 duration = 0;

        if (!playbin.query_duration (Gst.Format.TIME, out duration)) {
            warning ("Failed to get duration of stream.");
        }

        return duration;
    }

    public int get_audio_track () {
        return playbin.current_audio;
    }

    public void set_audio_track (int track) {
        playbin.current_audio = track;
    }

    public int64 get_position () {
        int64 position = 0;

        if (!playbin.query_position (Gst.Format.TIME, out position)) {
            warning ("Failed to get duration of stream.");
        }

        return position;
    }

    public void set_position (int64 position) {
        playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.ACCURATE, position);
    }

    public int get_subtitle_track () {
        return playbin.current_text;
    }

    public void set_subtitle_track (int track) {
        playbin.current_text = track;
    }

    public void set_subtitle (string uri) {
        // var progress = playbin.progress;
        // var is_playing = playbin.playing;

        /* Temporarily connect to the ready signal so that we can restore the progress setting
         * after resetting the playbin in order to set the subtitle uri */
        // ready_handler_id = playbin.ready.connect (() => {
        //     playbin.progress = progress;
        //     // Pause video if it was in Paused state before adding the subtitle
        //     if (!is_playing) {
        //         playbin.set_state (Gst.State.PAUSED);
        //     }

        //     playbin.disconnect (ready_handler_id);
        // });

        playbin.set_state (Gst.State.NULL); // Does not work otherwise
        playbin.suburi = uri;
        playbin.set_state (Gst.State.PLAYING);

        settings.set_string ("current-external-subtitles-uri", uri);
    }

    private string get_subtitle_for_uri (string uri) {
        /* This assumes that the subtitle file has the same basename as the video file but with
         * one of the subtitle extensions, and is in the same folder. */
        string without_ext;
        int last_dot = uri.last_index_of (".", 0);
        int last_slash = uri.last_index_of ("/", 0);

        if (last_dot < last_slash) {//we dont have extension
            without_ext = uri;
        } else {
            without_ext = uri.slice (0, last_dot);
        }

        foreach (string ext in SUBTITLE_EXTENSIONS) {
            string sub_uri = without_ext + "." + ext;
            if (File.new_for_uri (sub_uri).query_exists ()) {
                return sub_uri;
            }
        }

        return "";
    }
}
