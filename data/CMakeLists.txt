set (HICOLOR_DIR ${DATADIR}/icons/hicolor)
# Data
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/audience.desktop DESTINATION ${DATADIR}/applications/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/audience.appdata.xml DESTINATION ${DATADIR}/appdata/)

include(GSettings)
add_schema (org.pantheon.audience.gschema.xml)
