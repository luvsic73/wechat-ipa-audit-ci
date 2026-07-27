#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WMModuleDescriptor : NSObject

@property(nonatomic, copy, readonly) NSString *moduleID;
@property(nonatomic, copy, readonly) NSArray<NSString *> *compatibleVersions;
@property(nonatomic, copy, readonly) NSArray<NSString *> *dependencies;
@property(nonatomic, copy, readonly) NSArray<NSString *> *hooks;
@property(nonatomic, copy, readonly) NSString *healthCheck;
@property(nonatomic, copy, readonly) NSString *riskLevel;
@property(nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;

+ (nullable instancetype)descriptorWithDictionary:(NSDictionary *)dictionary;
- (BOOL)isCompatibleWithVersion:(NSString *)version;
- (BOOL)passesHookPolicy;

@end

NS_ASSUME_NONNULL_END
