
/*
  The panel on the right hand side
*/

public const string LIGHT_WINDOW_STYLE = """
    .content-view-window {
        background-image:none;
        background-color:@bg_color;
        
        border-radius: 6px;
        
        border-width:1px;
        border-style: solid;
        border-color: alpha (#000, 0.25);
    }
""";

namespace Audience.Widgets{
    
    public class TagView : GtkClutter.Actor {
        
        public bool expanded;
        public Gtk.Grid taggrid;
        public Audience.App app;
        
        private Gtk.ComboBoxText languages;
        private Gtk.ComboBoxText subtitles;
        
        private Granite.Drawing.BufferSurface buffer;
        int shadow_blur = 30;
        int shadow_x    = 0;
        int shadow_y    = 0;
        double shadow_alpha = 0.5;
        
        public TagView (Audience.App app) {
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
            var setupgrid  = new Gtk.Grid ();
            this.languages = new Gtk.ComboBoxText ();
            this.subtitles = new Gtk.ComboBoxText ();
            var lang_lbl   = new LLabel.right (_("Language")+":");
            var sub_lbl    = new LLabel.right (_("Subtitles")+":");
            setupgrid.attach (lang_lbl,  0, 1, 1, 1);
            setupgrid.attach (languages,                   1, 1, 1, 1);
            setupgrid.attach (sub_lbl, 0, 2, 1, 1);
            setupgrid.attach (subtitles,                   1, 2, 1, 1);
            setupgrid.column_homogeneous = true;
            setupgrid.margin = 12;
            setupgrid.column_spacing = 12;
            
            this.subtitles.append ("-1", _("None"));
            this.subtitles.active = 0;
            this.subtitles.changed.connect ( () => {
                dynamic Gst.Element pipe = this.app.canvas.get_pipeline ();
                
                int flags;
                pipe.get ("flags", out flags);
                if (this.subtitles.active_id == "-1") {
                    flags &= ~SUBTITLES_FLAG;
                    pipe.set ("flags", flags, "current-text", -1);
                    debug ("Disabling subtitles");
                }else {
                    debug ("Switching to subtitle %s", this.subtitles.active_id);
                    flags |= SUBTITLES_FLAG;
                    pipe.set ("flags", flags, 
                        "current-text", int.parse (this.subtitles.active_id));
                }
            });
            
            var playlist_scrolled = new Gtk.ScrolledWindow (null, null);
            playlist_scrolled.add (this.app.playlist);
            
            notebook.append_page (playlist_scrolled, new Gtk.Label (_("Playlist")));
            notebook.append_page (setupgrid, new Gtk.Label (_("Options")));
            if (settings.show_details)
                notebook.append_page (tagview, new Gtk.Label (_("Details")));
            
            /*draw the window stylish!*/
            var css = new Gtk.CssProvider ();
            try {
                css.load_from_data (LIGHT_WINDOW_STYLE, -1);
            } catch (Error e) { warning (e.message); }
            
            var draw_ref = new Gtk.Window ();
            draw_ref.get_style_context ().add_class ("content-view-window");
            draw_ref.get_style_context ().add_provider (css, Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);
            
            var w = -1; var h = -1;
            this.get_widget ().size_allocate.connect ( () => {
                if (w == this.get_widget ().get_allocated_width () && 
                    h == this.get_widget ().get_allocated_height ())
                    return;
                w = this.get_widget ().get_allocated_width ();
                h = this.get_widget ().get_allocated_height ();
                
                this.buffer = new Granite.Drawing.BufferSurface (w, h);
                
                this.buffer.context.rectangle (shadow_blur + shadow_x, 
                    shadow_blur + shadow_y, w - shadow_blur*2 + shadow_x, h - shadow_blur*2 + shadow_y);
                this.buffer.context.set_source_rgba (0, 0, 0, shadow_alpha);
                this.buffer.context.fill ();
                this.buffer.exponential_blur (shadow_blur / 2);
                
                draw_ref.get_style_context ().render_activity (this.buffer.context, 
                    shadow_blur + shadow_x, shadow_blur + shadow_y, 
                    w - shadow_blur*2 + shadow_x, h - shadow_blur*2 + shadow_y);
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
            
            var no_bg = new Gtk.CssProvider ();
            try {
                no_bg.load_from_data ("""
                * {
                    background-color: alpha(#fff, 0);
                }
                .view:selected:focused {
                    color: @selected_bg_color;
                }
                """, -1);
            } catch (Error e) { warning (e.message); }
            setupgrid.get_parent ().get_style_context ().add_provider (no_bg, 20000);
            app.playlist.get_style_context ().add_provider (no_bg, 20000);
            
            playlist_scrolled.margin = 3;
            notebook.margin = shadow_blur + 2;
            notebook.margin_top += 3;
            this.get_widget ().get_style_context ().add_class ("content-view");
            ((Gtk.Bin)this.get_widget ()).add (notebook);
            this.get_widget ().show_all ();
            this.width = 350;
            this.opacity = 0;
            this.expanded = false;
        }
        
        public void expand (){
            var x2 = this.get_stage ().width - this.width + 10;
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x:x2);
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity:255);
            this.expanded = true;
        }
        
        public void collapse (){
            var x2 = this.get_stage ().width;
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x:x2);
            this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity:0);
            this.expanded = false;
        }
        
        /*target is either "text" or "audio"*/
        public void setup_setup (string target) {
            Value num = 0;
            this.app.canvas.get_pipeline ().get_property ("n-"+target, ref num);
            
            int used = 0;
            for (var i=0;i<num.get_int ();i++) {
                Gst.TagList tags = null;
                Signal.emit_by_name (this.app.canvas.get_pipeline (), 
                    "get-"+target+"-tags", i, out tags);
                if (tags == null)
                    continue;
                
                used ++;
                string desc;
                tags.get_string (Gst.TAG_LANGUAGE_CODE, out desc);
                if (desc == null)
                    tags.get_string (Gst.TAG_CODEC, out desc);
                
                var readable = Gst.tag_get_language_name (desc);
                if (target == "audio" && desc != null) {
                    this.languages.append (i.to_string (), (readable == null)?desc:readable);
                }else if (desc != null) {
                    this.subtitles.append (i.to_string (), Gst.tag_get_language_name (desc));
                }
                
                message ("Getting %s", desc);
                
                debug (desc);
            }
            if (target == "audio") {
                if (used <= 1) { //FIXME
                    this.languages.append ("def", _("Default"));
                    this.languages.active = 0;
                    this.languages.sensitive = false;
                } else {
                    this.languages.sensitive = true;
                    this.languages.active = 0;
                    
                    this.languages.changed.connect ( () => { //place it here to not get problems
                        debug ("Switching to audio %s\n", this.languages.active_id);
                        dynamic Gst.Element pipe = this.app.canvas.get_pipeline ();
                        pipe.current_audio = int.parse (this.languages.active_id);
                    });
                }
            } else {
                if (used == 0)
                    this.subtitles.sensitive = false;
                else
                    this.subtitles.sensitive = true;
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
