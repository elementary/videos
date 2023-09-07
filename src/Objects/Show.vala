public class Audience.Objects.Show : Object, LibraryInterface {
    public string title { get; construct; }
    public Gdk.Paintable poster { get; set; }
    public string uri { get; set; }

    public ListStore episodes { get; construct; }

    public Show (string title) {
        Object (
            title: title
        );
    }

    construct {
        episodes = new ListStore (typeof (Video));
    }

    public void add_video (Video video) {
        episodes.append (video);
    }
}
