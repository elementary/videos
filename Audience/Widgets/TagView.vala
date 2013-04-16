
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

namespace Audience.Widgets
{
    public class TagView : GtkClutter.Actor
    {
        public bool expanded;
        public Gtk.Grid taggrid;
        public Audience.App app;
        
        public Gtk.ComboBoxText languages;
        public Gtk.ComboBoxText subtitles;
		private Gtk.FileChooserButton external_subtitle_file;
        
        private Granite.Drawing.BufferSurface buffer;
        int shadow_blur = 30;
        int shadow_x    = 0;
        int shadow_y    = 0;
        double shadow_alpha = 0.5;

		bool currently_parsing = false;

		public signal void select_external_subtitle (string uri);
        
        public TagView (Audience.App app) {
            this.app      = app;
            this.reactive = true;
            this.buffer   = new Granite.Drawing.BufferSurface (100, 100);
            
            var notebook = new Granite.Widgets.StaticNotebook (false);
            
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
			this.external_subtitle_file = new Gtk.FileChooserButton (_("External Subtitle"), Gtk.FileChooserAction.OPEN);
            var lang_lbl   = new LLabel.right (_("Language")+":");
            var sub_lbl    = new LLabel.right (_("Subtitles")+":");
			var sub_ext_lbl = new LLabel.right (_("External Subtitles") + ":");
            setupgrid.attach (lang_lbl,  0, 1, 1, 1);
            setupgrid.attach (languages,                   1, 1, 1, 1);
            setupgrid.attach (sub_lbl, 0, 2, 1, 1);
            setupgrid.attach (subtitles,                   1, 2, 1, 1);
			setupgrid.attach (sub_ext_lbl, 0, 3, 1, 1);
			setupgrid.attach (this.external_subtitle_file, 1, 3, 1, 1);
            setupgrid.column_homogeneous = true;
            setupgrid.margin = 12;
            setupgrid.column_spacing = 12;
            
			external_subtitle_file.file_set.connect (() => {
				select_external_subtitle (external_subtitle_file.get_uri ());
			});
            this.subtitles.changed.connect ( () => {
                if (subtitles.active_id == null || currently_parsing)
                    return;
				var id = int.parse (this.subtitles.active_id);
				app.video_player.current_text = id;
            });
            
            languages.changed.connect ( () => { //place it here to not get problems
                if (languages.active_id == null || currently_parsing)
                    return;
                app.video_player.current_audio = int.parse (this.languages.active_id);
            });
            
            var playlist_scrolled = new Gtk.ScrolledWindow (null, null);
            playlist_scrolled.add (this.app.playlist);
            
            notebook.append_page (playlist_scrolled, new Gtk.Label (_("Playlist")));
            notebook.append_page (setupgrid, new Gtk.Label (_("Options")));
            
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
        
        public override void allocate (Clutter.ActorBox box, Clutter.AllocationFlags flags) {
        	//have a minimum height in order to not get the negative allocation warnings
        	if (box.y2 - box.y1 < 100) {
        		box.y2 = box.y1 + 100;
    		}
    		base.allocate (box, flags);
        }
        
        public void expand (){
            //make sure it comes from right bounds
            x = get_stage ().width + 100;
            
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
        
        public void setup_text_setup  () { setup_setup ("text"); }
        public void setup_audio_setup () { setup_setup ("audio"); }
        /*target is either "text" or "audio"*/
        public void setup_setup (string target) {
			currently_parsing = true;
            
            if (target == "audio" && languages.model.iter_n_children (null) > 0)
                languages.remove_all ();
            else if (target == "text" && subtitles.model.iter_n_children (null) > 0)
                subtitles.remove_all ();
            
            Value num = 0;
            app.video_player.playbin.get_property ("n-"+target, ref num);
            
            int used = 0;
            for (var i=0;i<num.get_int ();i++) {
                Gst.TagList tags = null;
                Signal.emit_by_name (app.video_player.playbin, "get-"+target+"-tags", i, out tags);
                if (tags == null)
                    continue;
                
                string desc;
				string readable = null;
#if HAS_CLUTTER_GST_1
                tags.get_string (Gst.Tags.LANGUAGE_CODE, out desc);
                if (desc == null)
                    tags.get_string (Gst.Tags.CODEC, out desc);
                
				if (desc != null)
					readable = Gst.Tag.get_language_name (desc);
#else
                tags.get_string (Gst.TAG_LANGUAGE_CODE, out desc);
                if (desc == null)
                    tags.get_string (Gst.TAG_CODEC, out desc);
                
				if (desc != null)
					readable = Gst.tag_get_language_name (desc);
#endif
                if (target == "audio" && desc != null) {
                    this.languages.append (i.to_string (), readable == null ? desc : readable);
                    used ++;
                } else if (desc != null) {
#if HAS_CLUTTER_GST_1
                    var language = Gst.Tag.get_language_name (desc);
#else
                    var language = Gst.tag_get_language_name (desc);
#endif
                    this.subtitles.append (i.to_string (), language == null ? desc : language);
                    used ++;
                }
            }

            if (target == "audio") {
                
                if (used == 0) {
                    languages.append ("def", _("Default"));
                    languages.active = 0;
                    languages.sensitive = false;
                } else {
                    languages.sensitive = true;
					languages.active_id = app.video_player.current_audio.to_string ();
                }
            } else {
                if (used == 0)
                    subtitles.sensitive = false;
                else
                    subtitles.sensitive = true;
                
                subtitles.append ("-1", _("None"));
				subtitles.active_id = app.video_player.current_text.to_string ();
            }

			currently_parsing = false;
        }
    }
}
