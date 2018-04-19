# Videos
[![Translation status](https://l10n.elementary.io/widgets/videos/-/svg-badge.svg)](https://l10n.elementary.io/projects/videos/?utm_source=widget)

![Videos Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* intltool
* libclutter-gst-3.0-dev
* libclutter-gtk-1.0-dev
* libgranite-dev
* libgstreamer-plugins-base1.0-dev
* libgstreamer1.0-dev
* valac

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`, then execute with `io.elementary.videos`

    sudo make install
    io.elementary.videos
