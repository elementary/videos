# Videos
[![Translation status](https://l10n.elementary.io/widgets/videos/-/svg-badge.svg)](https://l10n.elementary.io/projects/videos/?utm_source=widget)

![Videos Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

Run `flatpak-builder` to configure the build environment, download dependencies, build, and install

```bash
    flatpak-builder build io.elementary.videos.yml --user --install --force-clean --install-deps-from=appcenter
```

Then execute with

```bash
    flatpak run io.elementary.videos
```
