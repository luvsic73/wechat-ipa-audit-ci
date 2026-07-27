#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WMFeatureStore : NSObject

+ (BOOL)isModuleEnabled:(NSString *)moduleID
           defaultValue:(BOOL)defaultValue;
+ (void)setModule:(NSString *)moduleID enabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
