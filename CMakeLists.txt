cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

enable_testing ()
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project (audience)

set (DATADIR ${CMAKE_INSTALL_PREFIX}/share)
set (PKGDATADIR ${DATADIR}/${CMAKE_PROJECT_NAME})
set (GETTEXT_PACKAGE ${CMAKE_PROJECT_NAME})
set (RELEASE_NAME "A modern media player.")
set (VERSION "0.1")
set (VERSION_INFO "The Red Comet")

add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions (-w)

# Data
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/16/audience.svg DESTINATION ${DATADIR}/icons/hicolor/16x16/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/24/audience.svg DESTINATION ${DATADIR}/icons/hicolor/24x24/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/32/audience.svg DESTINATION ${DATADIR}/icons/hicolor/32x32/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/48/audience.svg DESTINATION ${DATADIR}/icons/hicolor/48x48/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/64/audience.svg DESTINATION ${DATADIR}/icons/hicolor/64x64/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/128/audience.svg DESTINATION ${DATADIR}/icons/hicolor/128x128/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/audience.desktop DESTINATION ${DATADIR}/applications/)

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)

set (CPACK_PACKAGE_VERSION ${VERSION})
set (CPACK_SOURCE_GENERATOR "TGZ")
set (CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${CPACK_PACKAGE_VERSION}")
set (CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;/.bzrignore;~$;${CPACK_SOURCE_IGNORE_FILES}")

include (CPack)
add_custom_target (dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED granite clutter-gtk-1.0 gstreamer-1.0 gstreamer-pbutils-1.0 gstreamer-tag-1.0)

add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})
find_package (Vala REQUIRED)
include (ValaVersion)

ensure_vala_version("0.16.1" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C
    ${CMAKE_BINARY_DIR}/src/Config.vala
    src/Audience.vala
    src/Consts.vala
    src/Settings.vala
    src/Utils.vala
    src/Widgets/TagView.vala
    src/Widgets/Button.vala
    src/Widgets/ControlsBar.vala
    src/Widgets/LLabel.vala
    src/Widgets/MediaSlider.vala
    src/Widgets/TopPanel.vala
    src/Widgets/Playlist.vala
    src/Widgets/VideoPlayer.vala
    src/desktop-launcher.vala
PACKAGES
    granite
    clutter-gtk-1.0
    gdk-x11-3.0
    gstreamer-1.0
    gstreamer-pbutils-1.0
    gstreamer-tag-1.0
OPTIONS
    --enable-experimental
    --target-glib=2.32
    --thread
    -g
)


include(GSettings)
add_schema ("data/org.pantheon.audience.gschema.xml")

add_subdirectory (po)
add_executable(${CMAKE_PROJECT_NAME} ${VALA_C})
install (TARGETS ${CMAKE_PROJECT_NAME} RUNTIME DESTINATION bin)

# uninstall target
configure_file(
    "${CMAKE_SOURCE_DIR}/cmake/Uninstall.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake"
    IMMEDIATE @ONLY)

add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake)
