/*
    uielem.m
    naomisphere <parou.sia@tuta.io>
    License: GNU General Public License v3.0 or later
*/

/*
    --------------------------------------------------
    version date: June 20, 2026
    --------------------------------------------------
*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "include/ui_assets.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
 
static NSWindow *uiWindow = nil;
static NSMutableArray *iconViews = nil;
 
NSString* UIResourcesPath(void) {
    return @"/Applications/foobar2000.app/Contents/Resources";
}

NSString* UIBackupPath(void) {
    static NSString *path = nil;
    if (!path) {
        NSString *home = NSHomeDirectory();
        NSString *folder = [home stringByAppendingPathComponent:@".config/foo/backup"];
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        path = folder;
    }
    return path;
}
 
void BackupOriginalIcons(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *resources = UIResourcesPath();
    NSString *backup = UIBackupPath();
    
    for (int i = 0; i < iconCount; i++) {
        NSString *icon = iconFiles[i].filename;
        NSString *src = [resources stringByAppendingPathComponent:icon];
        NSString *dst = [backup stringByAppendingPathComponent:icon];
        if ([fm fileExistsAtPath:src] && ![fm fileExistsAtPath:dst]) {
            [fm copyItemAtPath:src toPath:dst error:nil];
        }
    }
}
 
 
 
void RestoreOriginalIcons(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *resources = UIResourcesPath();
    NSString *backup = UIBackupPath();
    
    for (int i = 0; i < iconCount; i++) {
        NSString *icon = iconFiles[i].filename;
        NSString *src = [backup stringByAppendingPathComponent:icon];
        NSString *dst = [resources stringByAppendingPathComponent:icon];
        if ([fm fileExistsAtPath:src]) {
            [fm removeItemAtPath:dst error:nil];
            [fm copyItemAtPath:src toPath:dst error:nil];
        }
    }
}
 
 
 
@interface UIElementWindowController : NSObject <NSWindowDelegate, NSOpenSavePanelDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSMutableArray *iconViews;
@property (nonatomic, strong) NSButton *restoreAllButton;
- (void)refreshAllIcons;
- (void)redrawSubviews:(NSView *)view;
- (void)findAndRefreshImages:(NSView *)view;
- (void)findAndRefreshButtons:(NSView *)view withClass:(Class)buttonClass;
@end

@implementation UIElementWindowController {
    NSMutableArray *_iconViews;
}

+ (instancetype)sharedInstance {
    static UIElementWindowController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UIElementWindowController alloc] init];
        instance.iconViews = [NSMutableArray array];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _iconViews = [NSMutableArray array];
        [self createWindow];
    }
    return self;
}

- (void)createWindow {
    NSRect windowRect = NSMakeRect(0, 0, 500, 470);
    _window = [[NSWindow alloc] initWithContentRect:windowRect
                                          styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _window.title = @"UI Elements";
    _window.level = NSFloatingWindowLevel;
    _window.delegate = self;
    _window.releasedWhenClosed = NO;
    
    NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 450)];
    
    CGFloat yPos = 410;
    CGFloat padding = 15;
 
    NSTextField *headerLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos - 20, 300, 20)];
    headerLabel.stringValue = @"Customize UI Icons";
    headerLabel.font = [NSFont boldSystemFontOfSize:16];
    headerLabel.bezeled = NO;
    headerLabel.drawsBackground = NO;
    headerLabel.editable = NO;
    headerLabel.selectable = NO;
    [contentView addSubview:headerLabel];
    yPos -= 35;
 
    NSTextField *subLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos - 15, 400, 16)];
    subLabel.stringValue = @"Replace icons with your own images (PNG format, 256x256 recommended)";
    subLabel.font = [NSFont systemFontOfSize:11];
    subLabel.textColor = [NSColor secondaryLabelColor];
    subLabel.bezeled = NO;
    subLabel.drawsBackground = NO;
    subLabel.editable = NO;
    subLabel.selectable = NO;
    [contentView addSubview:subLabel];
    yPos -= 25;
 
    NSTextField *restartNote = [[NSTextField alloc] initWithFrame:NSMakeRect(padding, yPos - 15, 470, 16)];
    restartNote.stringValue = @"⚠️ Changes take effect after restarting foobar2000 for the main UI.";
    restartNote.font = [NSFont systemFontOfSize:11];
    restartNote.textColor = [NSColor systemOrangeColor];
    restartNote.bezeled = NO;
    restartNote.drawsBackground = NO;
    restartNote.editable = NO;
    restartNote.selectable = NO;
    [contentView addSubview:restartNote];
    yPos -= 25;
 
    NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(padding, yPos - 5, 470, 1)];
    separator.boxType = NSBoxSeparator;
    [contentView addSubview:separator];
    yPos -= 20;
 
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 40, 500, yPos - 10)];
    scrollView.hasVerticalScroller = YES;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.borderType = NSNoBorder;
    scrollView.drawsBackground = NO;
    
    NSView *scrollContentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 480, iconCount * 60 + 20)];
    scrollContentView.wantsLayer = YES;
    scrollContentView.layer.backgroundColor = [NSColor clearColor].CGColor;
    
    [_iconViews removeAllObjects];
    
    for (int i = 0; i < iconCount; i++) {
        CGFloat rowY = (iconCount - 1 - i) * 60 + 10;
 
        NSBox *rowBg = [[NSBox alloc] initWithFrame:NSMakeRect(5, rowY, 470, 50)];
        rowBg.boxType = NSBoxCustom;
        rowBg.transparent = YES;
        rowBg.fillColor = [NSColor clearColor];
        rowBg.borderWidth = 0;
        [scrollContentView addSubview:rowBg];
 
        NSImageView *iconPreview = [[NSImageView alloc] initWithFrame:NSMakeRect(20, rowY + 5, 40, 40)];
        iconPreview.imageScaling = NSImageScaleProportionallyUpOrDown;
        iconPreview.imageAlignment = NSImageAlignCenter;
 
        NSString *iconPath = [UIResourcesPath() stringByAppendingPathComponent:iconFiles[i].filename];
        NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile:iconPath];
        if (iconImage) {
            iconPreview.image = iconImage;
        } else {
 
            iconPreview.image = [NSImage imageNamed:NSImageNameCaution];
        }
        [scrollContentView addSubview:iconPreview];
        [_iconViews addObject:iconPreview];
 
        NSTextField *nameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(75, rowY + 15, 180, 20)];
        nameLabel.stringValue = [NSString stringWithFormat:@"%@ (%@)", iconFiles[i].displayName, iconFiles[i].filename];
        nameLabel.font = [NSFont systemFontOfSize:12];
        nameLabel.bezeled = NO;
        nameLabel.drawsBackground = NO;
        nameLabel.editable = NO;
        nameLabel.selectable = NO;
        [scrollContentView addSubview:nameLabel];
 
        NSButton *changeButton = [[NSButton alloc] initWithFrame:NSMakeRect(380, rowY + 12, 80, 25)];
        changeButton.title = @"Change...";
        changeButton.buttonType = NSButtonTypeMomentaryPushIn;
        changeButton.bezelStyle = NSBezelStyleRounded;
        changeButton.tag = i;
        changeButton.target = self;
        changeButton.action = @selector(changeButtonClicked:);
        [scrollContentView addSubview:changeButton];
 
        NSButton *restoreButton = [[NSButton alloc] initWithFrame:NSMakeRect(340, rowY + 12, 35, 25)];
        restoreButton.title = @"↺";
        restoreButton.buttonType = NSButtonTypeMomentaryPushIn;
        restoreButton.bezelStyle = NSBezelStyleRounded;
        restoreButton.tag = i;
        restoreButton.target = self;
        restoreButton.action = @selector(restoreButtonClicked:);
        [scrollContentView addSubview:restoreButton];
    }
    
    scrollView.documentView = scrollContentView;
    [contentView addSubview:scrollView];
    yPos = 0;
 
    NSButton *restoreAllButton = [[NSButton alloc] initWithFrame:NSMakeRect(padding, yPos + 10, 150, 30)];
    restoreAllButton.title = @"Restore All Originals";
    restoreAllButton.buttonType = NSButtonTypeMomentaryPushIn;
    restoreAllButton.bezelStyle = NSBezelStyleRounded;
    restoreAllButton.target = self;
    restoreAllButton.action = @selector(restoreAllClicked:);
    [contentView addSubview:restoreAllButton];
    _restoreAllButton = restoreAllButton;
    
    contentView.frame = NSMakeRect(0, 0, 500, 450);
    _window.contentView = contentView;
}

- (void)showWindow {
    if (!_window) {
        [self createWindow];
    }
    [_window center];
    [_window makeKeyAndOrderFront:nil];
}

- (void)closeWindow:(id)sender {
    [_window close];
}
 
 
 
- (void)changeButtonClicked:(id)sender {
    NSButton *button = (NSButton *)sender;
    int index = (int)button.tag;
    if (index < 0 || index >= iconCount) return;
    
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.title = [NSString stringWithFormat:@"Select icon for %@", iconFiles[index].displayName];
    openPanel.allowedFileTypes = @[@"png", @"PNG", @"jpg", @"jpeg", @"JPG", @"JPEG"];
    
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;
    openPanel.prompt = @"Choose Icon";
    
    [openPanel beginSheetModalForWindow:_window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *fileURL = openPanel.URL;
            if (fileURL) {
                [self replaceIconAtIndex:index withURL:fileURL];
            }
        }
    }];
}

- (void)restoreButtonClicked:(id)sender {
    NSButton *button = (NSButton *)sender;
    int index = (int)button.tag;
    if (index < 0 || index >= iconCount) return;
    [self restoreIconAtIndex:index];
}

- (void)restoreAllClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Restore All Icons";
    alert.informativeText = @"This will restore all icons to their original versions. Continue?";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Restore All"];
    [alert addButtonWithTitle:@"Cancel"];
    
    [alert beginSheetModalForWindow:_window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            RestoreOriginalIcons();
            [self refreshAllIcons];
        }
    }];
}
 
 
 
- (void)replaceIconAtIndex:(int)index withURL:(NSURL *)fileURL {
    if (index < 0 || index >= iconCount) return;
    
    NSString *filename = iconFiles[index].filename;
    NSString *resourcesPath = UIResourcesPath();
    NSString *destPath = [resourcesPath stringByAppendingPathComponent:filename];
 
    NSString *backupPath = [UIBackupPath() stringByAppendingPathComponent:filename];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:backupPath]) {
        NSString *srcPath = [resourcesPath stringByAppendingPathComponent:filename];
        if ([fm fileExistsAtPath:srcPath]) {
            [fm copyItemAtPath:srcPath toPath:backupPath error:nil];
        }
    }
 
    NSError *error = nil;
    [fm removeItemAtPath:destPath error:nil];
    [fm copyItemAtURL:fileURL toURL:[NSURL fileURLWithPath:destPath] error:&error];
    
    if (error) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Error replacing icon";
        alert.informativeText = error.localizedDescription;
        [alert runModal];
        return;
    }
 
    [[NSWorkspace sharedWorkspace] noteFileSystemChanged:destPath];
    
    [self refreshAllIcons];
}

- (void)restoreIconAtIndex:(int)index {
    if (index < 0 || index >= iconCount) return;
    
    NSString *filename = iconFiles[index].filename;
    NSString *backupPath = [UIBackupPath() stringByAppendingPathComponent:filename];
    NSString *destPath = [UIResourcesPath() stringByAppendingPathComponent:filename];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:backupPath]) {
        [fm removeItemAtPath:destPath error:nil];
        [fm copyItemAtPath:backupPath toPath:destPath error:nil];
        [[NSWorkspace sharedWorkspace] noteFileSystemChanged:destPath];
        [self refreshAllIcons];
    }
}

- (void)refreshAllIcons {
    for (int i = 0; i < iconCount && i < _iconViews.count; i++) {
        NSImageView *imageView = _iconViews[i];
        if (imageView) {
            NSString *iconPath = [UIResourcesPath() stringByAppendingPathComponent:iconFiles[i].filename];
            NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile:iconPath];
            imageView.image = nil;
            if (iconImage) {
                imageView.image = iconImage;
            }
            [imageView setNeedsDisplay:YES];
        }
    }

    NSView *scrollContentView = [(NSScrollView *)_window.contentView.subviews[0] documentView];
    if (scrollContentView) {
        [scrollContentView setNeedsDisplay:YES];
    }
    
    /* seriously */
    for (NSWindow *window in [NSApplication sharedApplication].windows) {
        [window.contentView setNeedsDisplay:YES];
        [window.contentView displayIfNeeded];
        [self redrawSubviews:window.contentView];
        [window displayIfNeeded];
        [self findAndRefreshImages:window.contentView];
 
        Class buttonClass = NSClassFromString(@"FB2KButtonEx");
        if (buttonClass) {
            [self findAndRefreshButtons:window.contentView withClass:buttonClass];
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:NSViewFrameDidChangeNotification object:nil];

    /* (seriously)^2 */
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (NSWindow *window in [NSApplication sharedApplication].windows) {
            [window.contentView setNeedsDisplay:YES];
            [window.contentView displayIfNeeded];
            [self redrawSubviews:window.contentView];
            [window displayIfNeeded];
        }
    });
}
 
- (void)redrawSubviews:(NSView *)view {
    if (!view) return;
    [view setNeedsDisplay:YES];
    [view displayIfNeeded];
    for (NSView *subview in view.subviews) {
        [self redrawSubviews:subview];
    }
}
 
- (void)findAndRefreshImages:(NSView *)view {
    if (!view) return;
    
    if ([view respondsToSelector:@selector(image)]) {
        id imageView = view;
        if ([imageView respondsToSelector:@selector(setImage:)]) {
            NSImage *currentImage = [imageView performSelector:@selector(image)];
            if (currentImage) {
                [imageView performSelector:@selector(setImage:) withObject:nil];
                [imageView performSelector:@selector(setImage:) withObject:currentImage];
                [view setNeedsDisplay:YES];
            }
        }
    }
    
    for (NSView *subview in view.subviews) {
        [self findAndRefreshImages:subview];
    }
}
 
 
 
- (void)findAndRefreshButtons:(NSView *)view withClass:(Class)buttonClass {
    if (!view) return;
    if ([view isKindOfClass:buttonClass]) {
 
        if ([view respondsToSelector:@selector(setImage:)]) {
            NSImage *img = [view performSelector:@selector(image)];
            if (img) {
                [view performSelector:@selector(setImage:) withObject:nil];
                [view performSelector:@selector(setImage:) withObject:img];
                [view setNeedsDisplay:YES];
            }
        }
 
        for (NSView *subview in view.subviews) {
            if ([subview isKindOfClass:[NSImageView class]]) {
                NSImageView *iv = (NSImageView *)subview;
                NSImage *img = iv.image;
                if (img) {
                    iv.image = nil;
                    iv.image = img;
                    [iv setNeedsDisplay:YES];
                }
            }
        }
    }
    for (NSView *subview in view.subviews) {
        [self findAndRefreshButtons:subview withClass:buttonClass];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    /* no need to do anything here */
}

@end

static UIElementWindowController *uiController = nil;

void InitUIElements(void) {
    BackupOriginalIcons();
}

void OpenUIElementsWindow(id sender) {
    if (!uiController) {
        uiController = [UIElementWindowController sharedInstance];
    }
    [uiController showWindow];
}