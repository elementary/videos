cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project (audience)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/audience")
set (GETTEXT_PACKAGE "audience")
set (RELEASE_NAME "A simple, modern media player.")
set (VERSION "0.1")
set (VERSION_INFO "The Red Comet")

# Data
file (GLOB _datafiles "${CMAKE_CURRENT_SOURCE_DIR}/data/style/*.css")
install (FILES ${_datafiles} DESTINATION ${PKGDATADIR}/style)
file (GLOB _imagefiles "${CMAKE_CURRENT_SOURCE_DIR}/data/style/images/*")
install (FILES ${_imagefiles} DESTINATION ${PKGDATADIR}/style/images)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/scalable/audience.svg DESTINATION ${DATADIR}/icons/hicolor/scalable/apps/)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/audience.desktop DESTINATION ${DATADIR}/applications/)

# Configure file
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)

set (AUDIENCE_DEPS "gstreamer-0.10;gstreamer-interfaces-0.10;gdk-x11-3.0;gtk+-3.0")

find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED ${AUDIENCE_DEPS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.12.0" MINIMUM)

include (ValaPrecompile)
vala_precompile (VALA_C
    Audience/Audience.vala
    Audience/Widgets/AppMenu.vala
PACKAGES
	${AUDIENCE_DEPS}
CUSTOM_VAPIS
	vapi/config.vapi
OPTIONS
	--thread
)

add_definitions (${DEPS_CFLAGS} -include config.h)
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

add_executable (audience ${VALA_C})
install (TARGETS audience RUNTIME DESTINATION bin)