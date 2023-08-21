/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

public class Audience.PlaybackManager : Object {
    public signal void ended ();
    public signal void item_added (string item_title);
    public signal void next_audio ();
    public signal void next_text ();
    public signal void play (File file);
    public signal void uri_changed (string uri);

    public Gdk.Paintable gst_video_widget { get; construct; }
    public string? subtitle_uri { get; private set; default = ""; }
    public bool playing { get; private set; }
    public int64 duration { get; private set; default = 0; }
    public int64 position { get; private set; default = 0; }

    public ListStore play_queue { get; private set; }

    private dynamic Gst.Element playbin;
    private bool is_seeking = false;
    private int64 queued_seek = -1;

    private uint inhibit_token = 0;

    private static GLib.Once<PlaybackManager> instance;
    public static unowned PlaybackManager get_default () {
        return instance.once (() => { return new PlaybackManager (); });
    }

    construct {
        play_queue = new ListStore (typeof (File));

        var gtksink = Gst.ElementFactory.make ("gtk4paintablesink", "sink");
        Gdk.Paintable _gst_video_widget;
        gtksink.get ("paintable", out _gst_video_widget);
        gst_video_widget = _gst_video_widget;

        playbin = Gst.ElementFactory.make ("playbin", "bin");
        playbin.video_sink = gtksink;

        var bus = playbin.get_bus ();
        bus.add_signal_watch ();
        bus.message.connect (handle_bus_message);

        playbin.notify["suburi"].connect (() => {
            if (subtitle_uri != (string)playbin.suburi) {
                subtitle_uri = playbin.suburi;
            }
        });

        playbin.notify["uri"].connect (() => {
            uri_changed (playbin.uri);
        });

        unowned var default_application = (Gtk.Application) Application.get_default ();

        default_application.action_state_changed.connect ((name, new_state) => {
            if (name == Audience.App.ACTION_PLAY_PAUSE) {
                var should_play = new_state.get_boolean ();

                if (playing != should_play) {
                    playbin.set_state (should_play ? Gst.State.PLAYING : Gst.State.PAUSED);
                }
            }
        });

        notify["playing"].connect (() => {
            var play_pause_action = default_application.lookup_action (Audience.App.ACTION_PLAY_PAUSE);
            ((SimpleAction) play_pause_action).set_state (playing);
            update_position ();
        });

        Timeout.add (500, () => {
            update_position ();
            return Source.CONTINUE;
        });
    }

    ~PlaybackManager () {
        if (duration == position) {
            settings.set_int64 ("last-stopped", 0);
        } else if ((string)playbin.current_uri != "") {
            /* The progress is only valid if the uri has not been reset as the current video setting is not
             * updated.  The playbin.uri has been reset when the window is destroyed from the Welcome page */
            settings.set_int64 ("last-stopped", position);
        }

        save_playlist ();

        if (inhibit_token != 0) {
            ((Gtk.Application) GLib.Application.get_default ()).uninhibit (inhibit_token);
            inhibit_token = 0;
        }
    }

    private void handle_bus_message (Gst.Message message) {
        unowned var default_application = (Gtk.Application) Application.get_default ();

        switch (message.type) {
            case EOS:
                if (!next ()) {
                    var repeat_action = default_application.lookup_action (Audience.App.ACTION_REPEAT);
                    if (repeat_action.get_state ().get_boolean ()) {
                        var file = (File) play_queue.get_item (0);
                        ((Audience.Window) default_application.active_window).open_files ({ file });
                    } else {
                        playbin.set_state (Gst.State.NULL);
                        settings.set_int64 ("last-stopped", 0);
                        position = 0;
                        duration = 0;
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

                if (old_state == Gst.State.READY && new_state == Gst.State.PAUSED) {
                    int64 _duration;
                    if (playbin.query_duration (Gst.Format.TIME, out _duration)) {
                        duration = _duration;
                    }

                    if (queued_seek >= 0) {
                        seek (queued_seek);
                    }
                }

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

            case ASYNC_DONE:
                if (is_seeking) {
                    is_seeking = false;

                    update_position ();

                    if (queued_seek >= 0) {
                        seek (queued_seek);
                    }
                }
                break;

            default:
                break;
        }
    }

    public void play_file (string uri, bool from_beginning = true) {
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
            seek (0);
        } else {
            seek (settings.get_int64 ("last-stopped"));
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
            seek (duration);
            ended ();
        }
    }

    public void clear_playlist (bool should_stop = true) {
        play_queue.remove_all ();

        if (should_stop) {
            stop ();
        }
    }

    public void append_to_playlist (File[] files) {
        Object[] files_to_queue = {};

        foreach (var file in files) {
            if (is_subtitle (file.get_uri ())) {
                subtitle_uri = file.get_uri ();
            } else {
                files_to_queue += file;
            }
        }

        play_queue.splice (play_queue.get_n_items () > 0 ? play_queue.get_n_items () - 1 : 0, 0, files_to_queue);
    }

    public void save_playlist () {
        var privacy_settings = new GLib.Settings ("org.gnome.desktop.privacy");
        if (!privacy_settings.get_boolean ("remember-recent-files") || !privacy_settings.get_boolean ("remember-app-usage")) {
            return;
        }

        string[] videos = {};
        for (int i = 0; i < play_queue.get_n_items () - 1; i++) {
            videos += ((File) play_queue.get_item (i)).get_uri ();
        }

        settings.set_strv ("last-played-videos", videos);
    }

    public bool next () {
        uint position;
        play_queue.find (File.new_for_uri (playbin.current_uri), out position);

        if (position < play_queue.get_n_items () - 1) {
            play ((File) play_queue.get_item (position + 1));
            return true;
        } else {
            return false;
            // play ((File) play_queue.get_item (0));
        }
    }

    public void previous () {
        uint position;
        play_queue.find_with_equal_func (File.new_for_uri (playbin.current_uri), file_equal_func, out position);
        print (position.to_string ());

        if (position == 0) {
            seek (0);
        } else {
            play ((File) play_queue.get_item (position - 1));
        }
    }

    public void seek (int64 position) {
        Gst.State state, pending;
        playbin.get_state (out state, out pending, 0);

        if (is_seeking || (state != Gst.State.PAUSED && state != Gst.State.PLAYING)) {
            queued_seek = position;
            return;
        }

        if (playbin.seek_simple (Gst.Format.TIME, Gst.SeekFlags.FLUSH | Gst.SeekFlags.ACCURATE, position)) {
            is_seeking = true;
        } else {
            warning ("Failed to seek.");
        }

        queued_seek = -1;
    }

    private void update_position () {
        int64 _position;
        if (playbin.query_position (Gst.Format.TIME, out _position)) {
            position = _position;
        } else {
            position = 0;
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

    public List<string> get_audio_tracks () {
        var list = new List<string> ();

        for (int i = 0; i < (int)playbin.n_audio; i++) {
            Gst.TagList tag_list;
            Signal.emit_by_name (playbin, "get-audio-tags", i, out tag_list);

            string lang_code;
            tag_list.get_string ("language-code", out lang_code);

            list.append (lang_code);
        }

        return list;
    }

    public List<string> get_subtitle_tracks () {
        var list = new List<string> ();

        for (int i = 0; i < (int)playbin.n_text; i++) {
            Gst.TagList tag_list;
            Signal.emit_by_name (playbin, "get-text-tags", i, out tag_list);

            string lang_code;
            tag_list.get_string ("language-code", out lang_code);

            list.append (lang_code);
        }

        return list;
    }

    public string get_uri () {
        return playbin.current_uri;
    }

    public int get_audio_track () {
        return playbin.current_audio;
    }

    public void set_audio_track (int track) {
        playbin.current_audio = track;
    }

    public int get_subtitle_track () {
        return playbin.current_text;
    }

    public void set_subtitle_track (int track) {
        playbin.current_text = track;
    }

    public void set_subtitle (string uri) {
        Gst.State state, pending;
        playbin.get_state (out state, out pending, 0);
        if (state == Gst.State.PAUSED || state == Gst.State.PLAYING) {
            var temp_playing = playing;
            var temp_position = position;

            /* Temporarily connect to the playing change so that we can restore the progress setting
             * after resetting the playbin in order to set the subtitle uri */
            ulong ready_handler_id = 0;
            ready_handler_id = notify["playing"].connect (() => {
                if (!playing) {
                    return;
                }

                disconnect (ready_handler_id);

                seek (temp_position);

                // Pause video if it was in Paused state before adding the subtitle
                if (!temp_playing) {
                    playbin.set_state (Gst.State.PAUSED);
                }
            });
        }

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
