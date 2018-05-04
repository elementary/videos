# Videos
[![Translation status](https://l10n.elementary.io/widgets/videos/-/svg-badge.svg)](https://l10n.elementary.io/projects/videos/?utm_source=widget)

![Videos Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* intltool
* libclutter-gst-3.0-dev
* libclutter-gtk-1.0-dev
* libgranite-dev
* libgstreamer-plugins-base1.0-dev
* libgstreamer1.0-dev
* meson
* valac


    
Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja
    
To install, use `ninja install`, then execute with `io.elementary.videos`

    sudo ninja install
    io.elementary.videos
