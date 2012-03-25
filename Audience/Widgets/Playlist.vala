

namespace Audience.Widgets {
    
    public class Playlist : Clutter.Box {
        
        /*class representing an item to be displayed*/
        class Entry : Clutter.Box {
            
            public File        path;
            Clutter.Text       title;
            GtkClutter.Texture thumb;
            Clutter.Rectangle  bg;
            
            public Entry (File file) {
                
                this.reactive = true;
                this.layout_manager = new Clutter.BinLayout (Clutter.BinAlignment.FILL, 
                    Clutter.BinAlignment.FILL);
                this.width   = 80.0f;
                this.height  = 200.0f;
                this.opacity = 150;
                this.clip_to_allocation = true;
                
                this.path                    = file;
                this.bg                      = new Clutter.Rectangle.with_color ({50, 50, 50, 220});
                this.bg.width                = 200;
                this.bg.height               = 30;
                this.title                   = new Clutter.Text.with_text ("", Audience.get_title (file.get_path ()));
                this.title.color             = {255, 255, 255, 255};
                this.title.ellipsize         = Pango.EllipsizeMode.END;
                this.thumb                   = new GtkClutter.Texture ();
                this.thumb.keep_aspect_ratio = true;
                
                Audience.get_thumb (file, -1, this.thumb);
                
                this.add_actor (this.thumb);
                ((Clutter.BinLayout)this.layout_manager).add (this.bg, 
                    Clutter.BinAlignment.START,  Clutter.BinAlignment.END);
                ((Clutter.BinLayout)this.layout_manager).add (this.title, 
                    Clutter.BinAlignment.START,  Clutter.BinAlignment.END);
                
                this.enter_event.connect ( () => {
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, width:200.0f);
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity:255);
                    return true;
                });
                
                this.leave_event.connect ( () => {
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, width:80.0f);
                    this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity:150);
                    return true;
                });
            }
            
        }
        
        /*the player is requested to play path*/
        public signal void play (File path);
        
        private int               current;
        private GLib.List<Entry?> playlist;
        
        public Playlist (){
            this.current  = 0;
            this.layout_manager = new Clutter.BoxLayout ();
            
            this.reactive = true;
            this.scroll_event.connect ( (e) => {
                var val = -100.0f;
                if (e.direction == Clutter.ScrollDirection.UP || 
                    e.direction == Clutter.ScrollDirection.RIGHT)
                    val *= -1;
                this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x:this.x+val);
                return true;
            });
        }
        
        private inline void change_current_symbol (){
            
        }
        
        public void next (){
            this.current ++;
            play (this.playlist.nth_data (current).path);
            change_current_symbol ();
        }
        
        public void previous (){
            this.current --;
            play (this.playlist.nth_data (current).path);
            change_current_symbol ();
        }
        
        public void add_item (File path){
            var e = new Entry (path);
            e.button_release_event.connect ( () => {
                play (e.path);
                return true;
            });
            
            this.add_actor (e);
            this.playlist.append (e);
        }
    }
    
}
