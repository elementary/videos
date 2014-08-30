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
 * Authored by: Tom Beckmann <tomjonabc@gmail.com>
 */

public class Audience.Settings : Granite.Services.Settings {
    public bool move_window {get; set;}
    public bool keep_aspect {get; set;}
    public bool resume_videos {get; set;}
    public string[] last_played_videos {get; set;}
    public string current_video {get; set;}
    public double last_stopped {get; set;}
    public string last_folder {get; set;}
    public bool playback_wait {get; set;}
    public bool stay_on_top {get; set;}
    public bool show_window_decoration {get; set;}

    public Settings () {
        base ("org.pantheon.audience");
    }

}
