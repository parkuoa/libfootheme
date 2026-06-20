/*
    ui_assets.h
    naomisphere <parou.sia@tuta.io>
    License: GNU General Public License v3.0 or later
*/

#ifndef ui_assets_h
#define ui_assets_h

#import <Foundation/Foundation.h>

/* icon file structure */
typedef struct {
    NSString *filename;
    NSString *displayName;
} IconFile;

/* list of non-nib (standard image) files */
static IconFile iconFiles[] = {
    {@"btn-play256.png", @"Play Button"},
    {@"btn-pause256.png", @"Pause Button"},
    {@"btn-next256.png", @"Next Button"},
    {@"btn-prev256.png", @"Previous Button"},
    {@"btn-stop256.png", @"Stop Button"},
    {@"btn-rand256.png", @"Random Button"},
    {@"album-art-stub.png", @"Album Art Stub"}
};

/* Number of icons in the array */
static const int iconCount = sizeof(iconFiles) / sizeof(iconFiles[0]);

#endif /* ui_assets_h */