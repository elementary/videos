include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    ../src/Widgets
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/org.pantheon.audience.desktop.in
        ${CMAKE_BINARY_DIR}/data/audience-original.desktop.in
    APPDATA_FILES
        ../data/io.elementary.videos.appdata.xml.in
)
