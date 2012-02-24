cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)
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
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/scalable/audience.svg DESTINATION ${DATADIR}/icons/hicolor/scalable/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/audience.desktop DESTINATION ${DATADIR}/applications/)

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/Audience/Config.vala.cmake ${CMAKE_BINARY_DIR}/Audience/Config.vala)
add_definitions(-DGETTEXT_PACKAGE="audience")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED granite gtk+-3.0 clutter-gtk-1.0 clutter-gst-1.0 gstreamer-pbutils-0.10)
add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})
find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.15.1" MINIMUM)
include(ValaPrecompile)
vala_precompile(VALA_C
    Audience/Audience.vala
    ${CMAKE_BINARY_DIR}/Audience/Config.vala
    Audience/Widgets/TagView.vala
    Audience/Widgets/Previewer.vala
PACKAGES
    gtk+-3.0
    granite
    clutter-gst-1.0
    clutter-gtk-1.0
    gdk-x11-3.0
    gstreamer-pbutils-0.10
OPTIONS
    --thread
)

add_subdirectory (po)
add_executable(audience ${VALA_C})
install (TARGETS audience RUNTIME DESTINATION bin)
