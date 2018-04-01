conf_data = configuration_data()
conf_data.set('APP_NAME', 'Videos')
conf_data.set('DATADIR', get_option('datadir')) 
conf_data.set('PKGDATADIR', get_option('datadir') + '/' + meson.project_name())
conf_data.set('GETTEXT_PACKAGE', meson.project_name())
conf_data.set('RELEASE_NAME', 'A modern media player.')
conf_data.set('VERSION', '0.2.5')
conf_data.set('VERSION_INFO', 'The Red Comet')
config_header = configure_file(
    input: 'Config.vala.in',
    output: 'Config.vala',
    configuration: conf_data
)

executable(
    meson.project_name(),
    'Audience.vala',
    'Consts.vala',
    'DiskManager.vala',
    'Settings.vala',
    'Utils.vala',
    'Window.vala',
    'ZeitgeistManager.vala',
    'Objects/Video.vala',
    'Services/DirictoryMonitoring.vala',
    'Services/Inhibitor.vala',
    'Services/LibraryManager.vala',
    'Services/Thubnailer.vala',
    'Widgets/NavigationButton.vala',
    'Widgets/WelcomePage.vala',
    'Widgets/Library/EpisodesPage.vala',
    'Widgets/Library/LibraryItem.vala',
    'Widgets/Library/LibraryPage.vala',
    'Widgets/Player/BottomBar.vala',
    'Widgets/Player/PlayerPage.vala',
    'Widgets/Player/Playlist.vala',
    'Widgets/Player/PlaylistPopover.vala',
    'Widgets/Player/PreviewPopover.vala',
    'Widgets/Player/SettingsPopover.vala',
    'Widgets/Player/TimeWidget.vala',
    config_header,
    
    vala_args: [
        '--enable-experimental',
        '--target-glib=2.32',
    ],

    dependencies: [
        dependency('clutter-gst-3.0'),
        dependency('clutter-gtk-1.0'),
        dependency('gdk-x11-3.0'),
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gstreamer-1.0'),
        dependency('gstreamer-pbutils-1.0'),
        dependency('gstreamer-video-1.0'),
        dependency('gstreamer-tag-1.0'),
        dependency('gtk+-3.0'),
        
        meson.get_compiler('vala').find_library('posix'),
        meson.get_compiler('c').find_library('m', required : false)
    ],
    install : true
)
