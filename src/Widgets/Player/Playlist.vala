/*
* Copyright 2019 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/

public class Audience.Widgets.Playlist : Gtk.ListBox {
    public signal void play (File path);
    public signal void item_added ();

        public Playlist () {
            Object (
                can_focus: true,
                expand: true,
                selection_mode: Gtk.SelectionMode.BROWSE
            );
        }

        public bool next () {

            return false;
        }

        public void previous () {

        }

        public void add_item (File path) {
            if (!path.query_exists ()) {
                return;
            }

            var file_name = path.get_uri ();
            bool exist = false;

            foreach (Gtk.Widget item in get_children ()) {
                string name = (item as PlaylistItem).filename;
                if (name == file_name) {
                    exist = true;
                }
            }

            if (exist) {
                return;
            }

            var row = new PlaylistItem (false, Audience.get_title (path.get_basename ()), path.get_uri ());
            add (row);
            item_added ();
        }

        public void remove_item (File path) {

        }

        public void clear_items () {

        }

        public File? get_first_item () {

            return null;
        }

        public int get_current () {

            return 0;
        }

        public void set_current (string current_file) {


        }

        public List<string> get_all_items () {
            var list = new List<string> ();

            return list;
        }

        public void save_playlist () {

        }

        private void restore_playlist () {

        }
}
