#import "WMModuleDescriptor.h"

static NSSet<NSString *> *WMAllowedHooks(void) {
    return [NSSet setWithObject:@"CMessageMgr.onRevokeMsg:"];
}

@implementation WMModuleDescriptor

+ (nullable instancetype)descriptorWithDictionary:(NSDictionary *)dictionary {
    NSString *moduleID = dictionary[@"id"];
    NSArray *versions = dictionary[@"compatible_versions"];
    NSArray *dependencies = dictionary[@"dependencies"];
    NSArray *hooks = dictionary[@"hooks"];
    NSString *healthCheck = dictionary[@"health_check"];
    NSString *risk = dictionary[@"risk"];
    NSNumber *enabled = dictionary[@"enabled"];
    if (![moduleID isKindOfClass:NSString.class] ||
        ![versions isKindOfClass:NSArray.class] ||
        ![dependencies isKindOfClass:NSArray.class] ||
        ![hooks isKindOfClass:NSArray.class] ||
        ![healthCheck isKindOfClass:NSString.class] ||
        ![risk isKindOfClass:NSString.class] ||
        ![enabled isKindOfClass:NSNumber.class]) {
        return nil;
    }

    WMModuleDescriptor *descriptor = [self new];
    descriptor->_moduleID = [moduleID copy];
    descriptor->_compatibleVersions = [versions copy];
    descriptor->_dependencies = [dependencies copy];
    descriptor->_hooks = [hooks copy];
    descriptor->_healthCheck = [healthCheck copy];
    descriptor->_riskLevel = [risk copy];
    descriptor->_enabled = enabled.boolValue;
    return descriptor;
}

- (BOOL)isCompatibleWithVersion:(NSString *)version {
    return [self.compatibleVersions containsObject:version];
}

- (BOOL)passesHookPolicy {
    for (NSString *hook in self.hooks) {
        if (![WMAllowedHooks() containsObject:hook]) {
            return NO;
        }
    }
    return YES;
}

@end
