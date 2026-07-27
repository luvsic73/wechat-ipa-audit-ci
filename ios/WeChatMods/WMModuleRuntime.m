#import "WMModuleRuntime.h"

#import "WMAntiRevokeModule.h"

static NSString *const WMModuleHealthKey = @"wechatmods.module-health";

@implementation WMModuleRuntime

+ (NSDictionary<NSString *, NSNumber *> *)installModules:
    (NSArray<NSString *> *)moduleIDs {
    NSMutableDictionary<NSString *, NSNumber *> *health =
        [NSMutableDictionary dictionary];
    for (NSString *moduleID in moduleIDs) {
        BOOL installed = NO;
        if ([moduleID isEqualToString:@"anti-revoke"]) {
            installed = [WMAntiRevokeModule install];
        }
        health[moduleID] = @(installed);
    }
    [NSUserDefaults.standardUserDefaults setObject:health
                                            forKey:WMModuleHealthKey];
    return health;
}

@end
