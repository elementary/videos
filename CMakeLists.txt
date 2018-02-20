cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)

enable_testing ()
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

project (io.elementary.videos C)

set (APP_NAME "Videos")
set (DATADIR ${CMAKE_INSTALL_PREFIX}/share)
set (PKGDATADIR ${DATADIR}/${CMAKE_PROJECT_NAME})
set (GETTEXT_PACKAGE ${CMAKE_PROJECT_NAME})
set (RELEASE_NAME "A modern media player.")
set (VERSION "0.2.5")
set (VERSION_INFO "The Red Comet")

add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

# Comment this out to enable C compiler warnings
add_definitions (-w)

add_subdirectory (src)
add_subdirectory (data)
add_subdirectory (po)

# uninstall target
configure_file (
    "${CMAKE_SOURCE_DIR}/cmake/Uninstall.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake"
    IMMEDIATE @ONLY)

add_custom_target (uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/Uninstall.cmake)
