# libfootheme
fb2k theming library for macOS

Provides the following:
- Color theming
- UI asset changing
    - Changing play, forward, pause, etc. button assets
- Background config
    - Transparency/image/blur
- Font Customization
    - Custom fonts, size, color

For layouts, use fb2k's layout feature. \
**libfootheme does not provide compatibility with .fth/.fcl files.**

```bash
curl https://parkuoa.github.io/libfootheme/install.sh | sh
```

This script will fully install libfootheme (feel free to check the script beforehand)

# Building
- Build with ```make```, optionally providing ```FOOBAR_APP_PATH``` (default is /Applications/foobar2000.app)

You can then run fb2k with libfootheme using ```make run``` or by permanently installing the library (see below)

To interact with libfootheme, use the **Theme** menu bar item (if you don't see it, unfocus the fb2k window and then focus again, or press on any other menu bar item. It will now pop up)


## Installing
To permanently install libfootheme, run ```make install```

This installs ```libfootheme.dylib``` to ```fb2k```/Contents/Frameworks and modifies the ```Info.plist``` to hook it on launch using ```DYLD_INSERT_LIBRARIES``` (this won't work if the executable is launched directly - in that case manually set ```DYLD_INSERT_LIBRARIES=path/to/libfootheme.dylib```)

## Uninstalling
```make uninstall``` or:
```bash
curl https://parkuoa.github.io/libfootheme/uninstall.sh | sh
```
