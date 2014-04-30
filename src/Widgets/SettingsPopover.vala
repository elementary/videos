
public class Audience.Widgets.SettingsPopover : Gtk.Popover {
    public signal void select_external_subtitle (string uri);

    public Gtk.Grid taggrid;
    public Gtk.ComboBoxText languages;
    public Gtk.ComboBoxText subtitles;
    public Gtk.FileChooserButton external_subtitle_file;

    public SettingsPopover (Gtk.Widget widget) {
        opacity = global_opacity;
        relative_to = widget;
        
        var stack_grid = new Gtk.Grid ();
        stack_grid.margin = 6;
        stack_grid.orientation = Gtk.Orientation.VERTICAL;
        var stack = new Gtk.Stack ();
        //var stack_switcher = new Gtk.StackSwitcher ();
        //stack_switcher.set_stack (stack);
        //stack_switcher.halign = Gtk.Align.CENTER;
        //stack_grid.add (stack_switcher);
        stack_grid.add (stack);
        
        /*tags*/
        var tagview = new Gtk.ScrolledWindow (null, null);
        taggrid = new Gtk.Grid ();
        taggrid.column_spacing = 10;
        tagview.add_with_viewport (taggrid);
        
        /*setup*/
        var setupgrid  = new Gtk.Grid ();
        this.languages = new Gtk.ComboBoxText ();
        this.subtitles = new Gtk.ComboBoxText ();
        this.external_subtitle_file = new Gtk.FileChooserButton (_("External Subtitles"), Gtk.FileChooserAction.OPEN);
        var lang_lbl   = new LLabel.right (_("Audio")+":");
        var sub_lbl    = new LLabel.right (_("Subtitles")+":");
        var sub_ext_lbl = new LLabel.right (_("External Subtitles") + ":");
        setupgrid.attach (lang_lbl,  0, 1, 1, 1);
        setupgrid.attach (languages,                   1, 1, 1, 1);
        setupgrid.attach (sub_lbl, 0, 2, 1, 1);
        setupgrid.attach (subtitles,                   1, 2, 1, 1);
        setupgrid.attach (sub_ext_lbl, 0, 3, 1, 1);
        setupgrid.attach (this.external_subtitle_file, 1, 3, 1, 1);
        setupgrid.column_homogeneous = true;
        setupgrid.column_spacing = 12;
        
        external_subtitle_file.file_set.connect (() => {
            select_external_subtitle (external_subtitle_file.get_uri ());
        });
        /*this.subtitles.changed.connect ( () => {
            if (subtitles.active_id == null || currently_parsing)
                return;
            var id = int.parse (this.subtitles.active_id);
            app.video_player.current_text = id;
        });
        
        languages.changed.connect ( () => { //place it here to not get problems
            if (languages.active_id == null || currently_parsing)
                return;
            app.video_player.current_audio = int.parse (this.languages.active_id);
        });*/
        
        
        //stack.add_titled (playlist_scrolled, "playlist", _("Playlist"));
        stack.add_titled (setupgrid, "options", _("Options"));
        
        add (stack_grid);
    }
    public void setup_text_setup  () { setup_setup ("text"); }
    public void setup_audio_setup () { setup_setup ("audio"); }
    /*target is either "text" or "audio"*/
    public void setup_setup (string target) {
        /*var currently_parsing = true;
        
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
            tags.get_string (Gst.Tags.LANGUAGE_CODE, out desc);
            if (desc == null)
                tags.get_string (Gst.Tags.CODEC, out desc);

            if (desc != null)
                readable = Gst.Tag.get_language_name (desc);

            if (target == "audio" && desc != null) {
                this.languages.append (i.to_string (), readable == null ? desc : readable);
                used ++;
            } else if (desc != null) {
                var language = Gst.Tag.get_language_name (desc);
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

        currently_parsing = false;*/
    }
}