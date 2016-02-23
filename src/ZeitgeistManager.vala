// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013-2015 Audience Developers (http://launchpad.net/pantheon-chat)
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
 * Authored by:     Artem Anufrij <artem.anufrij@live.de>
 */

namespace Audience {

    [DBus (name = "org.gnome.zeitgeist.Blacklist")]
    interface BlacklistInterface : Object {
        [DBus (signature = "a{s(asaasay)}")]
        public abstract Variant get_templates () throws IOError;
    }

    public class ZeitgeistManager : Object {

        private BlacklistInterface apps;

        public ZeitgeistManager () {
            try {
                apps = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.zeitgeist.Engine", "/org/gnome/zeitgeist/blacklist");
            } catch (Error e) {
                error (e.message);
            }
        }

        public bool app_into_blacklist (string app_name) {
            try {
                foreach(Variant key in apps.get_templates ()) {
                    VariantIter iter = key.iterator ();
                    string template_id = iter.next_value ().get_string ();
                    if (template_id == "app-" + app_name + ".desktop") {
                        return true;
                    }
                }
            } catch (Error e) {
                error (e.message);
            }

            return false;
        }
    }
}
