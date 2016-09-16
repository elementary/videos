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

namespace Audience {

    public class LibraryItem : Gtk.CellRenderer  {

        public Audience.Objects.Video Video { get; set; }

        private Gtk.CellRendererPixbuf icon_renderer;
        private Gtk.CellRendererText text_renderer;

        public int Padding;

        public LibraryItem () {
            icon_renderer = new Gtk.CellRendererPixbuf();
            text_renderer = new Gtk.CellRendererText();
        }

        public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area, out int x_offset, out int y_offset, out int width, out int height)
        {
            x_offset = 0;
            y_offset = 0;
            width = 240;
            height = 280;
            Padding = 10;
        }

        public override void render (Cairo.Context ctx, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {

            Gdk.Rectangle icon_area = Gdk.Rectangle();
            Gdk.Rectangle text_area = Gdk.Rectangle();

            Gdk.Rectangle fill_area;

            Gtk.Requisition size;

            text_renderer.@set("text", Video.Title);
            text_renderer.get_preferred_size(widget, null, out size);

            text_area.width = size.width;
            text_area.height = size.height;

            icon_renderer.@set("pixbuf", Video.Poster);
            icon_renderer.get_preferred_size(widget, null, out size);

            icon_area.width = size.width;
            icon_area.height = size.height;

            fill_area = cell_area;
            fill_area.x += (int) xpad;
            fill_area.y += (int) ypad;

            fill_area.width -= (int) xpad * 2;
            fill_area.height -= (int) ypad * 2;

            icon_area.x = fill_area.x + (fill_area.width - icon_area.width) / 2;
            icon_area.y = fill_area.y;

            text_area.x = fill_area.x + (fill_area.width - text_area.width) / 2;;
            text_area.y = icon_area.y + icon_area.height;
            text_area.width = fill_area.width - Padding;

            weak Gtk.StyleContext style = widget.get_style_context ();
            
            style.save ();
            style.add_class ("h4");
            text_renderer.render(ctx, widget, background_area, text_area, flags);
            style.restore ();
            style.save ();
            style.add_class ("cover");
            icon_renderer.render(ctx, widget, background_area, icon_area, flags);
            style.restore ();
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void get_preferred_width (Gtk.Widget widget, out int minimum_size, out int natural_size)
        {
            minimum_size = natural_size = 260;
        }

        public override void get_preferred_height_for_width (Gtk.Widget widget, int width, out int minimum_height, out int natural_height)
        {
            minimum_height = natural_height = 260;
        }
    }
}
