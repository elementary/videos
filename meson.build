project(
    'io.elementary.videos',
    'vala', 'c',
    version: '2.9.1'
)

i18n = import('i18n')
gnome = import('gnome')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language:'c')

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

gresource = gnome.compile_resources(
    'gresource',
    'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data'
)

subdir('src')
meson.add_install_script('meson/post_install.py')
subdir('data')
subdir('po')
