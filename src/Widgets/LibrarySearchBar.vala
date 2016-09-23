// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2016 elementary LLC.
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
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 *
 */

namespace Audience {
    public class LibrarySearchBar : Gtk.Toolbar {
        private Gtk.ToolItem tool_search_entry;
        public Gtk.SearchEntry search_entry;

        construct {
            set_style (Gtk.ToolbarStyle.ICONS);
            get_style_context ().add_class ("search-bar");

            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Find");
            search_entry.width_request = 250;
            search_entry.margin_left = 6;
            search_entry.search_changed.connect (() => {Audience.LibraryPage.get_instance ().filter ();});

            tool_search_entry = new Gtk.ToolItem ();
            tool_search_entry.add (search_entry);

            add (tool_search_entry);
        }
    }
}
