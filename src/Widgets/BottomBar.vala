// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013-2014 Audience Developers (http://launchpad.net/pantheon-chat)
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
    public signal void play_toggled ();
    public signal void unfullscreen ();
    public signal void seeked (double val);

    public bool hovered { get; set; default=false; }
    public bool fullscreen { get; set; default=false; }
    public SettingsPopover preferences_popover;
    public PlaylistPopover playlist_popover;
    public TimeWidget time_widget;

    private Widgets.VideoPlayer player;
    private Gtk.Button play_button;
    private Gtk.Button preferences_button;
    private Gtk.Revealer unfullscreen_revealer;
    private bool is_playing = false;
    private uint hiding_timer = 0;

    public BottomBar (Widgets.VideoPlayer player) {
        this.player = player;

        this.events |= Gdk.EventMask.POINTER_MOTION_MASK;
        this.events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        this.events |= Gdk.EventMask.ENTER_NOTIFY_MASK;

        this.enter_notify_event.connect ((event) => { this.hovered = true; return false; });
        this.leave_notify_event.connect ((event) => { this.hovered = false; return false; });

        this.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;

        var main_actionbar = new Gtk.ActionBar ();

        play_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
        play_button.tooltip_text = _("Play");
        play_button.clicked.connect (() => {play_toggled ();});

        var playlist_button = new Gtk.Button.from_icon_name ("view-list-symbolic", Gtk.IconSize.BUTTON);
        playlist_button.tooltip_text = _("Playlist");
        playlist_button.clicked.connect (() => {playlist_popover.show_all (); playlist_popover.queue_resize ();});

        preferences_button = new Gtk.Button.from_icon_name ("open-menu-symbolic", Gtk.IconSize.BUTTON);
        preferences_button.tooltip_text = _("Settings");
        preferences_button.clicked.connect (() => {preferences_popover.show_all (); preferences_popover.queue_resize ();});

        time_widget = new TimeWidget ();
        time_widget.seeked.connect ((val) => {seeked (val);});

        playlist_popover = new PlaylistPopover ();
        playlist_popover.relative_to = playlist_button;
        preferences_popover = new SettingsPopover (player);
        preferences_popover.relative_to = preferences_button;

        main_actionbar.pack_start (play_button);
        main_actionbar.set_center_widget (time_widget);
        main_actionbar.pack_end (preferences_button);
        main_actionbar.pack_end (playlist_button);
        add (main_actionbar);

        notify["hovered"].connect (() => {
            if (hovered == false) {
                reveal_control ();
            } else {
                if (hiding_timer != 0) {
                    Source.remove (hiding_timer);
                    hiding_timer = 0;
                }
            }
        });

        notify["fullscreen"].connect (() => {
            if (fullscreen == true && child_revealed == true) {
                unfullscreen_revealer.set_reveal_child (true);
            } else if (fullscreen == false && child_revealed == true) {
                unfullscreen_revealer.set_reveal_child (false);
            }
        });

        show_all ();
    }

    public void set_preview_uri (string uri) {
        time_widget.set_preview_uri (uri);
    }

    public bool get_repeat () {
        return playlist_popover.rep.active;
    }

    public void set_repeat (bool repeat) {
        playlist_popover.rep.active = repeat;
    }

    public Gtk.Revealer get_unfullscreen_button () {
        unfullscreen_revealer = new Gtk.Revealer ();
        unfullscreen_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;

        var unfullscreen_button = new Gtk.Button.from_icon_name ("view-restore-symbolic", Gtk.IconSize.BUTTON);
        unfullscreen_button.tooltip_text = _("Unfullscreen");
        unfullscreen_button.clicked.connect (() => {unfullscreen ();});
        unfullscreen_revealer.add (unfullscreen_button);
        unfullscreen_revealer.show_all ();
        return unfullscreen_revealer;
    }

    public void toggle_play_pause () {
        is_playing = !is_playing;
        if (is_playing == true) {
            play_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            play_button.tooltip_text = _("Pause");
            reveal_control ();
        } else {
            play_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.BUTTON);
            play_button.tooltip_text = _("Play");
            set_reveal_child (true);
        }
    }

    private new void set_reveal_child (bool reveal) {
        base.set_reveal_child (reveal);
        if (reveal == true && fullscreen == true) {
            unfullscreen_revealer.set_reveal_child (reveal);
        } else if (reveal == false) {
            unfullscreen_revealer.set_reveal_child (reveal);
        }
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);
        if (parent.get_window () == null)
            return;

        var width = parent.get_window ().get_width ();
        if (width > 0 && width >= minimum_width) {
            natural_width = width;
        }
    }

    public void set_progression_time (double current_time, double total_time) {
        time_widget.set_progression_time (current_time, total_time);
    }

    public void reveal_control () {
        if (child_revealed == false)
            set_reveal_child (true);

        if (hiding_timer != 0)
            Source.remove (hiding_timer);

        hiding_timer = GLib.Timeout.add (2000, () => {
            if (hovered == true || preferences_popover.visible == true || playlist_popover.visible == true || is_playing == false) {
                hiding_timer = 0;
                return false;
            }
            set_reveal_child (false);
            unfullscreen_revealer.set_reveal_child (false);
            hiding_timer = 0;
            return false;
        });
    }
}
