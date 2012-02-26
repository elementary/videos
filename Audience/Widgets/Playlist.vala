

namespace Audience.Widgets {
    
    struct Item {
        File path;
        Gtk.TreeIter iter;
    }
    
    public class Playlist : Gtk.TreeView{
        
        /*the player is requested to play path*/
        public signal void play (File path);
        
        private unowned List<Item?> current;
        private List<Item?>         files;
        private Gtk.ListStore       playlist;
        
        public Playlist (){
            files    = new List<Item?> ();
            this.playlist = new Gtk.ListStore (4, typeof (Gdk.Pixbuf),  /*playing*/
                                                  typeof (Gdk.Pixbuf),  /*icon*/
                                                  typeof (string),      /*title*/
                                                  typeof (string));     /*filename*/
            this.model = this.playlist;
            this.expand = true;
            this.headers_visible = false;
            this.insert_column_with_attributes (-1, "", new Gtk.CellRendererPixbuf (),
                "pixbuf", 0);
            this.insert_column_with_attributes (-1, "", new Gtk.CellRendererPixbuf (),
                "pixbuf", 1);
            this.insert_column_with_attributes (-1, "", new Gtk.CellRendererText (),
                "text", 2);
            
            this.row_activated.connect ( (path ,col) => {
                Gtk.TreeIter iter;
                playlist.get_iter (out iter, path);
                string filename;
                playlist.get (iter, 3, out filename);
                play (File.new_for_commandline_arg (filename));
            });
            
            this.reorderable = true;
            unowned List<Item?> reorder_del = null; //deleted item when DnDing an item
            this.model.row_deleted.connect ( (path) => {
                reorder_del = this.files.nth (int.parse (path.to_string ()));
                this.files.delete_link (reorder_del);
            });
            this.model.row_inserted.connect ( (path, iter) => {
                if (reorder_del != null){
                    this.files.insert (reorder_del.data, int.parse (path.to_string ()));
                    reorder_del = null;
                }
            });
        }
        
        public void next (){
            if (current.next != null)
                current = current.next;
            play (current.data.path);
        }
        
        public void previous (){
            if (current.prev != null)
                current = current.prev;
            play (current.data.path);
        }
        
        public void add_item (File path){
            try{
                Gtk.TreeIter iter;
                var ext = Audience.get_extension (path.get_path ());
                Gdk.Pixbuf pix = null;
                if (ext in Audience.audio)
                    pix = Gtk.IconTheme.get_default ().load_icon ("folder-music-symbolic", 16, 0);
                else
                    pix = Gtk.IconTheme.get_default ().load_icon ("folder-videos-symbolic", 16, 0);
                var playing = Gtk.IconTheme.get_default ().load_icon ("media-playback-start-symbolic", 16, 0);
                playlist.append (out iter);
                playlist.set (iter, 0, playing, 1, pix, 
                                    2, Audience.get_basename (path.get_basename ()), 3, path.get_path ());
                Item item = {path, iter};
                files.append (item);
                if (files.length () == 1)
                    current = files.nth (0);
            }catch (Error e){warning (e.message);}
        }
        
        public void remove_item (File path){
            
        }
        
    }
    
}
