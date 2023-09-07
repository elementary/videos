public class Audience.Objects.Show : Object, LibraryInterface {
    public string title { get; construct; }
    public Gdk.Pixbuf? poster { get; protected set; default = null; }

    public ListStore episodes { get; construct; }

    public Show (string title, Video first_video) {
        Object (
            title: title
        );

        first_video.poster_changed.connect (() => {
            poster = first_video.poster;
        });
    }

    construct {
        episodes = new ListStore (typeof (Video));
    }

    public void add_video (Video video) {
        video.trashed.connect (() => {
            uint position;
            episodes.find (video, out position);
            episodes.remove (position);
        });

        episodes.insert_sorted (video, Services.LibraryManager.library_item_sort_func);
    }

    public void trash () {
        for (int i = 0; i < episodes.get_n_items (); i++) {
            ((Video) episodes.get_item (i)).trash ();
        }
    }
}
