
/*
  The panel on the right hand side
*/

namespace Audience.Widgets{
    
    public class TagView : GtkClutter.Actor{
        
        public bool expanded;
        public Gtk.Grid taggrid;
        public Gtk.ListStore playlist;
        public AudienceApp app;
        
        private Granite.Drawing.BufferSurface buffer;
        
        public TagView (AudienceApp app){
            this.app      = app;
            this.reactive = true;
            this.buffer   = new Granite.Drawing.BufferSurface (100, 100);
            
            var notebook = new Granite.Widgets.StaticNotebook ();
            
            /*tags*/
            taggrid = new Gtk.Grid ();
            taggrid.column_spacing = 10;
            taggrid.margin = 12;
            
            /*chapters*/
            var chaptergrid = new Gtk.Grid ();
            chaptergrid.margin = 12;
            
            chaptergrid.attach (
                new Gtk.Image.from_icon_name ("edit-find-symbolic", Gtk.IconSize.MENU), 0, 1, 1, 1);
            chaptergrid.attach (new Gtk.Button.with_label (_("Menu")), 1, 1, 1, 1);
            chaptergrid.attach (
                new Gtk.Image.from_icon_name ("folder-music-symbolic", Gtk.IconSize.MENU), 0, 2, 1, 1);
            chaptergrid.attach (new Gtk.Button.with_label (_("Audio Menu")), 1, 2, 1, 1);
            chaptergrid.attach (
                new Gtk.Image.from_icon_name ("folder-videos-symbolic", Gtk.IconSize.MENU), 0, 3, 1, 1);
            chaptergrid.attach (new Gtk.Button.with_label (_("Chapter Menu")), 1, 3, 1, 1);
            for (var i=1;i<10;i++){
                chaptergrid.attach (
                    new Gtk.Image.from_icon_name ("view-list-video-symbolic", Gtk.IconSize.MENU), 0, i+3, 1, 1);
                var bt = new Gtk.Button.with_label (_("Chapter")+" 0"+i.to_string ());
                bt.hexpand = true;
                chaptergrid.attach (bt, 1, i+3, 1, 1);
            }
            
            /*setup*/
            var setupgrid = new Gtk.Grid ();
            var languages = new Gtk.ComboBoxText ();
            var subtitles = new Gtk.ComboBoxText ();
            setupgrid.attach (new Gtk.Label (_("Language")),  0, 1, 1, 1);
            setupgrid.attach (languages,                   1, 1, 1, 1);
            setupgrid.attach (new Gtk.Label (_("Subtitles")), 0, 2, 1, 1);
            setupgrid.attach (subtitles,                   1, 2, 1, 1);
            setupgrid.column_homogeneous = true;
            setupgrid.margin = 12;
            
            languages.append ("eng", "English (UK)");
            languages.append ("de", "German");
            languages.append ("fr", "French");
            languages.active = 0;
            subtitles.append ("0", "None");
            subtitles.append ("eng", "English (UK");
            subtitles.append ("de", "German");
            subtitles.append ("fr", "French");
            subtitles.active = 0;
            
            /*playlist*/
            var playlistgrid    = new Gtk.ScrolledWindow (null, null);
            playlistgrid.margin = 12;
            
            var css = new Gtk.CssProvider ();
            try{
                css.load_from_data ("*{background-color:#ffffff;}", -1);
            }catch (Error e){warning (e.message);}
            notebook.get_style_context ().add_provider (css, 12000);
            
            playlistgrid.add (this.app.playlist);
            
            notebook.append_page (playlistgrid, new Gtk.Label (_("Playlist")));
            notebook.append_page (setupgrid, new Gtk.Label (_("Setup")));
            notebook.append_page (chaptergrid, new Gtk.Label (_("Chapters")));
            if (app.settings.show_details)
                notebook.append_page (taggrid, new Gtk.Label (_("Details")));
            
            notebook.margin = 15;
            notebook.margin_bottom = CONTROLS_HEIGHT + 25;
            ((Gtk.Bin)this.get_widget ()).add (notebook);
            
            var w = 0; var h = 0;
            this.get_widget ().size_allocate.connect ( () => {
                if (w != this.get_widget ().get_allocated_width  () || 
                    h != this.get_widget ().get_allocated_height ()) {
                    w = this.get_widget ().get_allocated_width  ();
                    h = this.get_widget ().get_allocated_height ();
                    
                    this.buffer = new Granite.Drawing.BufferSurface (w, h);
                    
                    Granite.Drawing.Utilities.cairo_rounded_rectangle (this.buffer.context, 10, 10, 
                        w-20, h-CONTROLS_HEIGHT-30, 10);
                    
                    this.buffer.context.set_source_rgba (0.0, 0.0, 0.0, 1.0);
                    this.buffer.context.fill_preserve ();
                    this.buffer.exponential_blur (2);
                    
                    this.buffer.context.set_source_rgb (1.0, 1.0, 1.0);
                    this.buffer.context.fill ();
                }
            });
            
            this.get_widget ().draw.connect ( (ctx) => {
                ctx.set_operator (Cairo.Operator.SOURCE);
                ctx.rectangle (0, 0, this.width, this.height);
                ctx.set_source_rgba (0.0, 0.0, 0.0, 0.0);
                ctx.fill ();
                
                ctx.set_source_surface (this.buffer.surface, 0, 0);
                ctx.paint ();
                
                return false;
            });
            
            notebook.show_all ();
            this.width  = 200;
            this.expanded = false;
        }
        
        public void expand (){
            var x2 = this.get_stage ().width - this.width;
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x:x2);
            this.expanded = true;
        }
        
        public void collapse (){
            var x2 = this.get_stage ().width;
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x:x2);
            this.expanded = false;
        }
        
        public void get_tags (string filename, bool set_title){
            var pipe = new Gst.Pipeline ("tagpipe");
            var src  = Gst.ElementFactory.make ("uridecodebin", "src");
            var sink = Gst.ElementFactory.make ("fakesink", "sink");
            src.set ("uri", File.new_for_commandline_arg (filename).get_uri ());
            pipe.add_many (src, sink);
            
            pipe.set_state (Gst.State.PAUSED);
            
            taggrid.foreach ( (w) => {taggrid.remove (w);});
            var index = 1;
            pipe.get_bus ().add_watch ( (bus, msg) => {
                if (msg.type == Gst.MessageType.TAG){
                    Gst.TagList tag_list;
                    msg.parse_tag (out tag_list);
                    tag_list.foreach ( (list, tag) => {
                        for (var i=0;i<list.get_tag_size (tag);i++){
                            var val = list.get_value_index (tag, i);
                            if (set_title && tag == "title")
                                this.app.mainwindow.title = val.strdup_contents ();
                            taggrid.attach (new LLabel.markup ("<b>"+tag+"</b>"), 0, index, 1, 1);
                            taggrid.attach (new LLabel (val.strdup_contents ()),  1, index, 1, 1);
                            taggrid.show_all ();
                            index ++;
                        }
                    });
                }else if (msg.type == Gst.MessageType.EOS)
                    pipe.set_state (Gst.State.NULL);
                return true;
            });
            pipe.set_state (Gst.State.PLAYING);
        }
    }
    
}
