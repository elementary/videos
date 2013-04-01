cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

enable_testing ()
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project (audience)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/audience")
set (GETTEXT_PACKAGE "audience")
set (RELEASE_NAME "A modern media player.")
set (VERSION "0.1")
set (VERSION_INFO "The Red Comet")

# Data
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/16/audience.svg DESTINATION ${DATADIR}/icons/hicolor/16x16/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/24/audience.svg DESTINATION ${DATADIR}/icons/hicolor/24x24/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/32/audience.svg DESTINATION ${DATADIR}/icons/hicolor/32x32/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/48/audience.svg DESTINATION ${DATADIR}/icons/hicolor/48x48/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/64/audience.svg DESTINATION ${DATADIR}/icons/hicolor/64x64/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/128/audience.svg DESTINATION ${DATADIR}/icons/hicolor/128x128/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/audience.desktop DESTINATION ${DATADIR}/applications/)

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/Audience/Config.vala.cmake ${CMAKE_BINARY_DIR}/Audience/Config.vala)
add_definitions(-DGETTEXT_PACKAGE="audience")

set (CPACK_PACKAGE_VERSION ${VERSION})
set (CPACK_SOURCE_GENERATOR "TGZ")
set (CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${CPACK_PACKAGE_VERSION}")
set (CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;/.bzrignore;~$;${CPACK_SOURCE_IGNORE_FILES}")

include (CPack)
add_custom_target (dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

find_package(PkgConfig)
pkg_check_modules(CLUTTER_GST_1 QUIET clutter-gst-2.0)
if (CLUTTER_GST_1_FOUND)
	set(CLUTTER_GST_FLAGS "--define=HAS_CLUTTER_GST_1")
	set(GST_PACKAGES gstreamer-1.0 gstreamer-pbutils-1.0 gstreamer-tag-1.0)
else (CLUTTER_GST_1_FOUND)
	set(CLUTTER_GST_FLAGS "")
	set(GST_PACKAGES gstreamer-0.10 gstreamer-pbutils-0.10 gstreamer-tag-0.10 gstreamer-interfaces-0.10)
endif (CLUTTER_GST_1_FOUND)

pkg_check_modules(DEPS REQUIRED granite clutter-gtk-1.0 ${GST_PACKAGES})

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})
find_package(Vala REQUIRED)
include(ValaVersion)

ensure_vala_version("0.16.1" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C
    Audience/Audience.vala
    Audience/Consts.vala
    Audience/Settings.vala
    Audience/Utils.vala
    ${CMAKE_BINARY_DIR}/Audience/Config.vala
    Audience/Widgets/TagView.vala
    Audience/Widgets/Button.vala
    Audience/Widgets/ControlsBar.vala
    Audience/Widgets/LLabel.vala
    Audience/Widgets/MediaSlider.vala
    Audience/Widgets/TopPanel.vala
    Audience/Widgets/Playlist.vala
    Audience/Widgets/VideoPlayer.vala
    Audience/desktop-launcher.vala
PACKAGES
    granite
    clutter-gtk-1.0
    gdk-x11-3.0
	${GST_PACKAGES}
OPTIONS
	${CLUTTER_GST_FLAGS}
    --thread
    -g
)


include(GSettings)
add_schema ("data/org.pantheon.audience.gschema.xml")

add_subdirectory (po)
add_executable(audience ${VALA_C})
install (TARGETS audience RUNTIME DESTINATION bin)
