

namespace Audience.Widgets {

    public class Playlist : Gtk.TreeView {

        /*the player is requested to play path*/
        public signal void play (File path);

        private int                 current;
        private Gtk.ListStore       playlist;

        public Playlist () {
            this.current  = 0;
            this.playlist = new Gtk.ListStore (3, typeof (Icon),  /*playing*/
                                                  typeof (string),      /*title*/
                                                  typeof (string));     /*filename*/
            this.model = this.playlist;
            this.expand = true;
            this.headers_visible = false;
            this.activate_on_single_click = true;
            this.can_focus = false;
            get_selection ().mode = Gtk.SelectionMode.NONE;

            var text_render = new Gtk.CellRendererText ();
            text_render.ellipsize = Pango.EllipsizeMode.END;

            this.insert_column_with_attributes (-1, "", new Gtk.CellRendererPixbuf (), "gicon", 0);
            this.insert_column_with_attributes (-1, "", text_render, "text", 1);

            this.row_activated.connect ( (path ,col) => {
                Gtk.TreeIter iter;
                playlist.get_iter (out iter, path);
                string filename;
                playlist.get (iter, 2, out filename);
                play (File.new_for_commandline_arg (filename));
                change_current_symbol (iter);
                this.current = int.parse (path.to_string ());
            });

            this.reorderable = true;
            this.model.row_inserted.connect ( (path, iter) => {
                Gtk.TreeIter it;
                playlist.get_iter (out it, path);
                Gdk.Pixbuf playing;
                playlist.get (it, 0, out playing);
                if (playing != null) //if playing is not null it's the current item
                    this.current = int.parse (path.to_string ());
            });
        }

        private inline void change_current_symbol (Gtk.TreeIter new_item) {
            Gtk.TreeIter old_item;
            playlist.get_iter_from_string (out old_item, this.current.to_string ());
            playlist.set (old_item, 0, null);
            playlist.set (new_item, 0, new ThemedIcon ("media-playback-start-symbolic"));
        }

        public void next () {
            Gtk.TreeIter it;
            if (playlist.get_iter_from_string (out it, (this.current + 1).to_string ())){
                string filename;
                playlist.get (it, 2, out filename);
                change_current_symbol (it);
                current++;
                play (File.new_for_commandline_arg (filename));
            }
        }

        public void previous () {
            Gtk.TreeIter it;
            if (playlist.get_iter_from_string (out it, (this.current - 1).to_string ())){
                string filename;
                playlist.get (it, 2, out filename);
                change_current_symbol (it);
                current--;
                play (File.new_for_commandline_arg (filename));
            }
        }

        public void add_item (File path) {
            Gtk.TreeIter iter;

            Icon? playing = null;
            Gtk.TreeIter dummy;
            if (!playlist.get_iter_first (out dummy)){
                playing = new ThemedIcon ("media-playback-start-symbolic");
            } else {
                playing = null;
            }

            playlist.append (out iter);
            playlist.set (iter, 0, playing, 1, Audience.get_title (path.get_basename ()), 2, path.get_path ());
        }

        public void remove_item (File path) {
            /*not needed up to now*/
        }

        public File? get_first_item () {
            Gtk.TreeIter iter;
            if (playlist.get_iter_first (out iter)){
                string filename;
                playlist.get (iter, 2, out filename);
                return File.new_for_commandline_arg (filename);
            }
            return null;
        }

        public List<string> get_all_items () {
            var list = new List<string> ();
            playlist.foreach ((model, path, iter) => {
                Value filename;
                playlist.get_value (iter, 2, out filename);
                string name = filename.get_string ();
                list.append (name);
                return false;
            });
            return list.copy ();
        }

        public void save_playlist_config () {
            var list = new List<string> ();
            playlist.foreach ((model, path, iter) => {
                Value filename;
                playlist.get_value (iter, 2, out filename);
                string name = filename.get_string ();
                list.append (name);
                return false;
            });

            uint i = 0;
            //settings.last_played_videos = new string[list.length ()];
            foreach (var filename in list) {
                settings.last_played_videos[i] = filename;
                i++;
            }
        }

    }

}