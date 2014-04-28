set (HICOLOR_DIR ${DATADIR}/icons/hicolor)
# Data
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/16/audience.svg DESTINATION ${HICOLOR_DIR}/16x16/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/24/audience.svg DESTINATION ${HICOLOR_DIR}/24x24/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/32/audience.svg DESTINATION ${HICOLOR_DIR}/32x32/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/48/audience.svg DESTINATION ${HICOLOR_DIR}/48x48/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/64/audience.svg DESTINATION ${HICOLOR_DIR}/64x64/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/icons/128/audience.svg DESTINATION ${HICOLOR_DIR}/128x128/apps/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/audience.desktop DESTINATION ${DATADIR}/applications/)

include(GSettings)
add_schema (org.pantheon.audience.gschema.xml)
