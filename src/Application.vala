/*-
 * Copyright (c) 2013-2018 elementary LLC (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Tom Beckmann <tomjonabc@gmail.com>
 *              Cody Garver <cody@elementaryos.org>
 *              Artem Anufrij <artem.anufrij@live.de>
 */

namespace Audience {
    private const string SCHEMA = "io.elementary.videos";

    public GLib.Settings settings; //global space for easier access...

    public class App : Gtk.Application {

        public Window mainwindow;
        public GLib.VolumeMonitor monitor;

        construct {
            Intl.setlocale (LocaleCategory.ALL, "");
            application_id = "io.elementary.videos";
        }

        public App () {
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;

            settings = new GLib.Settings (SCHEMA);

            Services.Inhibitor.initialize (this);
        }

        private static App app; // global App instance
        public static App get_instance () {
            if (app == null)
                app = new App ();
            return app;
        }

        public override void activate () {
            if (mainwindow == null) {
                if (settings.get_string ("last-folder") == "-1") {
                    settings.set_string ("last-folder", GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS));
                }

                var library_path = settings.get_string ("library-folder");
                File library_folder = File.new_for_path (library_path);
                if (library_path == "" || !library_folder.query_exists ()) {
                    settings.set_string ("library-folder", GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS));
                };

                try {
                    File cache = File.new_for_path (get_cache_directory ());
                    if (!cache.query_exists ()) {
                        cache.make_directory ();
                    }
                } catch (Error e) {
                    warning (e.message);
                }

                mainwindow = new Window ();
                mainwindow.application = this;
                mainwindow.title = _("Videos");
            }
        }

        public string get_cache_directory () {
            return GLib.Path.build_filename (GLib.Environment.get_user_cache_dir (), application_id);
        }

        //the application was requested to open some files
        public override void open (File[] files, string hint) {
            activate ();
            mainwindow.open_files (files, true);
        }
    }
}

public static void main (string [] args) {
    X.init_threads ();

    var err = GtkClutter.init (ref args);
    if (err != Clutter.InitError.SUCCESS) {
        error ("Could not initialize clutter! %s", err.to_string ());
    }

    Gst.init (ref args);

    var app = Audience.App.get_instance ();

    app.run (args);
}
