/*-
 * Copyright 2013-2021 elementary, Inc. (https://elementary.io)
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
 *              Artem Anufrij <artem.anufrij@live.de>
 */

public class Audience.Widgets.BottomBar : Gtk.Box {
    public bool popover_open {
        get {
            return playlist_popover.visible;
        }
    }

    private const string PULSE_CLASS = "pulse";
    private const string PULSE_TYPE = "attention";

    private PlaylistPopover playlist_popover;
    public Videos.SeekBar time_widget { get; private set; }

    private Gtk.Button play_button;
    private SettingsPopover preferences_popover;
    private Gtk.MenuButton playlist_button;
    private uint hiding_timer = 0;
    private bool playlist_glowing = false;

    public BottomBar () {
        var playback_manager = PlaybackManager.get_default ();

        play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic") {
            action_name = App.ACTION_PREFIX + App.ACTION_PLAY_PAUSE,
            tooltip_text = _("Play")
        };

        playlist_popover = new PlaylistPopover ();

        playlist_button = new Gtk.MenuButton () {
            icon_name = "view-list-symbolic",
            popover = playlist_popover,
            tooltip_text = _("Playlist")
        };

        preferences_popover = new SettingsPopover ();

        var preferences_button = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            popover = preferences_popover,
            tooltip_text = _("Settings")
        };

        time_widget = new Videos.SeekBar ();

        // var main_actionbar = new Gtk.ActionBar ();
        append (play_button);
        append (time_widget);
        append (preferences_button);
        append (playlist_button);

        // show_all ();

        // transition_type = Gtk.RevealerTransitionType.SLIDE_UP;

        // events |= Gdk.EventMask.POINTER_MOTION_MASK;
        // events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        // events |= Gdk.EventMask.ENTER_NOTIFY_MASK;

        // enter_notify_event.connect ((event) => {
        //     if (event.window == get_window ()) {
        //         hovered = true;
        //     }
        //     return false;
        // });

        // leave_notify_event.connect ((event) => {
        //     if (event.window == get_window ()) {
        //         hovered = false;
        //     }
        //     return false;
        // });

        PlaybackManager.get_default ().item_added.connect (() => {
            playlist_item_added ();
        });

        GLib.Application.get_default ().action_state_changed.connect ((name, new_state) => {
            if (name == Audience.App.ACTION_PLAY_PAUSE) {
                if (!new_state.get_boolean ()) {
                    play_button.icon_name = "media-playback-start-symbolic";
                    play_button.tooltip_text = _("Play");
                } else {
                    play_button.icon_name = "media-playback-pause-symbolic";
                    play_button.tooltip_text = _("Pause");
                }
            }
        });
    }

    private void playlist_item_added () {
        if (!playlist_glowing) {
            playlist_glowing = true;
            playlist_button.get_child ().add_css_class (PULSE_CLASS);
            playlist_button.get_child ().add_css_class (PULSE_TYPE);

            Timeout.add (6000, () => {
                playlist_button.get_child ().remove_css_class (PULSE_CLASS);
                playlist_button.get_child ().remove_css_class (PULSE_TYPE);
                playlist_glowing = false;
                return false;
            });
        }
    }
}
