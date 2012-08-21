

namespace Audience.Widgets {

    public class Playlist : Gtk.TreeView {

        /*the player is requested to play path*/
        public signal void play (File path);

        private int                 current;
        private Gtk.ListStore       playlist;

        public Playlist () {
            this.current  = 0;
            this.playlist = new Gtk.ListStore (4, typeof (Gdk.Pixbuf),  /*playing*/
                                                  typeof (Gdk.Pixbuf),  /*icon*/
                                                  typeof (string),      /*title*/
                                                  typeof (string));     /*filename*/
            this.model = this.playlist;
            this.expand = true;
            this.headers_visible = false;

            var text_render = new Gtk.CellRendererText ();
            text_render.ellipsize = Pango.EllipsizeMode.END;

            this.insert_column_with_attributes (-1, "", new Gtk.CellRendererPixbuf (),
                "pixbuf", 0);
            this.insert_column_with_attributes (-1, "", new Gtk.CellRendererPixbuf (),
                "pixbuf", 1);
            this.insert_column_with_attributes (-1, "", text_render, "text", 2);

            this.row_activated.connect ( (path ,col) => {
                Gtk.TreeIter iter;
                playlist.get_iter (out iter, path);
                string filename;
                playlist.get (iter, 3, out filename);
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

            var css_fix = new Gtk.CssProvider ();
            try {
                css_fix.load_from_data ("
                    * {
                        background-image:none;
                        background-color:@transparent;
                        border-color:@transparent;
                    }", -1);
            } catch (Error e) { warning (e.message); }
            this.get_style_context ().add_provider (css_fix, 20000);
        }

        private inline void change_current_symbol (Gtk.TreeIter new_item) {
            try{
                playlist.set (new_item, 0, Gtk.IconTheme.get_default ().
                    load_icon ("media-playback-start-symbolic", 16, 0));
            }catch (Error e) { warning (e.message); }
            Gtk.TreeIter old_item;
            playlist.get_iter_from_string (out old_item, this.current.to_string ());
            playlist.set (old_item, 0, null);
        }

        public void next () {
            Gtk.TreeIter it;
            if (playlist.get_iter_from_string (out it, (this.current + 1).to_string ())){
                string filename;
                playlist.get (it, 3, out filename);
                change_current_symbol (it);
                current++;
                play (File.new_for_commandline_arg (filename));
            }
        }

        public void previous () {
            Gtk.TreeIter it;
            if (playlist.get_iter_from_string (out it, (this.current - 1).to_string ())){
                string filename;
                playlist.get (it, 3, out filename);
                change_current_symbol (it);
                current--;
                play (File.new_for_commandline_arg (filename));
            }
        }

        public void add_item (File path) {
            Gtk.TreeIter iter;
            Gdk.Pixbuf pix = null; //may becoming the thumb...

            Gdk.Pixbuf? playing = null;
            Gtk.TreeIter dummy;
            if (!playlist.get_iter_first (out dummy)){ //first item
                try {
                    playing = Gtk.IconTheme.get_default ().lookup_icon ("media-playback-start-symbolic",
                        16, 0).load_symbolic ({0, 0, 0, 255}, null, null, null);
                } catch (Error e) { warning (e.message); }
            } else {
                playing = null;
            }

            playlist.append (out iter);
            playlist.set (iter, 0, playing, 1, pix,
                                2, Audience.get_title (path.get_basename ()), 3, path.get_path ());
        }

        public void remove_item (File path) {
            /*not needed up to now*/
        }
        public File? get_first_item () {
            Gtk.TreeIter it;
            if (playlist.get_iter_from_string (out it, 0.to_string ())){
                string filename;
                playlist.get (it, 3, out filename);
                return File.new_for_commandline_arg (filename);
            }
            return null;
        }

    }

}
