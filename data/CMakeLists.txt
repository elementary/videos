set (HICOLOR_DIR ${DATADIR}/icons/hicolor)
# Data
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/audience.desktop DESTINATION ${DATADIR}/applications/)

include(GSettings)
add_schema (org.pantheon.audience.gschema.xml)
