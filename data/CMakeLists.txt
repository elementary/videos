include (Translations)

set (HICOLOR_DIR ${DATADIR}/icons/hicolor)

configure_file_translation (audience.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/audience.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation (audience.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/audience.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/audience.desktop DESTINATION ${DATADIR}/applications/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/audience.appdata.xml DESTINATION ${DATADIR}/appdata/)

include (GSettings)
add_schema (org.pantheon.audience.gschema.xml)
