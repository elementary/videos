namespace Audience {

    using Gtk;

    public abstract class ToolButtonWithMenu : ToggleToolButton
    {
        protected Menu menu;
        private PositionType _menu_orientation;
        protected PositionType menu_orientation{
            set{
                if(value == PositionType.TOP || value == PositionType.BOTTOM){
                    value = PositionType.LEFT;
                }
                
                _menu_orientation = value;
            }
            get{
                return _menu_orientation;
            }
        }

        public ToolButtonWithMenu (Image image, string label, Menu _menu, PositionType menu_orientation = PositionType.LEFT)
        {
            this.menu_orientation = menu_orientation;
        
            icon_widget = image;
            label_widget = new Label (label);
            ((Label) label_widget).use_underline = true;
            can_focus = true;
            set_tooltip_text (_("Menu"));
            menu = _menu;
            menu.attach_to_widget (this, null);
            menu.deactivate.connect(() => {
                active = false;
            });

            mnemonic_activate.connect(on_mnemonic_activate);
            menu.deactivate.connect(popdown_menu);
            clicked.connect(on_clicked);
        }

        private bool on_mnemonic_activate (bool group_cycling)
        {
            // ToggleButton always grabs focus away from the editor,
            // so reimplement Widget's version, which only grabs the
            // focus if we are group cycling.
            if (!group_cycling) {
                activate ();
            } else if (can_focus) {
                grab_focus ();
            }

            return true;
        }

        protected new void popup_menu(Gdk.EventButton? ev)
        {
            try {
                menu.popup (null,
                            null,
                            get_menu_position,
                            (ev == null) ? 0 : ev.button,
                            (ev == null) ? get_current_event_time() : ev.time);
            } finally {
                // Highlight the parent
                if (menu.attach_widget != null)
                    menu.attach_widget.set_state(StateType.SELECTED);
            }
        }

        protected void popdown_menu ()
        {
            menu.popdown ();

            // Unhighlight the parent
            if (menu.attach_widget != null)
                menu.attach_widget.set_state(Gtk.StateType.NORMAL);
        }
        
        public override void show_all()
        {
            base.show_all();
            menu.show_all();
        }

        private void on_clicked ()
        {
            menu.select_first (true);
            popup_menu (null);
        }

        private void get_menu_position (Menu menu, out int x, out int y, out bool push_in)
        {
            if (menu.attach_widget == null ||
                menu.attach_widget.get_window() == null) {
                // Prevent null exception in weird cases
                x = 0;
                y = 0;
                push_in = true;
                return;
            }

            menu.attach_widget.get_window().get_origin (out x, out y);
            Allocation allocation;
            menu.attach_widget.get_allocation(out allocation);


            x += allocation.x;
            y += allocation.y;

            int width, height;
            menu.get_size_request(out width, out height);

            if (y + height >= menu.attach_widget.get_screen().get_height())
                y -= height;
            else
                y += allocation.height;

            push_in = true;
        }
    }

    public class AppMenu : ToolButtonWithMenu
    {
        Window WINDOW;

        public AppMenu (Window window, Menu menu)
        {

            Image image = new Image.from_file (Build.PKGDATADIR + "/style/images/appmenu.svg");

            MenuItem open_item = new MenuItem.with_label("Open");
         /* MenuItem audio_item = new MenuItem.with_label("Audio");
            CheckMenuItem en_item = new CheckMenuItem.with_label("English");
            CheckMenuItem en_item2 = new CheckMenuItem.with_label("English");
            CheckMenuItem fr_item = new CheckMenuItem.with_label("French");
            CheckMenuItem fr_item2 = new CheckMenuItem.with_label("French");
            MenuItem subtitles_item = new MenuItem.with_label("Subtitles");
            var audio_submenu = new Gtk.Menu();
            audio_submenu.append(en_item);
            audio_submenu.append(fr_item);
            audio_item.set_submenu(audio_submenu);
            var subtitles_submenu = new Gtk.Menu();
            subtitles_submenu.append(en_item2);
            subtitles_submenu.append(fr_item2);
            subtitles_item.set_submenu(subtitles_submenu);
          */

            menu.append(open_item);
         /* menu.append(new Gtk.SeparatorMenuItem());
            menu.append(audio_item);
            menu.append(subtitles_item);
          */

            base(image, "Menu", menu);

            WINDOW = window;
	    
         /* open_item.activate.connect(on_open);
            For CheckMenuItems see line 156 of
            http://bazaar.launchpad.net/~elementary-apps/lingo-dictionary/lingo/view/head:/src/lingo-window.vala
          */
        }

     /* private void on_open_menuitem()
        {

		stdout.printf("Exporting not yet available.\n");

        }
      */
    }
}
