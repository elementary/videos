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

public class Audience.Widgets.BottomBar : Gtk.EventBox {
    public bool should_stay_revealed {
        get {
            var play_pause_action = Application.get_default ().lookup_action (Audience.App.ACTION_PLAY_PAUSE);
            return hovered || playlist_popover.visible || settings_popover.visible ||
                !play_pause_action.get_state ().get_boolean ();
        }
    }

    private Videos.SeekBar seek_bar;
    private PlaylistPopover playlist_popover;
    private SettingsPopover settings_popover;
    private bool hovered;

    construct {
        var play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON) {
            action_name = App.ACTION_PREFIX + App.ACTION_PLAY_PAUSE,
            tooltip_text = _("Play")
        };

        playlist_popover = new PlaylistPopover ();

        var playlist_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("view-list-symbolic", Gtk.IconSize.SMALL_TOOLBAR),
            popover = playlist_popover,
            tooltip_text = _("Playlist")
        };

        settings_popover = new SettingsPopover ();

        var settings_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.SMALL_TOOLBAR),
            popover = settings_popover,
            tooltip_text = _("Settings")
        };

        seek_bar = new Videos.SeekBar ();

        var main_actionbar = new Gtk.ActionBar ();
        main_actionbar.pack_start (play_button);
        main_actionbar.set_center_widget (seek_bar);
        main_actionbar.pack_end (settings_button);
        main_actionbar.pack_end (playlist_button);

        child = main_actionbar;
        show_all ();

        events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        events |= Gdk.EventMask.ENTER_NOTIFY_MASK;

        playlist_popover.notify["visible"].connect (() => notify_property ("should-stay-revealed"));
        settings_popover.notify["visible"].connect (() => notify_property ("should-stay-revealed"));

        enter_notify_event.connect ((event) => {
            if (event.window == get_window ()) {
                hovered = true;
                notify_property ("should-stay-revealed");
            }
            return false;
        });

        leave_notify_event.connect ((event) => {
            if (event.window == get_window () && event.detail != INFERIOR) {
                hovered = false;
                notify_property ("should-stay-revealed");
            }
            return false;
        });

        GLib.Application.get_default ().action_state_changed.connect ((name, new_state) => {
            if (name == Audience.App.ACTION_PLAY_PAUSE) {
                if (new_state.get_boolean () == false) {
                    ((Gtk.Image) play_button.image).icon_name = "media-playback-start-symbolic";
                    play_button.tooltip_text = _("Play");
                } else {
                    ((Gtk.Image) play_button.image).icon_name = "media-playback-pause-symbolic";
                    play_button.tooltip_text = _("Pause");
                }
                notify_property ("should-stay-revealed");
            }
        });
    }

    public void hide_popovers () {
        playlist_popover.popdown ();

        var popover = seek_bar.preview_popover;
        if (popover != null) {
            popover.schedule_hide ();
        }
    }
}
