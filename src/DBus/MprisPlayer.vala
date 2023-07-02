/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "org.mpris.MediaPlayer2.Player")]
public class Videos.MprisPlayer : Object {
    [DBus (visible = false)]
    public unowned DBusConnection connection { get; construct; }

    public bool can_go_next { get; set; }
    public bool can_go_previous { get; set; }
    public bool can_play { get; set; }

    public string playback_status {
        get {
            var state = (bool) application.lookup_action (Audience.App.ACTION_PLAY_PAUSE).state;
            if (state == false) {
                return "Stopped";
            } else {
                return "Playing";
            }
        }
    }

    public HashTable<string, Variant>? metadata {
        owned get {
            var _metadata = new HashTable<string, Variant> (null, null);
            // FIXME: Store currently playing metadata somewhere. Yikes.
            _metadata.insert ("xesam:title", ((Gtk.Application) application).active_window.title);

            return _metadata;
        }
    }

    private GLib.Application application;
    // private Audience.Widgets.Playlist playlist;

    public MprisPlayer (DBusConnection connection) {
        Object (connection: connection);
    }

    construct {
        application = GLib.Application.get_default ();

        application.action_state_changed.connect ((name, new_state) => {
            if (name == Audience.App.ACTION_PLAY_PAUSE) {
                send_property_change ("PlaybackStatus", playback_status);
            }

            send_property_change ("Metadata", metadata);
        });

        var action_next = application.lookup_action (Audience.App.ACTION_NEXT);
        action_next.bind_property ("enabled", this, "can-go-next", BindingFlags.SYNC_CREATE);

        var action_play_pause = application.lookup_action (Audience.App.ACTION_PLAY_PAUSE);
        action_play_pause.bind_property ("enabled", this, "can-play", BindingFlags.SYNC_CREATE);

        var action_previous = application.lookup_action (Audience.App.ACTION_PREVIOUS);
        action_previous.bind_property ("enabled", this, "can-go-previous", BindingFlags.SYNC_CREATE);

        notify["can-go-next"].connect (() => send_property_change ("CanGoNext", can_go_next));
        notify["can-go-previous"].connect (() => send_property_change ("CanGoPrevious", can_go_previous));
        notify["can-play"].connect (() => send_property_change ("CanPlay", can_play));
    }

    private void send_property_change (string name, Variant variant) {
        var invalid_builder = new VariantBuilder (new VariantType ("as"));

        var builder = new VariantBuilder (VariantType.ARRAY);
        builder.add ("{sv}", name, variant);

        try {
            connection.emit_signal (
                null,
                "/org/mpris/MediaPlayer2",
                "org.freedesktop.DBus.Properties",
                "PropertiesChanged",
                new Variant (
                    "(sa{sv}as)",
                    "org.mpris.MediaPlayer2.Player",
                    builder,
                    invalid_builder
                )
            );
        } catch (Error e) {
            critical ("Could not send MPRIS property change: %s", e.message);
        }
    }

    public void next () throws GLib.Error {
        application.activate_action (Audience.App.ACTION_NEXT, null);
    }

    public void previous () throws GLib.Error {
        application.activate_action (Audience.App.ACTION_PREVIOUS, null);
    }

    public void play_pause () throws GLib.Error {
        application.activate_action (Audience.App.ACTION_PLAY_PAUSE, null);
    }
}
