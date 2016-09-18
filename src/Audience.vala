/*-
 * Copyright (c) 2013-2014 Audience Developers (http://launchpad.net/pantheon-chat)
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

    public Audience.Settings settings; //global space for easier access...
    public class App : Granite.Application {

        /**
         * Translatable launcher (.desktop) strings to be added to template (.pot) file.
         * These strings should reflect any changes in these launcher keys in .desktop file
         */
        /// TRANSLATORS: This is the name of the application shown in the application launcher. Some distributors (e.g. elementary OS) choose to display it instead of the brand name "Audience".
        public const string VIDEOS = N_("Videos");
        /// TRANSLATORS: These are the keywords used when searching for this application in an application store or launcher.
        public const string KEYWORDS = N_("Audience;Video;Player;Movies;");
        public const string COMMENT = N_("Watch videos and movies");
        public const string GENERIC_NAME = N_("Video Player");
        /// TRANSLATORS: This is the shortcut used to view information about the application itself when its displayed name is branded "Audience".
        public const string ABOUT_STOCK = N_("About Audience");
        /// TRANSLATORS: This is the shortcut used to view information about the application itself when its displayed name is the localized equivalent of "Videos".
        public const string ABOUT_GENERIC = N_("About Videos");

        public Window mainwindow;
        public GLib.VolumeMonitor monitor;

        construct {
            program_name = _(Constants.APP_NAME);
            exec_name = "audience";

            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;

            Intl.setlocale (LocaleCategory.ALL, "");

            app_years = "2011-2016";
            app_icon = "multimedia-video-player";
            app_launcher = "org.pantheon.audience.desktop";
            application_id = "org.pantheon.audience";

            main_url = "https://code.launchpad.net/audience";
            bug_url = "https://bugs.launchpad.net/audience";
            help_url = "https://elementary.io/help/audience";
            translate_url = "https://translations.launchpad.net/audience";

            about_authors = { "Cody Garver <cody@elementaryos.org>",
                              "Tom Beckmann <tom@elementaryos.org>" };
            about_translators = _("translator-credits");
            about_license_type = Gtk.License.GPL_3_0;
        }

        public App () {
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;
            settings = new Settings ();
            set_default ();
        }

        private static App app; // global App instance
        public static App get_instance () {
            if (app == null)
                app = new App ();
            return app;
        }

        public override void activate () {
            if (mainwindow == null) {
                if (settings.last_folder == "-1") {
                    settings.last_folder = Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS);
                }
                if (settings.library_folder == "") {
                    settings.library_folder = GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS);
                }
                mainwindow = new Window ();
                mainwindow.application = this;
                mainwindow.title = program_name;
            }
        }
        
        public string get_cache_directory () {
            return GLib.Environment.get_user_cache_dir () + "/" + exec_name;
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
        error ("Could not initalize clutter! "+err.to_string ());
    }

    Gst.init (ref args);

    var app = Audience.App.get_instance ();

    app.run (args);
}
