public interface Audience.Objects.LibraryInterface : Object {
    public abstract string title { get; construct; }
    public abstract Gdk.Pixbuf? poster { get; protected set; default = null; }

    public abstract void trash ();
}
