#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WMModuleRuntime : NSObject

+ (NSDictionary<NSString *, NSNumber *> *)installModules:
    (NSArray<NSString *> *)moduleIDs;

@end

NS_ASSUME_NONNULL_END
