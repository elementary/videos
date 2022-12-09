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
        public const string ACTION_PREFIX = "app.";
        public const string ACTION_NEXT = "action-next";
        public const string ACTION_PLAY_PAUSE = "action-play-pause";
        public const string ACTION_PREVIOUS = "action-previous";

        private const ActionEntry[] ACTION_ENTRIES = {
            { ACTION_PLAY_PAUSE, action_play_pause, null, "false" },
            { ACTION_NEXT, action_next },
            { ACTION_PREVIOUS, action_previous }
        };

        public Window mainwindow;
        public GLib.VolumeMonitor monitor;

        construct {
            Intl.setlocale (LocaleCategory.ALL, "");
            Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
            Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
            Intl.textdomain (GETTEXT_PACKAGE);
            application_id = "io.elementary.videos";
        }

        public App () {
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;

            settings = new GLib.Settings (SCHEMA);
        }

        private static App app; // global App instance
        public static App get_instance () {
            if (app == null)
                app = new App ();
            return app;
        }

        public override void activate () {
            if (mainwindow == null) {
                add_action_entries (ACTION_ENTRIES, this);

                if (settings.get_string ("last-folder") == "-1") {
                    settings.set_string ("last-folder", GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS));
                }

                try {
                    File cache = File.new_for_path (get_cache_directory ());
                    if (!cache.query_exists ()) {
                        cache.make_directory ();
                    }
                } catch (Error e) {
                    warning (e.message);
                }

                var mpris_id = Bus.own_name (
                    BusType.SESSION,
                    "org.mpris.MediaPlayer2.io.elementary.videos",
                    BusNameOwnerFlags.NONE,
                    on_bus_acquired,
                    null,
                    null
                );

                if (mpris_id == 0) {
                    warning ("Could not initialize MPRIS session.\n");
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

        private void action_play_pause () {
            var play_pause_action = lookup_action (ACTION_PLAY_PAUSE);
            if (play_pause_action.get_state ().get_boolean ()) {
                ((SimpleAction) play_pause_action).set_state (false);
            } else {
                ((SimpleAction) play_pause_action).set_state (true);
            }
        }

        private void action_next () {
            PlaybackManager.get_default ().next ();
        }

        private void action_previous () {
            PlaybackManager.get_default ().previous ();
        }

        private void on_bus_acquired (DBusConnection connection, string name) {
            try {
                connection.register_object ("/org/mpris/MediaPlayer2", new Videos.MprisRoot ());
                connection.register_object ("/org/mpris/MediaPlayer2", new Videos.MprisPlayer (connection));
            } catch (IOError e) {
                warning ("could not create MPRIS player: %s\n", e.message);
            }
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
