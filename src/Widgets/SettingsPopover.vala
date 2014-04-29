
public class Audience.Widgets.SettingsPopover : Gtk.Popover {
    public signal void select_external_subtitle (string uri);

    private Gtk.Grid taggrid;
    private Gtk.ComboBoxText languages;
    private Gtk.ComboBoxText subtitles;
    private Gtk.FileChooserButton external_subtitle_file;

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
}