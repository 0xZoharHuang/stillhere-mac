#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

// Read-only permission check. This deliberately never requests permissions,
// creates windows, captures the screen, or posts keyboard/mouse input.
int main(void) {
    @autoreleasepool {
        uint32_t displayCount = 0;
        CGError displayResult = CGGetActiveDisplayList(0, NULL, &displayCount);
        NSDictionary *result = @{
            @"os": NSProcessInfo.processInfo.operatingSystemVersionString,
            @"screenCaptureAllowed": @(CGPreflightScreenCaptureAccess()),
            @"accessibilityAllowed": @(AXIsProcessTrusted()),
            @"displayQueryResult": @(displayResult),
            @"activeDisplayCount": @(displayCount)
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:result
                                                     options:NSJSONWritingPrettyPrinted
                                                       error:NULL];
        puts([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);
    }
    return 0;
}
