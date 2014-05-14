
namespace Audience {

    public class Settings : Granite.Services.Settings {
        public bool move_window          {get; set;}
        public bool keep_aspect          {get; set;}
        public bool resume_videos        {get; set;}
        public string last_played_videos {get; set;} /*video1,time,video2,time2,...*/
        public string last_folder        {get; set;}
        public bool playback_wait        {get; set;}
        public bool stay_on_top          {get; set;}
        public bool show_window_decoration {get; set;}

        public Settings () {
            base ("org.pantheon.Audience");
        }

    }
}
