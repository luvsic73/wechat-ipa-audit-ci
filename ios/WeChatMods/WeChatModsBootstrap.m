#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "WMFeatureStore.h"
#import "WMLiquidGlassStyle.h"
#import "WMLoginLayoutAdapter.h"
#import "WMModuleDescriptor.h"
#import "WMModuleRuntime.h"
#import "WMSafeModeController.h"
#import "WMSettingsEntry.h"

static NSArray<WMModuleDescriptor *> *WMLoadDescriptors(void) {
    NSURL *manifestURL = [
        NSBundle.mainBundle.resourceURL
        URLByAppendingPathComponent:@"WeChatMods/module-manifest.json"
    ];
    NSData *data = [NSData dataWithContentsOfURL:manifestURL];
    if (data == nil) {
        return @[];
    }
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:data
                                                              options:0
                                                                error:nil];
    NSArray *items = manifest[@"modules"];
    if (![items isKindOfClass:NSArray.class]) {
        return @[];
    }

    NSMutableArray<WMModuleDescriptor *> *descriptors = [NSMutableArray array];
    for (NSDictionary *item in items) {
        WMModuleDescriptor *descriptor =
            [WMModuleDescriptor descriptorWithDictionary:item];
        if (descriptor != nil) {
            [descriptors addObject:descriptor];
        }
    }
    return descriptors;
}

static void WMBootstrap(void) {
    [WMLiquidGlassStyle install];
    [WMLoginLayoutAdapter install];
    [WMSettingsEntry install];

    NSArray<WMModuleDescriptor *> *descriptors = WMLoadDescriptors();
    NSString *version =
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSMutableArray<NSString *> *eligibleModules = [NSMutableArray array];
    for (WMModuleDescriptor *descriptor in descriptors) {
        BOOL enabled = [WMFeatureStore
            isModuleEnabled:descriptor.moduleID
               defaultValue:descriptor.isEnabled];
        if (enabled &&
            [descriptor isCompatibleWithVersion:version] &&
            descriptor.passesHookPolicy) {
            [eligibleModules addObject:descriptor.moduleID];
        }
    }

    WMSafeModeController *safeMode = WMSafeModeController.sharedController;
    [safeMode beginLaunchWithEnabledModules:eligibleModules];
    if (safeMode.isSafeMode) {
        [eligibleModules removeAllObjects];
    }
    [WMModuleRuntime installModules:eligibleModules];

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(__unused NSNotification *notification) {
                    dispatch_after(
                        dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC),
                        dispatch_get_main_queue(),
                        ^{
                            [safeMode markLaunchStable];
                        }
                    );
                }];

}

__attribute__((constructor))
static void WeChatModsConstructor(void) {
    [NSUserDefaults.standardUserDefaults
        setBool:YES
         forKey:@"wechatmods.loader-constructor-ran"];
    dispatch_async(dispatch_get_main_queue(), ^{
        WMBootstrap();
    });
}
