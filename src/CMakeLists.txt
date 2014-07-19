# Vala stuff
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.22" MINIMUM)
include (ValaPrecompile)

# Configure file
set (CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/config.vala)
configure_file (${CMAKE_CURRENT_SOURCE_DIR}/Config.vala.cmake ${CONFIG_FILE})

# pkgconfig, real C code
find_package (PkgConfig)

set (PKG_DEPS granite clutter-gtk-1.0 gstreamer-1.0 gstreamer-pbutils-1.0 gstreamer-tag-1.0)
set (VALA_DEPS 
    granite
    clutter-gtk-1.0
    gdk-x11-3.0
    gstreamer-1.0
    gstreamer-pbutils-1.0
    gstreamer-tag-1.0
)

pkg_check_modules (DEPS REQUIRED ${PKG_DEPS})
set (CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})
link_directories (${DEPS_LIBRARY_DIRS})
add_definitions (${CFLAGS})

set (EXEC_NAME ${CMAKE_PROJECT_NAME})

vala_precompile (VALA_C ${EXEC_NAME}
    ${CONFIG_FILE}
    Audience.vala
    Consts.vala
    Settings.vala
    Utils.vala
    DiskManager.vala
    Widgets/BottomBar.vala
    Widgets/SettingsPopover.vala
    Widgets/PreviewPopover.vala
    Widgets/TimeWidget.vala
    Widgets/Playlist.vala
    Widgets/PlaylistPopover.vala
    Widgets/VideoPlayer.vala
    desktop-launcher.vala
  PACKAGES
    ${VALA_DEPS}
  OPTIONS
    --enable-experimental
    --target-glib=2.32 # Remember to keep this updated.
    --thread
    -g
)

add_executable (${EXEC_NAME} ${VALA_C})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES})
install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)