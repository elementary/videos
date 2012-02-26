
/*
  The panel on the right hand side
*/

namespace Audience.Widgets{
    
    public class TagView : GtkClutter.Actor{
        
        public bool expanded;
        public Gtk.Grid taggrid;
        public Gtk.ListStore playlist;
        public AudienceApp app;
        
        public TagView (AudienceApp app){
            this.app = app;
            
            var notebook = new Granite.Widgets.StaticNotebook ();
            
            /*tags*/
            taggrid = new Gtk.Grid ();
            taggrid.column_spacing = 10;
            taggrid.margin = 12;
            
            /*chapters*/
            var chaptergrid = new Gtk.Grid ();
            chaptergrid.margin = 12;
            chaptergrid.attach (new LLabel.markup ("<span weight='bold' font='20'>"+_("Go to...")+"</span>"), 0, 0, 1, 1);
            
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
            setupgrid.attach (new LLabel.markup (
                "<span weight='bold' font='20'>Setup</span>"), 0, 0, 1, 1);
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
            var playlistgrid    = new Gtk.Grid ();
            playlistgrid.margin = 12;
            
            /*var css = new Gtk.CssProvider ();
            try{
                css.load_from_data ("*{background-color:@bg_color;}", -1);
            }catch (Error e){warning (e.message);}
            playlisttree.get_style_context ().add_provider (css, 12000);
            */
            
            playlistgrid.attach (new LLabel.markup (
                "<span weight='bold' font='20'>Playlist</span>"), 0, 0, 1, 1);
            playlistgrid.attach (this.app.playlist, 0, 1, 1, 1);
            
            notebook.append_page (playlistgrid, new Gtk.Label (_("Playlist")));
            notebook.append_page (setupgrid, new Gtk.Label (_("Setup")));
            notebook.append_page (chaptergrid, new Gtk.Label (_("Chapters")));
            if (app.settings.show_details)
                notebook.append_page (taggrid, new Gtk.Label (_("Details")));
            
            ((Gtk.Bin)this.get_widget ()).add (notebook);
            
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
            taggrid.attach (new LLabel.markup ("<span weight='bold' font='20'>"+_("Info")+"</span>"), 0, 0, 1, 1);
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
