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

public class Audience.Widgets.BottomBar : Gtk.Revealer {
    public PlaylistPopover playlist_popover { get; private set; }
    public Videos.SeekBar time_widget { get; private set; }

    private SettingsPopover preferences_popove
    private Gtk.Button play_button;
    private Gtk.MenuButton playlist_button;
    private uint hiding_timer = 0;

    private bool _hovered = false;
    private bool hovered {
        get {
            return _hovered;
        }
        set {
            _hovered = value;
            if (value) {
                if (hiding_timer != 0) {
                    Source.remove (hiding_timer);
                    hiding_timer = 0;
                }
            } else {
                reveal_control ();
            }
        }
    }

    public BottomBar () {
        play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON) {
            action_name = App.ACTION_PREFIX + App.ACTION_PLAY_PAUSE,
            tooltip_text = _("Play")
        };

        playlist_popover = new PlaylistPopover ();

        playlist_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("view-list-symbolic", Gtk.IconSize.SMALL_TOOLBAR),
            popover = playlist_popover,
            tooltip_text = _("Playlist")
        };

        preferences_popover = new SettingsPopover ();

        var preferences_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.SMALL_TOOLBAR),
            popover = preferences_popover,
            tooltip_text = _("Settings")
        };

        time_widget = new Videos.SeekBar ();

        var main_actionbar = new Gtk.ActionBar ();
        main_actionbar.pack_start (play_button);
        main_actionbar.set_center_widget (time_widget);
        main_actionbar.pack_end (preferences_button);
        main_actionbar.pack_end (playlist_button);

        add (main_actionbar);

        show_all ();

        transition_type = Gtk.RevealerTransitionType.SLIDE_UP;

        events |= Gdk.EventMask.POINTER_MOTION_MASK;
        events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        events |= Gdk.EventMask.ENTER_NOTIFY_MASK;

        enter_notify_event.connect ((event) => {
            if (event.window == get_window ()) {
                hovered = true;
            }
            return false;
        });

        leave_notify_event.connect ((event) => {
            if (event.window == get_window ()) {
                hovered = false;
            }
            return false;
        });

        GLib.Application.get_default ().action_state_changed.connect ((name, new_state) => {
            if (name == Audience.App.ACTION_PLAY_PAUSE) {
                if (new_state.get_boolean () == false) {
                    ((Gtk.Image) play_button.image).icon_name = "media-playback-start-symbolic";
                    play_button.tooltip_text = _("Play");
                    reveal_child = true;
                } else {
                    ((Gtk.Image) play_button.image).icon_name = "media-playback-pause-symbolic";
                    play_button.tooltip_text = _("Pause");
                    reveal_control ();
                }
            }
        });
    }

    public void reveal_control () {
        if (child_revealed == false) {
            set_reveal_child (true);
        }

        if (hiding_timer != 0) {
            Source.remove (hiding_timer);
        }

        var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);

        hiding_timer = GLib.Timeout.add (2000, () => {
            if (hovered || preferences_popover.visible || playlist_popover.visible || !play_pause_action.get_state ().get_boolean ()) {
                hiding_timer = 0;
                return false;
            }
            set_reveal_child (false);
            hiding_timer = 0;
            return false;
        });
    }
}
