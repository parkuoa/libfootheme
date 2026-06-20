/*
    libfootheme.h
    naomisphere <parou.sia@tuta.io>
    License: GNU General Public License v3.0 or later
*/

#ifndef libfootheme_h
#define libfootheme_h

#pragma clang diagnostic ignored "-Wunused-variable"

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

/* settings window controller */
@interface SettingsWindowController : NSObject <NSWindowDelegate>
+ (instancetype)sharedInstance; // return shared instance
- (void)showWindow;             // open or create settings window accordingly
- (void)closeWindow;            // close and let go of the settings window
- (void)updateUI;               // update UI to reflect current theme settings (state)
- (void)updateFontLabel;        // (stupid warning) update the font status indicator label
- (void)scrollToTop;            // (dirty) scroll to top of the settings window (I couldn't get it work cleanly)
@end

/* functions */
void InitUIElements(void);              // initialize the "UI Elements" plugin
void OpenUIElementsWindow(id sender);   // open the "UI Elements" settings window
void OpenThemeSettings(id sender);      // open the "Theme Settings" window

#endif