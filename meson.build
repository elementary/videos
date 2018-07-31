project(
    'io.elementary.videos',
    'vala', 'c',
    version: '2.6.1'
)

i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language:'c')


subdir('src')
meson.add_install_script('meson/post_install.py')
subdir('data')
subdir('po')
