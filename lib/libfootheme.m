/*
    libfootheme.m
    naomisphere <parou.sia@tuta.io>
    License: GNU General Public License v3.0 or later
*/

/*
    --------------------------------------------------
    version date: June 20, 2026
    --------------------------------------------------
*/

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "include/libfootheme.h"
// #import "include/classes.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#define YELLOW "\033[0;33m"
#define RESET "\033[0m"
#define foo_log(fmt, ...) NSLog(@"\x1B[1;33mlibfootheme\x1B[0m: " fmt, ##__VA_ARGS__)

/* some forward declarations for UI elements */
void InitUIElements(void);
void OpenUIElementsWindow(id sender);

// -------------------------------------------
/* forward declarations */
void save_config(void);
void apply_theme(void);
void apply_playlist_colors(void);
void update_derv_colors(void);
void load_custom_font(void);
void LoadSettings(void);
void import_config(void);
void export_config(void);
// -------------------------------------------

// -------------------------------------------
/* theme colors */
#define DARK_BG [NSColor colorWithCalibratedRed:0.12 green:0.12 blue:0.12 alpha:1.0]
#define TEXT_PRIMARY [NSColor colorWithCalibratedRed:0.95 green:0.95 blue:0.95 alpha:1.0]
// -------------------------------------------

// -------------------------------------------
/* config settings */

NSString *fb2kThemeConfigFile(void) {
    NSString *home = NSHomeDirectory();
    NSString *folder = [home stringByAppendingPathComponent:@".config/foo"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:folder]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:folder
        withIntermediateDirectories:YES
        attributes:nil
        error:nil];
    }
    return [folder stringByAppendingPathComponent:@"theme.conf"];
}
// -------------------------------------------

// -------------------------------------------
/* theming settings and states */
typedef enum {
  ThemeStyleOpaque = 0,
  ThemeStyleTranslucent = 1,
  ThemeStyleBlurred = 2,
  ThemeStyleGlass = 3
} ThemeStyle;

/*
opaque = 0
translucent = 1
blurred = 2
glass = 3
*/

static ThemeStyle currentStyle = ThemeStyleOpaque;
static CGFloat currentOpacity = 0.84;
static CGFloat currentBlurRadius = 20.0;

static NSColor *primaryColor = nil;
static BOOL useCustomPrimary = NO;

static NSColor *playlistColor = nil;
static BOOL useCustomPlaylist = NO;

static NSColor *fontColor = nil;
static BOOL useCustomFontColor = NO;

static NSString *backgroundImagePath = nil;
static CGFloat backgroundImageOpacity = 0.5;
static BOOL useBackgroundImage = NO;

static CGFloat sectionTransparency = 0.85;
static BOOL useSectionTransparency = NO;

static NSColor *currentBackgroundColor = nil;  // main (sunk) window view
static NSColor *playlistBackgroundColor = nil; // "playlist view"
static NSColor *selectionColor = nil;          // FIX:selection highlight

static CGFloat currentFontSize = 13.0;
static NSString *currentFontName = @"Helvetica Neue";
static NSString *customFontPath = nil;

/* store blurs p/ window */
static NSMutableDictionary *blurViews = nil;

void import_config(void) {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  openPanel.title = @"Import Theme Config";
  openPanel.allowedFileTypes = @[@"conf", @"txt"];
  openPanel.allowsMultipleSelection = NO;
  openPanel.canChooseDirectories = NO;
  openPanel.canChooseFiles = YES;
  openPanel.prompt = @"Import";

  NSWindow *keyWindow = [NSApp keyWindow];
  if (!keyWindow) {
    NSArray *windows = [NSApp windows];
    if (windows.count > 0) {
      keyWindow = windows[0];
    }
  }

  [openPanel beginSheetModalForWindow:keyWindow
    completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
        NSURL *fileURL = openPanel.URL;
        if (fileURL) {
            NSString *importPath = fileURL.path;
            NSFileManager *fm = [NSFileManager defaultManager];
            NSString *destPath = fb2kThemeConfigFile();
 
            if ([fm fileExistsAtPath:destPath]) {
            NSString *backupPath = [destPath stringByAppendingString:@".backup"];
            [fm copyItemAtPath:destPath toPath:backupPath error:nil];
            foo_log(@"backed up existing config to: %@", backupPath);
            }

            NSError *error = nil;
            [fm removeItemAtPath:destPath error:nil];
            [fm copyItemAtPath:importPath toPath:destPath error:&error];
            
            if (error) {
            foo_log(@"import failed: %@", error);
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Import Failed";
            alert.informativeText = error.localizedDescription;
            [alert runModal];
            } else {
            foo_log(@"config imported from: %@", importPath);

            LoadSettings();
            apply_theme();
            [[SettingsWindowController sharedInstance] updateUI];
            
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Import Successful";
            alert.informativeText = @"Applied imported config! Consider restarting foobar2000";
            [alert runModal];
            }
        }
        }
    }];
}

void export_config(void) {
  NSSavePanel *savePanel = [NSSavePanel savePanel];
  savePanel.title = @"Export Theme Config";
  savePanel.nameFieldStringValue = @"theme.conf";
  savePanel.allowedFileTypes = @[@"conf"];
  
  NSWindow *keyWindow = [NSApp keyWindow];
  if (!keyWindow) {
    NSArray *windows = [NSApp windows];
    if (windows.count > 0) {
      keyWindow = windows[0];
    }
  }

  [savePanel beginSheetModalForWindow:keyWindow
    completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
        NSURL *fileURL = savePanel.URL;
        if (fileURL) {
            NSString *exportPath = fileURL.path;
            NSString *sourcePath = fb2kThemeConfigFile();
            
            NSFileManager *fm = [NSFileManager defaultManager];
            if ([fm fileExistsAtPath:sourcePath]) {

            save_config();
            
            NSError *error = nil;
            [fm copyItemAtPath:sourcePath toPath:exportPath error:&error];
            
            if (error) {
                foo_log(@"export failed: %@", error);
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Export Failed";
                alert.informativeText = error.localizedDescription;
                [alert runModal];
            } else {
                foo_log(@"config exported to: %@", exportPath);
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Export Success";
                alert.informativeText = [NSString stringWithFormat:@"Config saved to:\n%@", exportPath];
                [alert runModal];
            }
            } else {
            save_config();
            [fm copyItemAtPath:sourcePath toPath:exportPath error:nil];
            foo_log(@"config exported to: %@", exportPath);
            }
        }
        }
    }];
}



void load_custom_font(void) {
  if (!customFontPath ||
      ![[NSFileManager defaultManager] fileExistsAtPath:customFontPath]) {
    return;
  }

  NSURL *fontURL = [NSURL fileURLWithPath:customFontPath];
  if (!fontURL)
  return;

  CFErrorRef error = NULL;
  if (!CTFontManagerRegisterFontsForURL
  ((__bridge CFURLRef)fontURL,kCTFontManagerScopeProcess, &error)) {
    foo_log(@"failed to register font: %@", error);
    return;
  }

  NSArray *descriptors =
  (__bridge_transfer NSArray *)CTFontManagerCreateFontDescriptorsFromURL(
    (__bridge CFURLRef)fontURL);
    if (descriptors.count > 0) {
        CTFontDescriptorRef descriptor =
        (__bridge CTFontDescriptorRef)descriptors[0];

    CFStringRef cfFontName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
    if (cfFontName) {
      NSString *fontName = (__bridge_transfer NSString *)cfFontName;
      currentFontName = fontName;
      foo_log(@"loaded custom font: %@", fontName);
    }
  }
}



void update_derv_colors(void) {
  if (!primaryColor) {
    primaryColor = DARK_BG;
  }

  if (currentStyle == ThemeStyleGlass) {
    currentBackgroundColor = [NSColor colorWithCalibratedWhite:0.1 alpha:0.1];
    playlistBackgroundColor = [NSColor colorWithCalibratedWhite:0.1 alpha:0.1];
  } else {
    currentBackgroundColor = primaryColor;
    if (useCustomPlaylist && playlistColor) {

      if (useSectionTransparency) {
        playlistBackgroundColor =
            [playlistColor colorWithAlphaComponent:sectionTransparency];
      } else {
        playlistBackgroundColor = playlistColor;
      }
    } else {

      if (useSectionTransparency) {
        playlistBackgroundColor = [primaryColor colorWithAlphaComponent:sectionTransparency];
      } else {
        playlistBackgroundColor = [primaryColor colorWithAlphaComponent:0.85];
      }
    }
  }

  CGFloat hue, saturation, brightness, alpha;
  [primaryColor getHue:&hue
    saturation:&saturation
    brightness:&brightness
    alpha:&alpha];

  CGFloat darkerBrightness = brightness * 0.6;
  selectionColor = [NSColor colorWithCalibratedHue:hue
    saturation:saturation
    brightness:darkerBrightness
    alpha:0.8];

  for (NSWindow *window in [NSApplication sharedApplication].windows) {
    NSString *className = NSStringFromClass([window class]);
    if (![className hasPrefix:@"NS"] && ![className hasPrefix:@"_NS"]) {
      if (currentStyle == ThemeStyleGlass) {
        window.backgroundColor = [NSColor clearColor];
      } else if (currentStyle == ThemeStyleTranslucent || currentStyle == ThemeStyleBlurred) {
        window.backgroundColor = [currentBackgroundColor colorWithAlphaComponent:currentOpacity];
      } else {
        window.backgroundColor = currentBackgroundColor;
      }
    }
  }

  foo_log(@"applied primary color scheme");
}



void save_config(void) {
  @try {
    NSMutableString *content = [NSMutableString string];
    [content appendFormat:@"style=%d\n", currentStyle];
    [content appendFormat:@"opacity=%.3f\n", currentOpacity];
    [content appendFormat:@"blurRadius=%.1f\n", currentBlurRadius];
    [content appendFormat:@"fontSize=%.1f\n", currentFontSize];
    [content appendFormat:@"fontName=%@\n", currentFontName ?: @"Helvetica Neue"];
    [content appendFormat:@"useCustomPrimary=%d\n", useCustomPrimary];
    if (customFontPath) {
      [content appendFormat:@"customFontPath=%@\n", customFontPath];
    }
    if (useCustomPrimary && primaryColor) {
      CGFloat r, g, b, a;
      [primaryColor getRed:&r green:&g blue:&b alpha:&a];
      [content appendFormat:@"primaryColor=%.3f,%.3f,%.3f,%.3f\n", r, g, b, a];
    }
    [content appendFormat:@"useCustomPlaylist=%d\n", useCustomPlaylist];
    if (useCustomPlaylist && playlistColor) {
      CGFloat r, g, b, a;
      [playlistColor getRed:&r green:&g blue:&b alpha:&a];
      [content appendFormat:@"playlistColor=%.3f,%.3f,%.3f,%.3f\n", r, g, b, a];
    }
    [content appendFormat:@"useCustomFontColor=%d\n", useCustomFontColor];
    if (useCustomFontColor && fontColor) {
      CGFloat r, g, b, a;
      [fontColor getRed:&r green:&g blue:&b alpha:&a];
      [content appendFormat:@"fontColor=%.3f,%.3f,%.3f,%.3f\n", r, g, b, a];
    }
    [content appendFormat:@"useBackgroundImage=%d\n", useBackgroundImage];
    if (useBackgroundImage && backgroundImagePath) {
      [content appendFormat:@"backgroundImagePath=%@\n", backgroundImagePath];
      [content appendFormat:@"backgroundImageOpacity=%.3f\n", backgroundImageOpacity];
    }
    [content
        appendFormat:@"useSectionTransparency=%d\n", useSectionTransparency];
    [content appendFormat:@"sectionTransparency=%.3f\n", sectionTransparency];
    [content writeToFile:fb2kThemeConfigFile()
    atomically:YES
    encoding:NSUTF8StringEncoding
    error:nil];
  } @catch (NSException *e) {
  }
}

void LoadSettings(void) {
  NSString *path = fb2kThemeConfigFile();
  if (![[NSFileManager defaultManager] fileExistsAtPath:path])
    return;

  @try {
    NSString *content = [NSString stringWithContentsOfFile:path
    encoding:NSUTF8StringEncoding
    error:nil];
    if (!content)
      return;

    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
      if (line.length == 0)
      continue;
      NSArray *parts = [line componentsSeparatedByString:@"="];
      if (parts.count != 2)
      continue;
      NSString *key = parts[0];
      NSString *value = parts[1];


      /* list of possible settings */
      if ([key isEqualToString:@"style"])
        currentStyle = [value intValue];
      else if ([key isEqualToString:@"opacity"])
        currentOpacity = [value floatValue];
      else if ([key isEqualToString:@"blurRadius"])
        currentBlurRadius = [value floatValue];
      else if ([key isEqualToString:@"fontSize"])
        currentFontSize = [value floatValue];
      else if ([key isEqualToString:@"fontName"])
        currentFontName = value;
      else if ([key isEqualToString:@"customFontPath"]) {
        customFontPath = value;
        load_custom_font();
      } else if ([key isEqualToString:@"useCustomPrimary"])
        useCustomPrimary = [value boolValue];
      else if ([key isEqualToString:@"primaryColor"]) {
        NSArray *components = [value componentsSeparatedByString:@","];
        if (components.count == 4) {
          CGFloat r = [components[0] floatValue];
          CGFloat g = [components[1] floatValue];
          CGFloat b = [components[2] floatValue];
          CGFloat a = [components[3] floatValue];
          primaryColor = [NSColor colorWithRed:r green:g blue:b alpha:a];
          useCustomPrimary = YES;
          update_derv_colors();
        }
      } else if ([key isEqualToString:@"useCustomPlaylist"])
        useCustomPlaylist = [value boolValue];
      else if ([key isEqualToString:@"playlistColor"]) {
        NSArray *components = [value componentsSeparatedByString:@","];
        if (components.count == 4) {
          CGFloat r = [components[0] floatValue];
          CGFloat g = [components[1] floatValue];
          CGFloat b = [components[2] floatValue];
          CGFloat a = [components[3] floatValue];
          playlistColor = [NSColor colorWithRed:r green:g blue:b alpha:a];
          useCustomPlaylist = YES;
          update_derv_colors();
        }
      } else if ([key isEqualToString:@"useCustomFontColor"])
        useCustomFontColor = [value boolValue];
      else if ([key isEqualToString:@"fontColor"]) {
        NSArray *components = [value componentsSeparatedByString:@","];
        if (components.count == 4) {
          CGFloat r = [components[0] floatValue];
          CGFloat g = [components[1] floatValue];
          CGFloat b = [components[2] floatValue];
          CGFloat a = [components[3] floatValue];
          fontColor = [NSColor colorWithRed:r green:g blue:b alpha:a];
          useCustomFontColor = YES;
        }
      } else if ([key isEqualToString:@"useBackgroundImage"])
        useBackgroundImage = [value boolValue];
      else if ([key isEqualToString:@"backgroundImagePath"]) {
        backgroundImagePath = value;
        useBackgroundImage = YES;
      } else if ([key isEqualToString:@"backgroundImageOpacity"]) {
        backgroundImageOpacity = [value floatValue];
      } else if ([key isEqualToString:@"useSectionTransparency"])
        useSectionTransparency = [value boolValue];
      else if ([key isEqualToString:@"sectionTransparency"]) {
        sectionTransparency = [value floatValue];
        useSectionTransparency = YES;
        update_derv_colors();
      }
    }
  } @catch (NSException *e) {
  }
}



NSView *findPlaylistView(NSView *view) {
  if (!view)
    return nil;
  NSString *className = NSStringFromClass([view class]);
  if ([className isEqualToString:@"FB2KPlaylistView"]) {
    return view;
  }
  for (NSView *subview in view.subviews) {
    NSView *found = findPlaylistView(subview);
    if (found)
    return found;
  }
  return nil;
}

void styleListsAndScrollViewsInView(NSView *view) {
  if (!view)
    return;

  NSString *className = NSStringFromClass([view class]);
  if ([className isEqualToString:@"fooOutlineView"] ||
      [className isEqualToString:@"FB2KTableViewEx"] ||
      [view isKindOfClass:[NSTableView class]] ||
      [view isKindOfClass:[NSOutlineView class]] ||
      [view isKindOfClass:NSClassFromString(@"fooOutlineView")] ||
      [view isKindOfClass:NSClassFromString(@"FB2KTableViewEx")]) {

    if ([view respondsToSelector:@selector(setBackgroundColor:)]) {
        [view performSelector:@selector(setBackgroundColor:)
        withObject:playlistBackgroundColor];
    }
    if ([view respondsToSelector:@selector(setNeedsDisplay:)]) {
        [view performSelector:@selector(setNeedsDisplay:) withObject:@YES];
    }

    NSView *parent = view.superview;
    while (parent) {
      if ([parent isKindOfClass:[NSScrollView class]]) {
        NSScrollView *scrollView = (NSScrollView *)parent;
        [scrollView setDrawsBackground:NO];
        break;
      }
      parent = parent.superview;
    }
  }

  for (NSView *subview in view.subviews) {
    styleListsAndScrollViewsInView(subview);
  }
}



NSImage *loadBackgroundImage(void) {
  if (!useBackgroundImage || !backgroundImagePath)
    return nil;
  if (![[NSFileManager defaultManager] fileExistsAtPath:backgroundImagePath])
    return nil;

  NSImage *image = [[NSImage alloc] initWithContentsOfFile:backgroundImagePath];
  if (!image)
    return nil;

  NSSize maxSize = NSMakeSize(1024, 1024);
  if (image.size.width > maxSize.width || image.size.height > maxSize.height) {
    NSImage *resized = [[NSImage alloc] initWithSize:maxSize];
    [resized lockFocus];

    [image drawInRect:NSMakeRect(0, 0, maxSize.width, maxSize.height)
    fromRect:NSZeroRect
    operation:NSCompositingOperationCopy
    fraction:1.0];

    [resized unlockFocus];
    return resized;
  }
  return image;
}

void applyBackgroundImageToView(NSView *view) {
  if (!view || !useBackgroundImage) return;

  NSImage *bgImage = loadBackgroundImage();
  if (!bgImage) return;

  view.wantsLayer = YES;

  CALayer *imageLayer = [CALayer layer];
  imageLayer.frame = view.bounds;
  imageLayer.contents = bgImage;
  imageLayer.contentsGravity = kCAGravityResizeAspectFill;
  imageLayer.opacity = backgroundImageOpacity;
  imageLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;

  NSMutableArray *toRemove = [NSMutableArray array];
  for (CALayer *sublayer in view.layer.sublayers) {
    if (sublayer.name &&
        [sublayer.name isEqualToString:@"foobarBackgroundImage"]) {
      [toRemove addObject:sublayer];
    }
  }
  for (CALayer *layer in toRemove) {
    [layer removeFromSuperlayer];
  }

  imageLayer.name = @"foobarBackgroundImage";
  [view.layer insertSublayer:imageLayer atIndex:0];
  [view setNeedsDisplay:YES];
}

void applyBackgroundImageToPlaylist(NSView *playlistView) {
  if (!playlistView || !useBackgroundImage) return;

  NSImage *bgImage = loadBackgroundImage();
  if (!bgImage) return;

  playlistView.wantsLayer = YES;

  CALayer *imageLayer = [CALayer layer];
  imageLayer.frame = playlistView.bounds;
  imageLayer.contents = bgImage;
  imageLayer.contentsGravity = kCAGravityResizeAspectFill;
  imageLayer.opacity = backgroundImageOpacity;
  imageLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;

  NSMutableArray *toRemove = [NSMutableArray array];
  for (CALayer *sublayer in playlistView.layer.sublayers) {
    if (sublayer.name &&
        [sublayer.name isEqualToString:@"foobarBackgroundImage"]) {
      [toRemove addObject:sublayer];
    }
  }
  for (CALayer *layer in toRemove) {
    [layer removeFromSuperlayer];
  }

  imageLayer.name = @"foobarBackgroundImage";
  [playlistView.layer insertSublayer:imageLayer atIndex:0];
  [playlistView setNeedsDisplay:YES];
}

void applyBackgroundImagesToAllViews(void) {
  if (!useBackgroundImage) return;

  for (NSWindow *window in [NSApplication sharedApplication].windows) {
    NSString *className = NSStringFromClass([window class]);
    if ([className hasPrefix:@"NS"] || [className hasPrefix:@"_NS"]) continue;

    if (window.contentView) {
      applyBackgroundImageToView(window.contentView);
    }

    NSView *playlistView = findPlaylistView(window.contentView);
    if (playlistView) {
      applyBackgroundImageToPlaylist(playlistView);
    }
  }
}



void apply_playlist_colors(void) {
  for (NSWindow *window in [NSApplication sharedApplication].windows) {
    styleListsAndScrollViewsInView(window.contentView);

    NSView *playlistView = findPlaylistView(window.contentView);
    if (!playlistView) continue;

    playlistView.wantsLayer = YES;
    playlistView.layer.backgroundColor = playlistBackgroundColor.CGColor;

    if ([playlistView respondsToSelector:@selector(tableView)]) {
      id tableView = [playlistView performSelector:@selector(tableView)];
      if (tableView) {
        if ([tableView respondsToSelector:@selector(setBackgroundColor:)]) {
          [tableView performSelector:@selector(setBackgroundColor:)
          withObject:playlistBackgroundColor];
        }
        if ([tableView respondsToSelector:@selector(setGridColor:)]) {
          [tableView performSelector:@selector(setGridColor:) withObject:
          [NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
        }
        if ([tableView respondsToSelector:@selector(setNeedsDisplay:)]) {
          [tableView performSelector:@selector(setNeedsDisplay:) withObject:@YES];
        }
      }
    }

    [playlistView setNeedsDisplay:YES];
  }

  if (useBackgroundImage) {
    applyBackgroundImagesToAllViews();
  }
}



void redrawSubviews(NSView *view) {
  if (!view)
    return;
  [view setNeedsDisplay:YES];
  [view displayIfNeeded];
  for (NSView *subview in view.subviews) {
    redrawSubviews(subview);
  }
}

void ForceRedrawAll(void) {
  for (NSWindow *window in [NSApplication sharedApplication].windows) {
    [window.contentView setNeedsDisplay:YES];
    [window.contentView displayIfNeeded];
    redrawSubviews(window.contentView);
    [window displayIfNeeded];
  }
}

/* worst function to ever exist */
void hunt_kill_blurs(NSWindow *window) {
  if (!window)
    return;
  if (!window.contentView)
    return;

  NSMutableArray *toRemove = [NSMutableArray array];
  for (NSView *subview in window.contentView.subviews) {
    if ([subview isKindOfClass:NSClassFromString(@"NSVisualEffectView")]) {
      [toRemove addObject:subview];
    }
  }
  for (NSView *view in toRemove) {
    [view removeFromSuperview];
  }

  if (blurViews) {
    [blurViews removeObjectForKey:@(window.hash)];
  }

  [window.contentView setNeedsDisplay:YES];
  [window.contentView displayIfNeeded];
}

static CALayer *findBackdropLayer(CALayer *layer) {
  if (!layer) return nil;
  if ([layer isKindOfClass:NSClassFromString(@"CABackdropLayer")]) {
    return layer;
  }
  for (CALayer *sublayer in layer.sublayers) {
    CALayer *found = findBackdropLayer(sublayer);
    if (found) return found;
  }
  return nil;
}

void applyBlurRadiusToVisualEffectView(NSVisualEffectView *blurView) {
  if (!blurView) return;
  blurView.wantsLayer = YES;

  CALayer *backdrop = findBackdropLayer(blurView.layer);
  if (backdrop) {
    @try {
      [backdrop setValue:@(currentBlurRadius)
      forKeyPath:@"filters.gaussianBlur.inputRadius"];
    } @catch (NSException *e) {
    }
  }
}

void RecreateBlurView(NSWindow *window) {
  if (!window) return;
  if (!window.contentView) return;

  hunt_kill_blurs(window);

  if (currentStyle != ThemeStyleBlurred && currentStyle != ThemeStyleGlass) return;

  if (@available(macOS 10.14, *)) {
    if (!blurViews)
    blurViews = [NSMutableDictionary dictionary];

    NSVisualEffectView *blurView =
    [[NSVisualEffectView alloc] initWithFrame:window.contentView.bounds];
    blurView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    if (currentStyle == ThemeStyleGlass) {
      blurView.material = NSVisualEffectMaterialUnderWindowBackground;
    } else {
      blurView.material = NSVisualEffectMaterialSidebar;
    }
    blurView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    blurView.state = NSVisualEffectStateActive;
    blurView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];

    applyBlurRadiusToVisualEffectView(blurView);

    [window.contentView addSubview:blurView positioned:NSWindowBelow relativeTo:nil];
    blurViews[@(window.hash)] = blurView;

    [window.contentView setNeedsDisplay:YES];
    [window.contentView displayIfNeeded];
  }
}

void ApplyWindowStyle(NSWindow *window) {
  if (!window) return;

  NSString *className = NSStringFromClass([window class]);
  if ([className hasPrefix:@"NS"] || [className hasPrefix:@"_NS"]) return;

  switch (currentStyle) {
  case ThemeStyleOpaque:
    window.titlebarAppearsTransparent = NO;
    window.opaque = YES;
    window.hasShadow = YES;
    window.backgroundColor = currentBackgroundColor;
    RecreateBlurView(window);
    break;

  case ThemeStyleTranslucent:
    window.titlebarAppearsTransparent = YES;
    window.opaque = NO;
    window.hasShadow = YES;
    window.backgroundColor =
    [currentBackgroundColor colorWithAlphaComponent:currentOpacity];
    RecreateBlurView(window);
    break;

  case ThemeStyleBlurred:
    window.titlebarAppearsTransparent = YES;
    window.opaque = NO;
    window.hasShadow = YES;
    window.backgroundColor =
    [currentBackgroundColor colorWithAlphaComponent:currentOpacity];
    RecreateBlurView(window);
    break;

  case ThemeStyleGlass:
    window.titlebarAppearsTransparent = YES;
    window.opaque = NO;
    window.hasShadow = YES;
    window.backgroundColor = [NSColor clearColor];
    RecreateBlurView(window);
    break;
  }

  [window.contentView setNeedsDisplay:YES];
  [window.contentView displayIfNeeded];
  [window displayIfNeeded];
}

void apply_theme(void) {
  update_derv_colors();

  for (NSWindow *window in [NSApplication sharedApplication].windows) {
    ApplyWindowStyle(window);
    if (window.contentView) {
        [window.contentView setNeedsDisplay:YES];
    }
  }

  ForceRedrawAll();
  apply_playlist_colors();

  if (useBackgroundImage) {
    applyBackgroundImagesToAllViews();
  }
}



static const void *OriginalDrawRectKey = &OriginalDrawRectKey;

void FoobarDrawRect(id self, SEL _cmd, NSRect dirtyRect) {
  NSString *className = NSStringFromClass([self class]);

  if ([className isEqualToString:@"FB2KButtonEx"] ||
      [className isEqualToString:@"FB2KSliderEx"] ||
      [className isEqualToString:@"FB2KTableViewEx"] ||
      [self isKindOfClass:[NSTableView class]] ||
      [self isKindOfClass:[NSOutlineView class]]) {

    NSValue *impValue =
    objc_getAssociatedObject([self class], OriginalDrawRectKey);

    if (impValue) {
        IMP originalIMP = (IMP)[impValue pointerValue];
        if (originalIMP) {
            ((void (*)(id, SEL, NSRect))originalIMP)(self, _cmd, dirtyRect);
      }
    }
    return;
  }

  NSValue *impValue =
  objc_getAssociatedObject([self class], OriginalDrawRectKey);

  if (impValue) {
    IMP originalIMP = (IMP)[impValue pointerValue];
    if (originalIMP) {
        ((void (*)(id, SEL, NSRect))originalIMP)(self, _cmd, dirtyRect);
    }
  }

  @try {
    if ([className hasPrefix:@"FB"] || [className hasPrefix:@"foo"] ||
        [className isEqualToString:@"fooAlbumListView"] ||
        [className isEqualToString:@"fooAlbumArtView"] ||
        [className isEqualToString:@"fooConsoleView"] ||
        [className isEqualToString:@"fooMessageView"] ||
        [className isEqualToString:@"fooVisCommonView"]) {

      [NSGraphicsContext saveGraphicsState];

      NSColor *drawColor = currentBackgroundColor;
      if (currentStyle == ThemeStyleTranslucent ||
          currentStyle == ThemeStyleBlurred) {
            drawColor =
            [currentBackgroundColor colorWithAlphaComponent:currentOpacity];
      } else if (currentStyle == ThemeStyleGlass) {
        drawColor = [NSColor colorWithCalibratedWhite:0.1 alpha:0.1];
      }
      [drawColor setFill];
      NSRectFill(dirtyRect);
      [NSGraphicsContext restoreGraphicsState];
    }
  } @catch (NSException *exception) {
  }
}

void HookDrawRect(Class cls) {
  if (!cls) return;

  Method drawMethod = class_getInstanceMethod(cls, @selector(drawRect:));

  if (drawMethod) {
    IMP originalIMP = method_getImplementation(drawMethod);
    NSValue *impValue = [NSValue valueWithPointer:originalIMP];
    objc_setAssociatedObject(cls, OriginalDrawRectKey, impValue,
    OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    method_setImplementation(drawMethod, (IMP)FoobarDrawRect);
  }
}



void ApplyFontToView(NSView *view) {
  if (!view)
  return;

  @try {
    NSString *className = NSStringFromClass([view class]);
    if ([className isEqualToString:@"FB2KPlaybackControlsBar"] ||
        [className isEqualToString:@"FB2KButtonEx"] ||
        [className isEqualToString:@"FB2KSliderEx"]) {
    return;
    }

    NSFont *font = nil;
    if (customFontPath &&
    [[NSFileManager defaultManager] fileExistsAtPath:customFontPath]) {
        font = [NSFont fontWithName:currentFontName size:currentFontSize];
      if (!font) {
        load_custom_font();
        font = [NSFont fontWithName:currentFontName size:currentFontSize];
      }
    }

    if (!font) {
        font = [NSFont fontWithName:currentFontName size:currentFontSize];
    }
    if (!font) {
        font = [NSFont systemFontOfSize:currentFontSize];
    }

    if ([view respondsToSelector:@selector(setFont:)]) {
        [view performSelector:@selector(setFont:) withObject:font];
    }

    NSColor *textColorToUse = (useCustomFontColor && fontColor) ? fontColor
    : TEXT_PRIMARY;
    if ([view respondsToSelector:@selector(setTextColor:)]) {
        [view performSelector:@selector(setTextColor:) withObject:textColorToUse];
    }

    for (NSView *subview in view.subviews) {
        ApplyFontToView(subview);
    }
  } @catch (NSException *e) {
  }
}



@interface FontFileTarget : NSObject
- (void)chooseFontFile:(id)sender;
- (void)resetFontFile:(id)sender;
@end

@implementation FontFileTarget
- (void)chooseFontFile:(id)sender {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  openPanel.title = @"Choose Font File";

  /* list of file types allowed by the font picker */
  openPanel.allowedFileTypes =
  @[ @"ttf", @"TTF", @"woff", @"woff2", @"otf", @"OTF" ];
  /* ttf and woff2 are known to fully work */

  openPanel.allowsMultipleSelection = NO;
  openPanel.canChooseDirectories = NO;
  openPanel.canChooseFiles = YES;
  openPanel.prompt = @"Choose Font";

  NSWindow *keyWindow = [NSApp keyWindow];
  if (!keyWindow) {
    NSArray *windows = [NSApp windows];
    if (windows.count > 0) {
      keyWindow = windows[0];
    }
  }

  [openPanel
  beginSheetModalForWindow:keyWindow
    completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *fileURL = openPanel.URL;
            if (fileURL) {
                customFontPath = fileURL.path;
                load_custom_font();
                apply_theme();
                save_config();
                [[NSNotificationCenter defaultCenter]
                postNotificationName:@"FontFileChanged" object:nil];
                foo_log(@"loaded font: %@", customFontPath);
            }
        }
    }];
}

- (void)resetFontFile:(id)sender {
  customFontPath = nil;
  currentFontName = @"Helvetica Neue";
  apply_theme();
  save_config();
  [[NSNotificationCenter defaultCenter] postNotificationName:@"FontFileChanged"
  object:nil];
  foo_log(@"reset font to default");
}
@end

static FontFileTarget *fontFileTarget = nil;



@interface BackgroundImageTarget : NSObject
- (void)chooseBackgroundImage:(id)sender;
- (void)resetBackgroundImage:(id)sender;
@end

@implementation BackgroundImageTarget
- (void)chooseBackgroundImage:(id)sender {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  openPanel.title = @"Choose Background Image";

  /* list of allowed image file types */
  openPanel.allowedFileTypes =
  @[ @"png", @"jpg", @"jpeg", @"tiff", @"bmp", @"gif", @"webp" ];

  openPanel.allowsMultipleSelection = NO;
  openPanel.canChooseDirectories = NO;
  openPanel.canChooseFiles = YES;
  openPanel.prompt = @"Choose Image";

  NSWindow *keyWindow = [NSApp keyWindow];
  if (!keyWindow) {
    NSArray *windows = [NSApp windows];
    if (windows.count > 0) {
      keyWindow = windows[0];
    }
  }

  [openPanel beginSheetModalForWindow:keyWindow
  completionHandler:^(NSModalResponse result) {
    if (result == NSModalResponseOK) {
        NSURL *fileURL = openPanel.URL;
    if (fileURL) {
        backgroundImagePath = fileURL.path;
        useBackgroundImage = YES;
        apply_theme();
        save_config();
        [[SettingsWindowController sharedInstance] updateUI];
        foo_log(@"loaded background image: %@", backgroundImagePath);
    }
    }
}];
}

- (void)resetBackgroundImage:(id)sender {
  backgroundImagePath = nil;
  useBackgroundImage = NO;
  apply_theme();
  save_config();
  [[SettingsWindowController sharedInstance] updateUI];
  foo_log(@"reset background image");
}
@end

static BackgroundImageTarget *bgImageTarget = nil;

@interface SliderTarget : NSObject
- (void)opacitySliderChanged:(id)sender;
- (void)blurSliderChanged:(id)sender;
- (void)fontSizeSliderChanged:(id)sender;
- (void)bgImageOpacitySliderChanged:(id)sender;
- (void)sectionTransparencySliderChanged:(id)sender;
@end

@implementation SliderTarget
- (void)opacitySliderChanged:(id)sender {
    if ([sender respondsToSelector:@selector(floatValue)]) {
        currentOpacity = [sender floatValue];
        apply_theme();
        save_config();
        [[SettingsWindowController sharedInstance] updateUI];
    }
}
- (void)blurSliderChanged:(id)sender {
    if ([sender respondsToSelector:@selector(floatValue)]) {
        currentBlurRadius = [sender floatValue];
        if (currentStyle == ThemeStyleBlurred || currentStyle == ThemeStyleGlass) {
            for (NSWindow *window in [NSApplication sharedApplication].windows) {
                RecreateBlurView(window);
            }
        }
    save_config();
    [[SettingsWindowController sharedInstance] updateUI];
  }
}
- (void)fontSizeSliderChanged:(id)sender {
  if ([sender respondsToSelector:@selector(floatValue)]) {
    currentFontSize = [sender floatValue];
    apply_theme();
    save_config();
    [[SettingsWindowController sharedInstance] updateUI];
  }
}
- (void)bgImageOpacitySliderChanged:(id)sender {
  if ([sender respondsToSelector:@selector(floatValue)]) {
    backgroundImageOpacity = [sender floatValue];

    if (useBackgroundImage) {
      apply_theme();
    }

    save_config();
    [[SettingsWindowController sharedInstance] updateUI];
  }
}
- (void)sectionTransparencySliderChanged:(id)sender {
  if ([sender respondsToSelector:@selector(floatValue)]) {
    sectionTransparency = [sender floatValue];
    useSectionTransparency = YES;
    update_derv_colors();
    apply_theme();
    save_config();
    [[SettingsWindowController sharedInstance] updateUI];
  }
}
@end

static SliderTarget *sliderTarget = nil;
// static SectionAlphaTarget *sectionAlphaTarget = nil;

@interface ColorPickerDelegate : NSObject <NSWindowDelegate>
@end

@implementation ColorPickerDelegate
- (void)changeColor:(id)sender {
  NSColor *newColor = [sender color];
  if (newColor) {
    primaryColor = newColor;
    useCustomPrimary = YES;
    update_derv_colors();
    apply_theme();
    save_config();
    foo_log(@"primary color changed!");
  }
}
@end

static ColorPickerDelegate *colorDelegate = nil;

NSArray *GetSystemFontNames(void) {
  NSMutableArray *fontNames = [NSMutableArray array];
  NSArray *families = [NSFontManager sharedFontManager].availableFontFamilies;
  for (NSString *family in families) {
    [fontNames addObject:family];
  }
  [fontNames sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  return fontNames;
}

static NSObject *importTarget = nil;
static NSObject *exportTarget = nil;

@implementation SettingsWindowController {
  NSWindow *_window;
  NSColorWell *_colorWell;
  NSColorWell *_playlistColorWell;
  NSColorWell *_fontColorWell;
  NSTextField *_opacityLabel;
  NSTextField *_blurLabel;
  NSTextField *_fontSizeLabel;
  NSTextField *_fontFileLabel;
  NSTextField *_bgImageOpacityLabel;
  NSTextField *_bgImageFileLabel;
  NSTextField *_sectionTransparencyLabel;
  NSButton *_opaqueButton;
  NSButton *_translucentButton;
  NSButton *_blurredButton;
  NSButton *_glassButton;
  NSButton *_resetColorButton;
  NSButton *_resetPlaylistColorButton;
  NSButton *_resetFontColorButton;
  NSButton *_closeButton;
  NSPopUpButton *_fontDropdown;
  NSButton *_chooseFontButton;
  NSButton *_resetFontButton;
  NSButton *_chooseBgImageButton;
  NSButton *_resetBgImageButton;
  NSButton *_importConfigButton;
  NSButton *_exportConfigButton;
}

+ (instancetype)sharedInstance {
    static SettingsWindowController *instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        instance = [[SettingsWindowController alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(updateFontLabel)
    name:@"FontFileChanged"
    object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)scrollToTop {
  if (!_window) return;

  NSScrollView *scrollView = (NSScrollView *)_window.contentView;
  if ([scrollView isKindOfClass:[NSScrollView class]]) {
    NSView *docView = [scrollView documentView];
    NSClipView *clipView = [scrollView contentView];
    if (docView && clipView) {
      CGFloat docHeight = docView.frame.size.height;
      CGFloat clipHeight = clipView.frame.size.height;
      CGFloat topY = docHeight - clipHeight;
      if (topY < 0) topY = 0;

      [clipView scrollToPoint:NSMakePoint(0, topY)];
      [scrollView reflectScrolledClipView:clipView];
    }
  }
}

- (void)showWindow {
  if (_window) {
    [_window makeKeyAndOrderFront:nil];
    [self updateUI];
    [self performSelector:@selector(scrollToTop) withObject:nil afterDelay:0.05];
    return;
  }

  [self createWindow];
  [_window center];
  [_window makeKeyAndOrderFront:nil];
  [self performSelector:@selector(scrollToTop) withObject:nil afterDelay:0.15];
}

- (void)closeWindow {
  if (_window) {
    _window.delegate = nil;
    [_window close];
    _window = nil;
  }
}

- (void)createWindow {
    NSRect windowRect = NSMakeRect(0, 0, 620, 750);
    _window = [[NSWindow alloc]
        initWithContentRect:windowRect
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                    NSWindowStyleMaskMiniaturizable |
                    NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
        
        _window.title = @"Theme Settings";
        /* NSFloatingWindowLevel caused it to always stay on top,
        it won't go away even after focusing out of fb2k */
        _window.level = NSNormalWindowLevel;
        _window.delegate = self;
        _window.releasedWhenClosed = NO;
        _window.minSize = NSMakeSize(580, 450);

  NSScrollView *scrollView =
  [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 620, 750)];
  scrollView.hasVerticalScroller = YES;
  scrollView.hasHorizontalScroller = NO;
  scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  scrollView.borderType = NSNoBorder;
  scrollView.drawsBackground = NO;

  CGFloat padding = 25;
  CGFloat width = 530;
  CGFloat labelWidth = 200;

  CGFloat totalHeight = 980;
  NSView *contentView =
  [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 600, totalHeight)];
  contentView.autoresizingMask = NSViewWidthSizable;
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [NSColor clearColor].CGColor;

  CGFloat yPos = 0;

  if (!sliderTarget)
    sliderTarget = [[SliderTarget alloc] init];
  if (!fontFileTarget)
    fontFileTarget = [[FontFileTarget alloc] init];
  if (!bgImageTarget)
    bgImageTarget = [[BackgroundImageTarget alloc] init];

  if (!importTarget) {
    importTarget = [[NSObject alloc] init];
    class_addMethod([importTarget class], @selector(importConfig:), (IMP)import_config, "v@:@");
  }
  if (!exportTarget) {
    exportTarget = [[NSObject alloc] init];
    class_addMethod([exportTarget class], @selector(exportConfig:), (IMP)export_config, "v@:@");
  }

  yPos += 20;
  _closeButton = [[NSButton alloc] initWithFrame:NSMakeRect(480, yPos, 90, 32)];
  _closeButton.title = @"Close";
  _closeButton.buttonType = NSButtonTypeMomentaryPushIn;
  _closeButton.bezelStyle = NSBezelStyleRounded;
  _closeButton.target = self;
  _closeButton.action = @selector(closeButtonClicked:);
  [contentView addSubview:_closeButton];
  yPos += 45;

  _sectionTransparencyLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(padding, yPos, labelWidth, 20)];
  _sectionTransparencyLabel.stringValue =
      [NSString stringWithFormat:@"Sidebar Opacity: %.2f", sectionTransparency];
  _sectionTransparencyLabel.font = [NSFont systemFontOfSize:13];
  _sectionTransparencyLabel.bezeled = NO;
  _sectionTransparencyLabel.drawsBackground = NO;
  _sectionTransparencyLabel.editable = NO;
  _sectionTransparencyLabel.selectable = NO;
  [contentView addSubview:_sectionTransparencyLabel];
  yPos += 24;

  NSSlider *sectionTransparencySlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(padding, yPos, width, 25)];
  sectionTransparencySlider.minValue = 0.1;
  sectionTransparencySlider.maxValue = 1.0;
  sectionTransparencySlider.floatValue = sectionTransparency;
  sectionTransparencySlider.continuous = YES;
  sectionTransparencySlider.target = sliderTarget;
  sectionTransparencySlider.action =
      @selector(sectionTransparencySliderChanged:);
  [contentView addSubview:sectionTransparencySlider];
  yPos += 35;

  NSBox *sectionSep =
  [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos, width, 1.5)];
  sectionSep.boxType = NSBoxSeparator;
  [contentView addSubview:sectionSep];
  yPos += 20;

  NSTextField *sectionHeader =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 300, 24)];
  sectionHeader.stringValue = @"Sidebar Transparency";
  sectionHeader.font = [NSFont boldSystemFontOfSize:16];
  sectionHeader.bezeled = NO;
  sectionHeader.drawsBackground = NO;
  sectionHeader.editable = NO;
  sectionHeader.selectable = NO;
  [contentView addSubview:sectionHeader];
  yPos += 35;



  _bgImageFileLabel =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 530, 16)];
  _bgImageFileLabel.stringValue = backgroundImagePath
  ? [NSString stringWithFormat:@"🖼️ %@", [backgroundImagePath lastPathComponent]]
  : @"No background image set";
  _bgImageFileLabel.font = [NSFont systemFontOfSize:11];
  _bgImageFileLabel.textColor = backgroundImagePath
  ? [NSColor controlTextColor]
  : [NSColor secondaryLabelColor];
  _bgImageFileLabel.bezeled = NO;
  _bgImageFileLabel.drawsBackground = NO;
  _bgImageFileLabel.editable = NO;
  _bgImageFileLabel.selectable = YES;
  [contentView addSubview:_bgImageFileLabel];
  yPos += 24;

  _chooseBgImageButton =
  [[NSButton alloc] initWithFrame:NSMakeRect(padding, yPos, 150, 28)];
  _chooseBgImageButton.title = @"Choose Image…";
  _chooseBgImageButton.buttonType = NSButtonTypeMomentaryPushIn;
  _chooseBgImageButton.bezelStyle = NSBezelStyleRounded;
  _chooseBgImageButton.target = bgImageTarget;
  _chooseBgImageButton.action = @selector(chooseBackgroundImage:);
  [contentView addSubview:_chooseBgImageButton];

  _resetBgImageButton =
  [[NSButton alloc] initWithFrame:NSMakeRect(padding + 165, yPos, 120, 28)];
  _resetBgImageButton.title = @"Remove Image";
  _resetBgImageButton.buttonType = NSButtonTypeMomentaryPushIn;
  _resetBgImageButton.bezelStyle = NSBezelStyleRounded;
  _resetBgImageButton.target = bgImageTarget;
  _resetBgImageButton.action = @selector(resetBackgroundImage:);
  [contentView addSubview:_resetBgImageButton];
  yPos += 35;

  _bgImageOpacityLabel = [[NSTextField alloc]
  initWithFrame:NSMakeRect(padding, yPos, labelWidth, 20)];
  _bgImageOpacityLabel.stringValue = [NSString
  stringWithFormat:@"Image Opacity: %.2f", backgroundImageOpacity];
  _bgImageOpacityLabel.font = [NSFont systemFontOfSize:13];
  _bgImageOpacityLabel.bezeled = NO;
  _bgImageOpacityLabel.drawsBackground = NO;
  _bgImageOpacityLabel.editable = NO;
  _bgImageOpacityLabel.selectable = NO;
  [contentView addSubview:_bgImageOpacityLabel];
  yPos += 24;

  NSSlider *bgImageOpacitySlider =
  [[NSSlider alloc] initWithFrame:NSMakeRect(padding, yPos, width, 25)];
  bgImageOpacitySlider.minValue = 0.05;
  bgImageOpacitySlider.maxValue = 1.0;
  bgImageOpacitySlider.floatValue = backgroundImageOpacity;
  bgImageOpacitySlider.continuous = YES;
  bgImageOpacitySlider.target = sliderTarget;
  bgImageOpacitySlider.action = @selector(bgImageOpacitySliderChanged:);
  [contentView addSubview:bgImageOpacitySlider];
  yPos += 35;

  NSBox *bgSep = [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos, width, 1.5)];
  bgSep.boxType = NSBoxSeparator;
  [contentView addSubview:bgSep];
  yPos += 20;

  NSTextField *bgHeader =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 300, 24)];
  bgHeader.stringValue = @"Background Image";
  bgHeader.font = [NSFont boldSystemFontOfSize:16];
  bgHeader.bezeled = NO;
  bgHeader.drawsBackground = NO;
  bgHeader.editable = NO;
  bgHeader.selectable = NO;
  [contentView addSubview:bgHeader];
  yPos += 35;



  _fontFileLabel =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 490, 16)];
  _fontFileLabel.stringValue =
      customFontPath
        ? [NSString
        stringWithFormat:@"📁 %@", [customFontPath lastPathComponent]]
        : @"No custom font loaded";

  _fontFileLabel.font = [NSFont systemFontOfSize:11];
  _fontFileLabel.textColor = customFontPath ? [NSColor controlTextColor]
  : [NSColor secondaryLabelColor];
  _fontFileLabel.bezeled = NO;
  _fontFileLabel.drawsBackground = NO;
  _fontFileLabel.editable = NO;
  _fontFileLabel.selectable = YES;
  [contentView addSubview:_fontFileLabel];
  yPos += 20;

  _chooseFontButton =
  [[NSButton alloc] initWithFrame:NSMakeRect(padding, yPos, 150, 28)];
  _chooseFontButton.title = @"Load Font File…";
  _chooseFontButton.buttonType = NSButtonTypeMomentaryPushIn;
  _chooseFontButton.bezelStyle = NSBezelStyleRounded;
  _chooseFontButton.target = fontFileTarget;
  _chooseFontButton.action = @selector(chooseFontFile:);
  [contentView addSubview:_chooseFontButton];

  _resetFontButton =
  [[NSButton alloc] initWithFrame:NSMakeRect(padding + 165, yPos, 120, 28)];
  _resetFontButton.title = @"Reset Font";
  _resetFontButton.buttonType = NSButtonTypeMomentaryPushIn;
  _resetFontButton.bezelStyle = NSBezelStyleRounded;
  _resetFontButton.target = fontFileTarget;
  _resetFontButton.action = @selector(resetFontFile:);
  [contentView addSubview:_resetFontButton];
  yPos += 35;

  NSTextField *fontPickerLabel =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 120, 20)];
  fontPickerLabel.stringValue = @"Font Family:";
  fontPickerLabel.font = [NSFont systemFontOfSize:13];
  fontPickerLabel.bezeled = NO;
  fontPickerLabel.drawsBackground = NO;
  fontPickerLabel.editable = NO;
  fontPickerLabel.selectable = NO;
  [contentView addSubview:fontPickerLabel];

  NSArray *fontNames = GetSystemFontNames();
  _fontDropdown = [[NSPopUpButton alloc]
      initWithFrame:NSMakeRect(padding + 120, yPos, 250, 28)];
  [_fontDropdown removeAllItems];
  [_fontDropdown addItemsWithTitles:fontNames];

  if (currentFontName) {
    NSInteger index = [_fontDropdown indexOfItemWithTitle:currentFontName];
    if (index != -1) {
        [_fontDropdown selectItemAtIndex:index];
    }
  }
  _fontDropdown.target = self;
  _fontDropdown.action = @selector(fontDropdownChanged:);
  [contentView addSubview:_fontDropdown];
  yPos += 40;

  _fontSizeLabel = [[NSTextField alloc]
  initWithFrame:NSMakeRect(padding, yPos, labelWidth, 20)];
  _fontSizeLabel.stringValue =
  [NSString stringWithFormat:@"Size: %.0fpt", currentFontSize];
  _fontSizeLabel.font = [NSFont systemFontOfSize:13];
  _fontSizeLabel.bezeled = NO;
  _fontSizeLabel.drawsBackground = NO;
  _fontSizeLabel.editable = NO;
  _fontSizeLabel.selectable = NO;
  [contentView addSubview:_fontSizeLabel];
  yPos += 28;

  NSSlider *fontSizeSlider =
  [[NSSlider alloc] initWithFrame:NSMakeRect(padding, yPos, width, 25)];
  fontSizeSlider.minValue = 9.0;
  fontSizeSlider.maxValue = 24.0;
  fontSizeSlider.floatValue = currentFontSize;
  fontSizeSlider.continuous = YES;
  fontSizeSlider.target = sliderTarget;
  fontSizeSlider.action = @selector(fontSizeSliderChanged:);
  [contentView addSubview:fontSizeSlider];
  yPos += 35;

  _fontColorWell =
  [[NSColorWell alloc] initWithFrame:NSMakeRect(padding, yPos, 60, 28)];
  _fontColorWell.color =
  (useCustomFontColor && fontColor) ? fontColor : TEXT_PRIMARY;
  _fontColorWell.target = self;
  _fontColorWell.action = @selector(fontColorChanged:);
  [contentView addSubview:_fontColorWell];

  _resetFontColorButton =
  [[NSButton alloc] initWithFrame:NSMakeRect(padding + 80, yPos, 130, 28)];
  _resetFontColorButton.title = @"Reset Text Color";
  _resetFontColorButton.buttonType = NSButtonTypeMomentaryPushIn;
  _resetFontColorButton.bezelStyle = NSBezelStyleRounded;
  _resetFontColorButton.target = self;
  _resetFontColorButton.action = @selector(resetFontColorClicked:);
  [contentView addSubview:_resetFontColorButton];
  yPos += 35;

  NSBox *fontSep =
  [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos, width, 1.5)];
  fontSep.boxType = NSBoxSeparator;
  [contentView addSubview:fontSep];
  yPos += 20;

  NSTextField *fontHeader =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 300, 24)];
  fontHeader.stringValue = @"Font Settings";
  fontHeader.font = [NSFont boldSystemFontOfSize:16];
  fontHeader.bezeled = NO;
  fontHeader.drawsBackground = NO;
  fontHeader.editable = NO;
  fontHeader.selectable = NO;
  [contentView addSubview:fontHeader];
  yPos += 35;

  NSBox *colorSep =
  [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos, width, 1.5)];
  colorSep.boxType = NSBoxSeparator;
  [contentView addSubview:colorSep];
  yPos += 20;

  _colorWell =
  [[NSColorWell alloc] initWithFrame:NSMakeRect(padding, yPos, 60, 28)];
  _colorWell.color = primaryColor ?: DARK_BG;
  _colorWell.target = self;
  _colorWell.action = @selector(primaryColorChanged:);
  [contentView addSubview:_colorWell];

  _resetColorButton =
  [[NSButton alloc] initWithFrame:NSMakeRect(padding + 70, yPos, 120, 28)];
  _resetColorButton.title = @"Reset Window";
  _resetColorButton.buttonType = NSButtonTypeMomentaryPushIn;
  _resetColorButton.bezelStyle = NSBezelStyleRounded;
  _resetColorButton.target = self;
  _resetColorButton.action = @selector(resetPrimaryColorClicked:);
  [contentView addSubview:_resetColorButton];

  _playlistColorWell = [[NSColorWell alloc]
  initWithFrame:NSMakeRect(padding + 220, yPos, 60, 28)];
  _playlistColorWell.color =
  playlistColor ?: [primaryColor ?: DARK_BG colorWithAlphaComponent:0.85];
  _playlistColorWell.target = self;
  _playlistColorWell.action = @selector(playlistColorChanged:);
  [contentView addSubview:_playlistColorWell];

  _resetPlaylistColorButton =
  [[NSButton alloc] initWithFrame:NSMakeRect(padding + 290, yPos, 130, 28)];
  _resetPlaylistColorButton.title = @"Reset Sidebar";
  _resetPlaylistColorButton.buttonType = NSButtonTypeMomentaryPushIn;
  _resetPlaylistColorButton.bezelStyle = NSBezelStyleRounded;
  _resetPlaylistColorButton.target = self;
  _resetPlaylistColorButton.action = @selector(resetPlaylistColorClicked:);
  [contentView addSubview:_resetPlaylistColorButton];
  yPos += 35;

  NSTextField *colorHeader =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 400, 24)];
  colorHeader.stringValue = @"Primary & Sidebar Colors";
  colorHeader.font = [NSFont boldSystemFontOfSize:16];
  colorHeader.bezeled = NO;
  colorHeader.drawsBackground = NO;
  colorHeader.editable = NO;
  colorHeader.selectable = NO;
  [contentView addSubview:colorHeader];
  yPos += 35;

  NSBox *blurSep =
      [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos, width, 1.5)];
  blurSep.boxType = NSBoxSeparator;
  [contentView addSubview:blurSep];
  yPos += 20;

  NSSlider *blurSlider =
  [[NSSlider alloc] initWithFrame:NSMakeRect(padding, yPos, width, 25)];
  blurSlider.minValue = 5.0;
  blurSlider.maxValue = 50.0;
  blurSlider.floatValue = currentBlurRadius;
  blurSlider.continuous = YES;
  blurSlider.target = sliderTarget;
  blurSlider.action = @selector(blurSliderChanged:);
  [contentView addSubview:blurSlider];
  yPos += 28;

  _blurLabel = [[NSTextField alloc]
  initWithFrame:NSMakeRect(padding, yPos, labelWidth, 20)];
  _blurLabel.stringValue =
  [NSString stringWithFormat:@"Value: %.0fpx", currentBlurRadius];
  _blurLabel.font = [NSFont systemFontOfSize:13];
  _blurLabel.bezeled = NO;
  _blurLabel.drawsBackground = NO;
  _blurLabel.editable = NO;
  _blurLabel.selectable = NO;
  [contentView addSubview:_blurLabel];
  yPos += 28;

  NSTextField *blurHeader =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 300, 24)];
  blurHeader.stringValue = @"Blur Radius";
  blurHeader.font = [NSFont boldSystemFontOfSize:16];
  blurHeader.bezeled = NO;
  blurHeader.drawsBackground = NO;
  blurHeader.editable = NO;
  blurHeader.selectable = NO;
  [contentView addSubview:blurHeader];
  yPos += 35;

  NSBox *opacitySep =
  [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos, width, 1.5)];
  opacitySep.boxType = NSBoxSeparator;
  [contentView addSubview:opacitySep];
  yPos += 20;

  NSSlider *opacitySlider =
  [[NSSlider alloc] initWithFrame:NSMakeRect(padding, yPos, width, 25)];
  opacitySlider.minValue = 0.1;
  opacitySlider.maxValue = 1.0;
  opacitySlider.floatValue = currentOpacity;
  opacitySlider.continuous = YES;
  opacitySlider.target = sliderTarget;
  opacitySlider.action = @selector(opacitySliderChanged:);
  [contentView addSubview:opacitySlider];
  yPos += 28;

  _opacityLabel = [[NSTextField alloc]
  initWithFrame:NSMakeRect(padding, yPos, labelWidth, 20)];
  _opacityLabel.stringValue =
  [NSString stringWithFormat:@"Value: %.2f", currentOpacity];
  _opacityLabel.font = [NSFont systemFontOfSize:13];
  _opacityLabel.bezeled = NO;
  _opacityLabel.drawsBackground = NO;
  _opacityLabel.editable = NO;
  _opacityLabel.selectable = NO;
  [contentView addSubview:_opacityLabel];
  yPos += 28;

  NSTextField *opacityHeader =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 300, 24)];
  opacityHeader.stringValue = @"Opacity";
  opacityHeader.font = [NSFont boldSystemFontOfSize:16];
  opacityHeader.bezeled = NO;
  opacityHeader.drawsBackground = NO;
  opacityHeader.editable = NO;
  opacityHeader.selectable = NO;
  [contentView addSubview:opacityHeader];
  yPos += 35;

  NSBox *styleSep =
  [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos, width, 1.5)];
  styleSep.boxType = NSBoxSeparator;
  [contentView addSubview:styleSep];
  yPos += 20;

  NSArray *styleTitles = @[ @"Opaque", @"Translucent", @"Blurred", @"Glass" ];
  for (int i = 0; i < 4; i++) {
    NSButton *button = [[NSButton alloc]
    initWithFrame:NSMakeRect(padding + (i * 120), yPos, 115, 25)];
    button.title = styleTitles[i];
    button.buttonType = NSButtonTypeRadio;
    button.tag = i;
    button.target = self;
    button.action = @selector(styleButtonClicked:);
    [contentView addSubview:button];

    if (i == 0)
      _opaqueButton = button;
    else if (i == 1)
      _translucentButton = button;
    else if (i == 2)
      _blurredButton = button;
    else if (i == 3)
      _glassButton = button;
  }
  yPos += 30;

  NSTextField *styleHeader =
  [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 300, 24)];
  styleHeader.stringValue = @"Window Style";
  styleHeader.font = [NSFont boldSystemFontOfSize:16];
  styleHeader.bezeled = NO;
  styleHeader.drawsBackground = NO;
  styleHeader.editable = NO;
  styleHeader.selectable = NO;
  [contentView addSubview:styleHeader];
  yPos += 30;

  yPos += 20;

  NSTextField *libHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos, 300, 24)];
  libHeader.stringValue = @"libfootheme";
  libHeader.font = [NSFont boldSystemFontOfSize:18];
  libHeader.bezeled = NO;
  libHeader.drawsBackground = NO;
  libHeader.editable = NO;
  libHeader.selectable = NO;
  [contentView addSubview:libHeader];
  yPos += 30;

  NSBox *libSep = [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos, width, 1.5)];
  libSep.boxType = NSBoxSeparator;
  [contentView addSubview:libSep];
  yPos += 20;

  _importConfigButton = [[NSButton alloc] initWithFrame:NSMakeRect(padding, yPos, 150, 30)];
  _importConfigButton.title = @"Import Config...";
  _importConfigButton.buttonType = NSButtonTypeMomentaryPushIn;
  _importConfigButton.bezelStyle = NSBezelStyleRounded;
  _importConfigButton.target = importTarget;
  _importConfigButton.action = @selector(importConfig:);
  [contentView addSubview:_importConfigButton];

  _exportConfigButton = [[NSButton alloc] initWithFrame:NSMakeRect(padding + 170, yPos, 150, 30)];
  _exportConfigButton.title = @"Export Config...";
  _exportConfigButton.buttonType = NSButtonTypeMomentaryPushIn;
  _exportConfigButton.bezelStyle = NSBezelStyleRounded;
  _exportConfigButton.target = exportTarget;
  _exportConfigButton.action = @selector(exportConfig:);
  [contentView addSubview:_exportConfigButton];
  yPos += 45;

  yPos += 20;

  contentView.frame = NSMakeRect(0, 0, 600, yPos);
  scrollView.documentView = contentView;
  _window.contentView = scrollView;

  [self updateUI];
}

- (void)updateUI {
  if (_colorWell)
    _colorWell.color = primaryColor ?: DARK_BG;
  if (_playlistColorWell)
    _playlistColorWell.color =
    playlistColor ?: [primaryColor ?: DARK_BG colorWithAlphaComponent:0.85];
  if (_fontColorWell)
    _fontColorWell.color =
    (useCustomFontColor && fontColor) ? fontColor : TEXT_PRIMARY;

  if (_opacityLabel)
    _opacityLabel.stringValue =
    [NSString stringWithFormat:@"Value: %.2f", currentOpacity];
  if (_blurLabel)
    _blurLabel.stringValue =
    [NSString stringWithFormat:@"Value: %.0fpx", currentBlurRadius];
  if (_fontSizeLabel)
    _fontSizeLabel.stringValue =
    [NSString stringWithFormat:@"Size: %.0fpt", currentFontSize];

  if (_sectionTransparencyLabel)
    _sectionTransparencyLabel.stringValue =
    [NSString stringWithFormat:@"Sidebar Opacity: %.2f", sectionTransparency];

  if (_bgImageOpacityLabel)
    _bgImageOpacityLabel.stringValue =
    [NSString stringWithFormat:@"Image Opacity: %.2f", backgroundImageOpacity];

  if (_fontFileLabel) {
    _fontFileLabel.stringValue =
    customFontPath
        ? [NSString stringWithFormat:@"📁 %@", [customFontPath lastPathComponent]]
        : @"No custom font loaded";
    _fontFileLabel.textColor = customFontPath ? [NSColor controlTextColor]
                                              : [NSColor secondaryLabelColor];
  }

  if (_bgImageFileLabel) {
    _bgImageFileLabel.stringValue =
        backgroundImagePath
            ? [NSString
                  stringWithFormat:@"🖼️ %@",
                                   [backgroundImagePath lastPathComponent]]
            : @"No background image set";
    _bgImageFileLabel.textColor = backgroundImagePath
                                      ? [NSColor controlTextColor]
                                      : [NSColor secondaryLabelColor];
  }

  if (_fontDropdown && currentFontName) {
    NSInteger index = [_fontDropdown indexOfItemWithTitle:currentFontName];
    if (index != -1) {
      [_fontDropdown selectItemAtIndex:index];
    }
  }

  if (_opaqueButton)
    _opaqueButton.state = (currentStyle == ThemeStyleOpaque)
        ? NSControlStateValueOn
        : NSControlStateValueOff;
  if (_translucentButton)
    _translucentButton.state = (currentStyle == ThemeStyleTranslucent)
        ? NSControlStateValueOn
        : NSControlStateValueOff;
  if (_blurredButton)
    _blurredButton.state = (currentStyle == ThemeStyleBlurred)
        ? NSControlStateValueOn
        : NSControlStateValueOff;
  if (_glassButton)
    _glassButton.state = (currentStyle == ThemeStyleGlass)
        ? NSControlStateValueOn
        : NSControlStateValueOff;
}

- (void)updateFontLabel {
  if (_fontFileLabel) {
    _fontFileLabel.stringValue =
        customFontPath ? [NSString stringWithFormat:@"📁 %@", [customFontPath lastPathComponent]]
        : @"No custom font loaded";

    _fontFileLabel.textColor = customFontPath ? [NSColor controlTextColor]
    : [NSColor secondaryLabelColor];
  }
}



- (void)styleButtonClicked:(id)sender {
  NSButton *button = (NSButton *)sender;
  currentStyle = (ThemeStyle)button.tag;
  apply_theme();
  save_config();
  [self updateUI];
}

- (void)primaryColorChanged:(id)sender {
  if (_colorWell) {
    primaryColor = _colorWell.color;
    useCustomPrimary = YES;
    update_derv_colors();
    apply_theme();
    save_config();
    [self updateUI];
  }
}

- (void)resetPrimaryColorClicked:(id)sender {
  useCustomPrimary = NO;
  primaryColor = DARK_BG;
  update_derv_colors();
  apply_theme();
  save_config();
  [self updateUI];
}

- (void)playlistColorChanged:(id)sender {
  if (_playlistColorWell) {
    playlistColor = _playlistColorWell.color;
    useCustomPlaylist = YES;
    update_derv_colors();
    apply_theme();
    save_config();
    [self updateUI];
  }
}

- (void)resetPlaylistColorClicked:(id)sender {
  useCustomPlaylist = NO;
  playlistColor = nil;
  update_derv_colors();
  apply_theme();
  save_config();
  [self updateUI];
}

- (void)fontColorChanged:(id)sender {
  if (_fontColorWell) {
    fontColor = _fontColorWell.color;
    useCustomFontColor = YES;
    apply_theme();
    save_config();
    [self updateUI];
  }
}

- (void)resetFontColorClicked:(id)sender {
  useCustomFontColor = NO;
  fontColor = nil;
  apply_theme();
  save_config();
  [self updateUI];
}

- (void)fontDropdownChanged:(id)sender {
  if (_fontDropdown) {
    NSString *selected = _fontDropdown.selectedItem.title;
    if (selected && selected.length > 0) {
        if (customFontPath) {
            customFontPath = nil;
            [[NSNotificationCenter defaultCenter]
            postNotificationName:@"FontFileChanged" object:nil];
      }
      currentFontName = selected;
      apply_theme();
      save_config();
      [self updateUI];
    }
  }
}

- (void)closeButtonClicked:(id)sender {
    [self closeWindow];
}



- (void)windowWillClose:(NSNotification *)notification {
    _window = nil;
}

- (BOOL)windowShouldClose:(id)sender {
    return YES;
}

@end

void OpenThemeSettings(id sender) {
    [[SettingsWindowController sharedInstance] showWindow];
}

void BuildThemeMenu(void) {
  @try {
    NSMenu *mainMenu = [NSApp mainMenu];
    if (!mainMenu) return;

    NSMenu *themeMenu = nil;
    for (NSMenuItem *item in mainMenu.itemArray) {
        if ([item.title isEqualToString:@"Theme"]) {
            themeMenu = item.submenu;
        break;
      }
    }

    if (!themeMenu) {
        themeMenu = [[NSMenu alloc] initWithTitle:@"Theme"];
    }

    static NSObject *menuTarget = nil;
    if (!menuTarget) {
        menuTarget = [[NSObject alloc] init];
        class_addMethod([menuTarget class], @selector(openThemeSettings:),
        (IMP)OpenThemeSettings, "v@:@");
        
        class_addMethod([menuTarget class], @selector(openUIElements:),
        (IMP)OpenUIElementsWindow, "v@:@");
    }

    for (NSMenuItem *item in themeMenu.itemArray) {
        if ([item.title isEqualToString:@"Theme Settings"] ||
          [item.title isEqualToString:@"UI Elements"]) {
            [themeMenu removeItem:item];
        }
    }

    NSMenuItem *settingsItem =
    [[NSMenuItem alloc] initWithTitle:@"Theme Settings"
    action:@selector(openThemeSettings:)
    keyEquivalent:@","];
    
    settingsItem.target = menuTarget;
    [themeMenu addItem:settingsItem];

    NSMenuItem *uiItem =
    [[NSMenuItem alloc] initWithTitle:@"UI Elements"
    action:@selector(openUIElements:)
    keyEquivalent:@""];

    uiItem.target = menuTarget;
    [themeMenu addItem:uiItem];

    BOOL found = NO;
    for (NSMenuItem *item in mainMenu.itemArray) {
        if ([item.title isEqualToString:@"Theme"]) {
            found = YES;
            break;
        }
    }

    if (!found) {
      NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"Theme"
      action:nil
      keyEquivalent:@""];

      menuItem.submenu = themeMenu;
      [mainMenu addItem:menuItem];
    }

    foo_log(@"built Theme menu");
  } @catch (NSException *e) {
    foo_log(@"menu error: %@", e);
  }
}



void SetupHooks(void) {
    NSArray *targets = @[
        @"FB2KPlaylistView", @"FB2KTableViewEx", @"fooAlbumListView",
        @"fooAlbumArtView", @"fooConsoleView", @"fooMessageView",
        @"fooVisCommonView", @"FB2KPreferencesAdvancedView",
        @"FB2KPreferencesOutputView", @"FB2KPreferencesUPnPView",
        @"FB2KDSPManagerView", @"FB2KReplayGainConfigView",
        @"FB2KPlaybackControlsBar"
    ];

    for (NSString *name in targets) {
        Class cls = NSClassFromString(name);
        if (cls) { HookDrawRect(cls); }
    }
}

void StartPeriodicTheming(void) {
    [NSTimer
        scheduledTimerWithTimeInterval:1.0
        repeats:YES
        block:^(NSTimer *t) {
            for (NSWindow *w in
            [NSApplication sharedApplication]
            .windows) {
                NSString *cls = NSStringFromClass([w class]);
                if (![cls hasPrefix:@"NS"] && ![cls hasPrefix:@"_NS"]) {
                    if (w.contentView) {
                    ApplyFontToView(w.contentView);
                    if (currentStyle == ThemeStyleBlurred) {
                        RecreateBlurView(w);
                    }
                    [w.contentView setNeedsDisplay:YES];
                    }
                }
            }
            apply_playlist_colors();
            if (useBackgroundImage) {
            applyBackgroundImagesToAllViews();
            }
    }];
}



__attribute__((constructor)) static void initialize(void) {
    foo_log(@"loaded!");

    InitUIElements();

    if (!primaryColor) {
        primaryColor = DARK_BG;
    }

    LoadSettings();

    if (!primaryColor)
        primaryColor = DARK_BG;
    if (!currentFontName)
        currentFontName = @"Helvetica Neue";

    if (customFontPath) {
        load_custom_font();
    }

    update_derv_colors();

    @try {
        [NSApp
        setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
    } @catch (id e) {
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
        dispatch_get_main_queue(), ^{
        SetupHooks();
        BuildThemeMenu();
        StartPeriodicTheming();
        apply_theme();
        foo_log(@"theme injected, no errors");
        });
}