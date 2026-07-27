#import "WMFeatureStore.h"

static NSString *const WMModuleOverridesKey =
    @"wechatmods.module-overrides";

@implementation WMFeatureStore

+ (BOOL)isModuleEnabled:(NSString *)moduleID
           defaultValue:(BOOL)defaultValue {
    NSDictionary<NSString *, NSNumber *> *overrides =
        [NSUserDefaults.standardUserDefaults
            dictionaryForKey:WMModuleOverridesKey];
    NSNumber *value = overrides[moduleID];
    return value == nil ? defaultValue : value.boolValue;
}

+ (void)setModule:(NSString *)moduleID enabled:(BOOL)enabled {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary<NSString *, NSNumber *> *overrides =
        [[defaults dictionaryForKey:WMModuleOverridesKey]
            mutableCopy] ?: [NSMutableDictionary dictionary];
    overrides[moduleID] = @(enabled);
    [defaults setObject:overrides forKey:WMModuleOverridesKey];
}

@end
