#import "WMLiquidGlassStyle.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSInteger const WMGlassEffectStyleRegular = 0;
static void *WMLiquidGlassBackdropKey = &WMLiquidGlassBackdropKey;

static UIVisualEffect *WMGlassEffect(void) {
    Class effectClass = NSClassFromString(@"UIGlassEffect");
    SEL initializer = NSSelectorFromString(@"initWithStyle:");
    if (effectClass != Nil &&
        [effectClass instancesRespondToSelector:initializer]) {
        id allocated = [effectClass alloc];
        id (*initialize)(id, SEL, NSInteger) =
            (id (*)(id, SEL, NSInteger))objc_msgSend;
        id effect = initialize(
            allocated,
            initializer,
            WMGlassEffectStyleRegular
        );
        if ([effect isKindOfClass:UIVisualEffect.class]) {
            return effect;
        }
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
}

static void WMGlassifyAppearance(UIBarAppearance *appearance) {
    appearance.backgroundEffect = nil;
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor =
        [UIColor.separatorColor colorWithAlphaComponent:0.18];
}

static void WMInstallGlassBackdrop(UIView *bar) {
    UIVisualEffectView *backdrop =
        objc_getAssociatedObject(bar, WMLiquidGlassBackdropKey);
    if (backdrop == nil) {
        backdrop = [[UIVisualEffectView alloc] initWithEffect:WMGlassEffect()];
        backdrop.translatesAutoresizingMaskIntoConstraints = NO;
        backdrop.userInteractionEnabled = NO;
        backdrop.accessibilityElementsHidden = YES;
        objc_setAssociatedObject(
            bar,
            WMLiquidGlassBackdropKey,
            backdrop,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    } else {
        backdrop.effect = WMGlassEffect();
    }
    if (backdrop.superview == bar) {
        return;
    }
    [bar insertSubview:backdrop atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [backdrop.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [backdrop.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [backdrop.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [backdrop.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor]
    ]];
}

static UINavigationBarAppearance *WMNavigationAppearance(void) {
    UINavigationBarAppearance *appearance =
        [UINavigationBarAppearance new];
    [appearance configureWithTransparentBackground];
    WMGlassifyAppearance(appearance);
    return appearance;
}

static UITabBarAppearance *WMTabAppearance(void) {
    UITabBarAppearance *appearance = [UITabBarAppearance new];
    [appearance configureWithTransparentBackground];
    WMGlassifyAppearance(appearance);
    return appearance;
}

static UIToolbarAppearance *WMToolbarAppearance(void) {
    UIToolbarAppearance *appearance = [UIToolbarAppearance new];
    [appearance configureWithTransparentBackground];
    WMGlassifyAppearance(appearance);
    return appearance;
}

static void WMGlassifyNavigationBar(UINavigationBar *bar) {
    UINavigationBarAppearance *appearance =
        [bar.standardAppearance copy] ?: WMNavigationAppearance();
    WMGlassifyAppearance(appearance);
    bar.standardAppearance = appearance;
    bar.scrollEdgeAppearance = [appearance copy];
    bar.compactAppearance = [appearance copy];
    bar.translucent = YES;
    WMInstallGlassBackdrop(bar);
}

static void WMGlassifyTabBar(UITabBar *bar) {
    UITabBarAppearance *appearance =
        [bar.standardAppearance copy] ?: WMTabAppearance();
    WMGlassifyAppearance(appearance);
    bar.standardAppearance = appearance;
    bar.scrollEdgeAppearance = [appearance copy];
    bar.translucent = YES;
    WMInstallGlassBackdrop(bar);
}

static void WMGlassifyToolbar(UIToolbar *bar) {
    UIToolbarAppearance *appearance =
        [bar.standardAppearance copy] ?: WMToolbarAppearance();
    WMGlassifyAppearance(appearance);
    bar.standardAppearance = appearance;
    bar.scrollEdgeAppearance = [appearance copy];
    bar.compactAppearance = [appearance copy];
    bar.translucent = YES;
    WMInstallGlassBackdrop(bar);
}

static void WMGlassifyViewTree(UIView *view) {
    if ([view isKindOfClass:UINavigationBar.class]) {
        WMGlassifyNavigationBar((UINavigationBar *)view);
    } else if ([view isKindOfClass:UITabBar.class]) {
        WMGlassifyTabBar((UITabBar *)view);
    } else if ([view isKindOfClass:UIToolbar.class]) {
        WMGlassifyToolbar((UIToolbar *)view);
    }
    for (UIView *subview in view.subviews) {
        WMGlassifyViewTree(subview);
    }
}

static void WMGlassifyWindows(void) {
    UIApplication *application = UIApplication.sharedApplication;
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            WMGlassifyViewTree(window);
        }
    }
}

static void WMInstallAppearanceDefaults(void) {
    UINavigationBarAppearance *navigation = WMNavigationAppearance();
    UINavigationBar *navigationProxy = UINavigationBar.appearance;
    navigationProxy.standardAppearance = navigation;
    navigationProxy.scrollEdgeAppearance = [navigation copy];
    navigationProxy.compactAppearance = [navigation copy];
    navigationProxy.translucent = YES;

    UITabBarAppearance *tab = WMTabAppearance();
    UITabBar *tabProxy = UITabBar.appearance;
    tabProxy.standardAppearance = tab;
    tabProxy.scrollEdgeAppearance = [tab copy];
    tabProxy.translucent = YES;

    UIToolbarAppearance *toolbar = WMToolbarAppearance();
    UIToolbar *toolbarProxy = UIToolbar.appearance;
    toolbarProxy.standardAppearance = toolbar;
    toolbarProxy.scrollEdgeAppearance = [toolbar copy];
    toolbarProxy.compactAppearance = [toolbar copy];
    toolbarProxy.translucent = YES;
}

@implementation WMLiquidGlassStyle

+ (void)install {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        WMInstallAppearanceDefaults();
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        NSArray<NSNotificationName> *notifications = @[
            UIApplicationDidFinishLaunchingNotification,
            UIApplicationDidBecomeActiveNotification
        ];
        for (NSNotificationName name in notifications) {
            [center addObserverForName:name
                               object:nil
                                queue:NSOperationQueue.mainQueue
                           usingBlock:^(__unused NSNotification *notification) {
                               dispatch_async(
                                   dispatch_get_main_queue(),
                                   ^{
                                       WMGlassifyWindows();
                                   }
                               );
                           }];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            WMGlassifyWindows();
        });
    });
}

@end
