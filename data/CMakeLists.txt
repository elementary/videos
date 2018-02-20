include (Translations)

set (HICOLOR_DIR ${DATADIR}/icons/hicolor)

# We need to create two temporary desktop files in order to have all translations available.
set (APP_NAME "Videos")
configure_file(io.elementary.videos.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.videos.desktop.in)
set (APP_NAME "Audience")
configure_file(io.elementary.videos.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/audience-original.desktop.in)

if (BUILD_FOR_ELEMENTARY)
    configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/io.elementary.videos.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.videos.desktop ${CMAKE_SOURCE_DIR}/po/)
else ()
    configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/audience-original.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.videos.desktop ${CMAKE_SOURCE_DIR}/po/)
endif ()

configure_file_translation (io.elementary.videos.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.videos.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.videos.desktop DESTINATION ${DATADIR}/applications/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.videos.appdata.xml DESTINATION ${DATADIR}/appdata/)

include (GSettings)

add_schema (io.elementary.videos.gschema.xml)
