#import "WMLocalization.h"

static NSBundle *WMLocalizationBundle(void) {
    static NSBundle *bundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *url = [
            NSBundle.mainBundle
            URLForResource:@"WeChatModsLocalization"
             withExtension:@"bundle"
              subdirectory:@"WeChatMods"
        ];
        bundle = url == nil ? nil : [NSBundle bundleWithURL:url];
    });
    return bundle;
}

NSString *WMLocalizedString(NSString *key, NSString *fallback) {
    NSBundle *bundle = WMLocalizationBundle();
    if (bundle == nil) {
        return fallback;
    }
    return [bundle localizedStringForKey:key value:fallback table:nil];
}
