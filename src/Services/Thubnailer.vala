// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2016 elementary LLC.
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
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 *
 */

namespace Audience.Services {
    [DBus (name = "org.freedesktop.thumbnails.Thumbnailer1")]
    private interface Tumbler : GLib.Object {
        public abstract async uint Queue (string[] uris, string[] mime_types, string flavor, string sheduler, uint handle_to_dequeue) throws GLib.IOError, GLib.DBusError;
        public signal void Finished (uint handle);
    }

    public class DbusThumbnailer : GLib.Object {
        private Tumbler tumbler;
        private const string THUMBNAILER_IFACE = "org.freedesktop.thumbnails.Thumbnailer1";
        private const string THUMBNAILER_SERVICE = "/org/freedesktop/thumbnails/Thumbnailer1";

        public signal void finished (uint handle);

        public DbusThumbnailer () {
        }

        construct {
            try {
                tumbler = Bus.get_proxy_sync (BusType.SESSION, THUMBNAILER_IFACE, THUMBNAILER_SERVICE);
                tumbler.Finished.connect ((handle) => { finished (handle); });
            } catch (Error e) {
                warning (e.message);
            }
        }

        public void Instand (Gee.ArrayList<string> uris, Gee.ArrayList<string> mimes ){
            tumbler.Queue.begin (uris.to_array (), mimes.to_array (), "large", "default", 0);
        }
    }
}
