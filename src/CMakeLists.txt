# Vala stuff
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.28" MINIMUM)
include (ValaPrecompile)

# Configure file
set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/config.vala)
configure_file (${CMAKE_CURRENT_SOURCE_DIR}/Config.vala.cmake ${CONFIG_FILE})

# pkgconfig, real C code
find_package (PkgConfig)

set (PKG_DEPS
    granite>=0.4.1
    clutter-gtk-1.0
    gstreamer-1.0
    gstreamer-pbutils-1.0
    gstreamer-video-1.0
    gstreamer-tag-1.0
    clutter-gst-3.0
)

set (VALA_DEPS
    granite>=0.4.1
    clutter-gtk-1.0
    gdk-x11-3.0
    gstreamer-1.0
    gstreamer-pbutils-1.0
    gstreamer-video-1.0
    gstreamer-tag-1.0
    clutter-gst-3.0
)

pkg_check_modules (DEPS REQUIRED ${PKG_DEPS})

set (CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})
link_directories (${DEPS_LIBRARY_DIRS})
add_definitions (${CFLAGS})

set (EXEC_NAME ${CMAKE_PROJECT_NAME})

vala_precompile (VALA_C ${EXEC_NAME}
    ${CONFIG_FILE}
    ZeitgeistManager.vala
    Audience.vala
    Consts.vala
    Settings.vala
    Utils.vala
    DiskManager.vala
    Window.vala

    Widgets/WelcomePage.vala
    Widgets/NavigationButton.vala

    Widgets/Player/BottomBar.vala
    Widgets/Player/SettingsPopover.vala
    Widgets/Player/PreviewPopover.vala
    Widgets/Player/TimeWidget.vala
    Widgets/Player/Playlist.vala
    Widgets/Player/PlaylistPopover.vala
    Widgets/Player/PlayerPage.vala

    Widgets/Library/LibraryPage.vala
    Widgets/Library/LibraryItem.vala
    Widgets/Library/EpisodesPage.vala

    Services/Inhibitor.vala
    Services/DirectoryMonitoring.vala
    Services/LibraryManager.vala
    Services/Thumbnailer.vala

    Objects/Video.vala
  PACKAGES
    ${VALA_DEPS}
  OPTIONS
    ${GLOBAL_VALAC_OPTIONS}
    --enable-experimental
    --target-glib=2.32 # Remember to keep this updated.
    --thread
)

add_executable (${EXEC_NAME} ${VALA_C})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES})
install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)
