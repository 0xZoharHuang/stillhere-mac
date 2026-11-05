#import <AppKit/AppKit.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface ProbePanel : NSPanel
@end
@implementation ProbePanel
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

static void writeJSON(NSDictionary *value, NSString *path) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:NULL];
    if (path) [data writeToFile:path atomically:YES];
    puts([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
    fflush(stdout);
}

static NSDictionary *saveImage(CGImageRef image, NSString *path) {
    if (!image) return @{@"status": @"no_image"};
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
    NSInteger green = 0, magenta = 0, black = 0, total = 0;
    for (NSInteger y = 5; y < rep.pixelsHigh - 5; y += 4) {
        for (NSInteger x = 5; x < rep.pixelsWide - 5; x += 4) {
            NSColor *c = [[rep colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            if (!c) continue;
            CGFloat r = c.redComponent, g = c.greenComponent, b = c.blueComponent;
            total++;
            if (g > .65 && g > r + .35 && g > b + .35) green++;
            if (r > .65 && b > .65 && g < .35) magenta++;
            if (r < .15 && g < .15 && b < .15) black++;
        }
    }
    NSString *kind = green > total * .7 ? @"underlying_desktop" :
        magenta > total * .7 ? @"privacy_overlay_visible" :
        black > total * .7 ? @"black_rectangle" : @"unexpected_pixels";
    return @{@"status": @"captured", @"classification": kind,
             @"greenFraction": @(total ? (double)green / total : 0),
             @"magentaFraction": @(total ? (double)magenta / total : 0),
             @"blackFraction": @(total ? (double)black / total : 0),
             @"width": @(rep.pixelsWide), @"height": @(rep.pixelsHigh), @"file": path.lastPathComponent};
}

static NSDictionary *legacyCapture(CGRect rect, NSString *path) {
    CGImageRef image = CGWindowListCreateImage(rect, kCGWindowListOptionOnScreenOnly,
                                               kCGNullWindowID, kCGWindowImageBoundsIgnoreFraming);
    NSDictionary *result = saveImage(image, path);
    if (image) CGImageRelease(image);
    return result;
}

static NSDictionary *sckCapture(SCShareableContent *content, SCDisplay *display,
                                CGRect sourceRect, CGWindowID exclude, NSString *path) API_AVAILABLE(macos(14.0)) {
    NSArray *excluded = exclude == 0 ? @[] : [content.windows filteredArrayUsingPredicate:
        [NSPredicate predicateWithBlock:^BOOL(SCWindow *window, NSDictionary *bindings) {
            return window.windowID == exclude;
        }]];
    SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:excluded];
    SCStreamConfiguration *config = [SCStreamConfiguration new];
    config.sourceRect = sourceRect;
    config.width = (size_t)sourceRect.size.width;
    config.height = (size_t)sourceRect.size.height;
    config.showsCursor = NO;
    config.ignoreShadowsDisplay = YES;
    __block NSDictionary *result;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [SCScreenshotManager captureImageWithFilter:filter configuration:config
                            completionHandler:^(CGImageRef image, NSError *error) {
        result = error ? @{@"status": @"error", @"error": error.localizedDescription} : saveImage(image, path);
        dispatch_semaphore_signal(sem);
    }];
    if (dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)))
        return @{@"status": @"timeout"};
    return result ?: @{@"status": @"no_result"};
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *out = argc > 1 ? @(argv[1]) : @"research/probe-results";
        [[NSFileManager defaultManager] createDirectoryAtPath:out withIntermediateDirectories:YES attributes:nil error:NULL];
        if (!CGPreflightScreenCaptureAccess()) {
            writeJSON(@{@"status": @"screen_capture_permission_unavailable", @"requestedPermissions": @NO},
                      [out stringByAppendingPathComponent:@"results.json"]);
            return 77;
        }
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        __block BOOL probeActivated = NO;
        id focusObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification
            object:app queue:nil usingBlock:^(NSNotification *note) { probeActivated = YES; }];
        NSUInteger screenIndex = argc > 2 ? (NSUInteger)strtoul(argv[2], NULL, 10) : NSNotFound;
        NSScreen *screen = screenIndex == NSNotFound ? NSScreen.mainScreen :
            (screenIndex < NSScreen.screens.count ? NSScreen.screens[screenIndex] : nil);
        if (!screen) { writeJSON(@{@"status": @"no_active_display"}, nil); return 78; }
        NSRect frame = NSMakeRect(screen.visibleFrame.origin.x + 30, NSMaxY(screen.visibleFrame) - 210, 300, 160);
        CGRect globalRect = CGRectMake(frame.origin.x, NSMaxY(NSScreen.screens.firstObject.frame) - NSMaxY(frame), frame.size.width, frame.size.height);
        CGDirectDisplayID displayID = [screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];
        CGRect displayBounds = CGDisplayBounds(displayID);
        CGRect sourceRect = CGRectOffset(globalRect, -displayBounds.origin.x, -displayBounds.origin.y);
        pid_t frontBefore = NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
        ProbePanel *(^panel)(NSColor *, NSInteger) = ^ProbePanel *(NSColor *color, NSInteger level) {
            ProbePanel *p = [[ProbePanel alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
            p.backgroundColor = color;
            p.opaque = YES;
            p.hasShadow = NO;
            p.ignoresMouseEvents = YES;
            p.hidesOnDeactivate = NO;
            p.level = level;
            p.sharingType = NSWindowSharingReadOnly;
            p.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
            [p orderFrontRegardless];
            return p;
        };
        ProbePanel *target = panel([NSColor colorWithDeviceRed:0 green:1 blue:0 alpha:1], NSScreenSaverWindowLevel);
        ProbePanel *mask = panel([NSColor colorWithDeviceRed:1 green:0 blue:1 alpha:1], NSScreenSaverWindowLevel + 1);
        target.title = @"StillHere probe: real desktop";
        mask.title = @"StillHere probe: privacy image";
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 24 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [mask orderOut:nil]; [target orderOut:nil];
            writeJSON(@{@"status": @"watchdog_timeout"}, [out stringByAppendingPathComponent:@"watchdog.json"]);
            exit(79);
        });
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [NSThread sleepForTimeInterval:.3];
            NSMutableDictionary *results = [@{@"os": NSProcessInfo.processInfo.operatingSystemVersionString,
                @"requestedPermissions": @NO, @"injectedInput": @NO} mutableCopy];
            results[@"normal_legacy"] = legacyCapture(globalRect, [out stringByAppendingPathComponent:@"normal-legacy.png"]);
            __block SCShareableContent *content;
            dispatch_semaphore_t contentSem = dispatch_semaphore_create(0);
            [SCShareableContent getShareableContentExcludingDesktopWindows:NO onScreenWindowsOnly:YES completionHandler:^(SCShareableContent *c, NSError *error) {
                content = c;
                dispatch_semaphore_signal(contentSem);
            }];
            dispatch_semaphore_wait(contentSem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
            SCDisplay *display;
            for (SCDisplay *d in content.displays) if (d.displayID == displayID) display = d;
            if (display) {
                results[@"normal_sck"] = sckCapture(content, display, sourceRect, 0, [out stringByAppendingPathComponent:@"normal-sck.png"]);
                results[@"explicit_exclusion_sck"] = sckCapture(content, display, sourceRect, (CGWindowID)mask.windowNumber, [out stringByAppendingPathComponent:@"explicit-exclusion-sck.png"]);
            }
            dispatch_sync(dispatch_get_main_queue(), ^{ mask.sharingType = NSWindowSharingNone; [mask displayIfNeeded]; });
            [NSThread sleepForTimeInterval:.3];
            results[@"protected_legacy"] = legacyCapture(globalRect, [out stringByAppendingPathComponent:@"protected-legacy.png"]);
            if (display) results[@"protected_sck"] = sckCapture(content, display, sourceRect, 0, [out stringByAppendingPathComponent:@"protected-sck.png"]);
            dispatch_sync(dispatch_get_main_queue(), ^{
                results[@"frontmostAppUnchanged"] = @(frontBefore == NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier);
                results[@"probeTookKeyboardFocus"] = @(probeActivated || mask.isKeyWindow || target.isKeyWindow);
                [NSNotificationCenter.defaultCenter removeObserver:focusObserver];
                [mask orderOut:nil]; [target orderOut:nil];
                results[@"status"] = @"completed";
                writeJSON(results, [out stringByAppendingPathComponent:@"results.json"]);
                CFRunLoopStop(CFRunLoopGetMain());
            });
        });
        // A capture-only helper needs the main run loop, not NSApplication.run.
        // run() performs launch activation when this executable lives in an app
        // bundle, which would steal focus from the automation being checked.
        CFRunLoopRun();
    }
    return 0;
}
