
/*
  The panel on the right hand side
*/

namespace Audience.Widgets{
    
    public class TagView : GtkClutter.Actor {
        
        public bool expanded;
        public Gtk.Grid taggrid;
        public AudienceApp app;
        
        private Gtk.ComboBoxText languages;
        private Gtk.ComboBoxText subtitles;
        
        private Granite.Drawing.BufferSurface buffer;
        
        public TagView (AudienceApp app) {
            this.app      = app;
            this.reactive = true;
            this.buffer   = new Granite.Drawing.BufferSurface (100, 100);
            
            var notebook = new Granite.Widgets.StaticNotebook ();
            
            /*tags*/
            var tagview = new Gtk.ScrolledWindow (null, null);
            taggrid = new Gtk.Grid ();
            taggrid.column_spacing = 10;
            taggrid.margin = 12;
            tagview.add_with_viewport (taggrid);
            
            /*setup*/
            var setupgrid = new Gtk.Grid ();
            this.languages = new Gtk.ComboBoxText ();
            this.subtitles = new Gtk.ComboBoxText ();
            setupgrid.attach (new LLabel.right (_("Language")+":"),  0, 1, 1, 1);
            setupgrid.attach (languages,                   1, 1, 1, 1);
            setupgrid.attach (new LLabel.right (_("Subtitles")+":"), 0, 2, 1, 1);
            setupgrid.attach (subtitles,                   1, 2, 1, 1);
            setupgrid.column_homogeneous = true;
            setupgrid.margin = 12;
            setupgrid.column_spacing = 12;
            
            this.subtitles.append ("-1", _("None"));
            this.subtitles.active = 0;
            this.subtitles.changed.connect ( () => {
                debug ("Switching to subtitle %s\n", this.subtitles.active_id);
                dynamic Gst.Element pipe = this.app.canvas.get_pipeline ();
                if (this.subtitles.active_id == "-1") {
                    pipe.flags &= ~SUBTITLES_FLAG;
                }else {
                    pipe.flags |= SUBTITLES_FLAG;
                    pipe.current_text =  int.parse (this.subtitles.active_id);
                }
            });
            
            /*playlist*/
            var playlistgrid    = new Gtk.Label ("Nothin here"); //dummy
            
            notebook.append_page (playlistgrid, new Gtk.Label (_("Playlist")));
            notebook.append_page (setupgrid, new Gtk.Label (_("Options")));
            if (app.settings.show_details)
                notebook.append_page (tagview, new Gtk.Label (_("Details")));
            
            playlistgrid.draw.connect ( (ctx) => {
                ctx.rectangle (0, 0, playlistgrid.get_allocated_width (), 
                    playlistgrid.get_allocated_height ());
                ctx.set_operator (Cairo.Operator.SOURCE);
                ctx.set_source_rgba (0.141, 0.141, 0.141, 0.698);
                ctx.fill ();
                return true;
            });
            
            
            notebook.margin = 15;
            notebook.margin_top = 0;
            ((Gtk.Bin)this.get_widget ()).add (notebook);
            
            var w = 0; var h = 0;
            this.get_widget ().size_allocate.connect ( () => {
                if (w != this.get_widget ().get_allocated_width  () || 
                    h != this.get_widget ().get_allocated_height ()) {
                    w = this.get_widget ().get_allocated_width  ();
                    h = this.get_widget ().get_allocated_height ();
                    
                    this.buffer = new Granite.Drawing.BufferSurface (w, h);
                    
                    this.buffer.context.rectangle (0, 0, this.width, this.height);
                    this.buffer.context.set_source_rgba (0.141, 0.141, 0.141, 0.698);
                    this.buffer.context.fill ();
                    
                    this.buffer.context.move_to (0, 0);
                    this.buffer.context.line_to (this.width, 0);
                    this.buffer.context.set_source_rgba (0.0, 0.0, 0.0, 0.5);
                    this.buffer.context.stroke ();
                    
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
            
            this.app.playlist.add_constraint (new Clutter.BindConstraint (this.app.playlist.get_stage (), 
                Clutter.BindCoordinate.WIDTH, 0));
            this.app.playlist.add_constraint (new Clutter.BindConstraint (this, 
                Clutter.BindCoordinate.Y, 30));
            this.app.playlist.height = 165.0f - CONTROLS_HEIGHT;
            
            notebook.page_changed.connect ( (idx) => {
                if (idx == 0) {
                    this.app.playlist.show ();
                }else {
                    this.app.playlist.hide ();
                }
            });
        }
        
        public void expand (){
            var y2 = this.get_stage ().height - this.height;
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, y:y2);
            this.expanded = true;
        }
        
        public void collapse (){
            var y2 = this.get_stage ().height;
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, y:y2);
            this.expanded = false;
        }
        
        /*target is either "text" or "audio"*/
        public void setup_setup (string target) {
            Value num = 0;
            this.app.canvas.get_pipeline ().get_property ("n-"+target, ref num);
            
            for (var i=0;i<num.get_int ();i++) {
                Gst.TagList tags = null;
                Signal.emit_by_name (this.app.canvas.get_pipeline (), 
                    "get-"+target+"-tags", i, out tags);
                if (tags == null)
                    continue;
                
                string desc;
                tags.get_string (Gst.TAG_LANGUAGE_CODE, out desc);
                if (desc == null)
                    tags.get_string (Gst.TAG_CODEC, out desc);
                
                if (target == "audio") {
                    this.languages.append (i.to_string (), desc);
                }else {
                    this.subtitles.append (i.to_string (), desc);
                }
            }
            if (target == "audio") {
                if (num.get_int () <= 1)
                    this.languages.sensitive = false;
                else {
                    this.languages.sensitive = true;
                    
                    this.languages.active = 0;
                    
                    this.languages.changed.connect ( () => { //place it here to not get problems
                        debug ("Switching to audio %s\n", this.languages.active_id);
                        dynamic Gst.Element pipe = this.app.canvas.get_pipeline ();
                        pipe.current_audio = int.parse (this.languages.active_id);
                    });
                }
            }
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
