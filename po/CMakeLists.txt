include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    ../src/Widgets
    DESKTOP_FILES
        ../data/audience.desktop.in
    APPDATA_FILES
        ../data/audience.appdata.xml.in
)
