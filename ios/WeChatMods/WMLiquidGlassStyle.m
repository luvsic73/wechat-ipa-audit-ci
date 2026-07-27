#import "WMLiquidGlassStyle.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSInteger const WMGlassEffectStyleRegular = 0;
static void *WMLiquidGlassBackdropKey = &WMLiquidGlassBackdropKey;
static IMP WMNavigationDidMoveOriginal = NULL;
static IMP WMTabDidMoveOriginal = NULL;
static IMP WMToolbarDidMoveOriginal = NULL;
static IMP WMCustomNavigationDidMoveOriginal = NULL;
static IMP WMCustomTabDidMoveOriginal = NULL;
static BOOL WMNavigationHookInstalled = NO;
static BOOL WMTabHookInstalled = NO;
static BOOL WMToolbarHookInstalled = NO;
static BOOL WMCustomNavigationHookInstalled = NO;
static BOOL WMCustomTabHookInstalled = NO;

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
    backdrop.accessibilityIdentifier =
        @"wechatmods.liquid-glass-backdrop";
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

static void WMNavigationDidMove(
    UINavigationBar *bar,
    SEL selector
) {
    if (WMNavigationDidMoveOriginal != NULL) {
        ((void (*)(id, SEL))WMNavigationDidMoveOriginal)(
            bar,
            selector
        );
    }
    if (bar.window != nil) {
        WMGlassifyNavigationBar(bar);
    }
}

static void WMTabDidMove(UITabBar *bar, SEL selector) {
    if (WMTabDidMoveOriginal != NULL) {
        ((void (*)(id, SEL))WMTabDidMoveOriginal)(bar, selector);
    }
    if (bar.window != nil) {
        WMGlassifyTabBar(bar);
    }
}

static void WMToolbarDidMove(UIToolbar *bar, SEL selector) {
    if (WMToolbarDidMoveOriginal != NULL) {
        ((void (*)(id, SEL))WMToolbarDidMoveOriginal)(
            bar,
            selector
        );
    }
    if (bar.window != nil) {
        WMGlassifyToolbar(bar);
    }
}

static void WMGlassifyCustomBar(UIView *bar) {
    bar.opaque = NO;
    bar.backgroundColor = UIColor.clearColor;
    WMInstallGlassBackdrop(bar);
}

static void WMCustomNavigationDidMove(
    UIView *bar,
    SEL selector
) {
    if (WMCustomNavigationDidMoveOriginal != NULL) {
        ((void (*)(id, SEL))WMCustomNavigationDidMoveOriginal)(
            bar,
            selector
        );
    }
    if ([bar isKindOfClass:UINavigationBar.class]) {
        WMGlassifyNavigationBar((UINavigationBar *)bar);
    } else {
        WMGlassifyCustomBar(bar);
    }
}

static void WMCustomTabDidMove(UIView *bar, SEL selector) {
    if (WMCustomTabDidMoveOriginal != NULL) {
        ((void (*)(id, SEL))WMCustomTabDidMoveOriginal)(
            bar,
            selector
        );
    }
    if ([bar isKindOfClass:UITabBar.class]) {
        WMGlassifyTabBar((UITabBar *)bar);
    } else {
        WMGlassifyCustomBar(bar);
    }
}

static BOOL WMInstallDidMoveHook(
    Class viewClass,
    IMP replacement,
    IMP *original
) {
    if (viewClass == Nil) {
        return NO;
    }
    SEL selector = NSSelectorFromString(@"didMoveToWindow");
    Method method = class_getInstanceMethod(viewClass, selector);
    if (method == NULL) {
        return NO;
    }
    IMP inherited = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    if (class_addMethod(viewClass, selector, replacement, types)) {
        *original = inherited;
        return YES;
    }
    *original = method_setImplementation(method, replacement);
    return *original != NULL;
}

static void WMInstallDynamicBarHooks(void) {
    if (!WMNavigationHookInstalled) {
        WMNavigationHookInstalled = WMInstallDidMoveHook(
            UINavigationBar.class,
            (IMP)WMNavigationDidMove,
            &WMNavigationDidMoveOriginal
        );
    }
    if (!WMTabHookInstalled) {
        WMTabHookInstalled = WMInstallDidMoveHook(
            UITabBar.class,
            (IMP)WMTabDidMove,
            &WMTabDidMoveOriginal
        );
    }
    if (!WMToolbarHookInstalled) {
        WMToolbarHookInstalled = WMInstallDidMoveHook(
            UIToolbar.class,
            (IMP)WMToolbarDidMove,
            &WMToolbarDidMoveOriginal
        );
    }
    if (!WMCustomNavigationHookInstalled) {
        WMCustomNavigationHookInstalled = WMInstallDidMoveHook(
            NSClassFromString(@"MMUINavigationBar"),
            (IMP)WMCustomNavigationDidMove,
            &WMCustomNavigationDidMoveOriginal
        );
    }
    if (!WMCustomTabHookInstalled) {
        WMCustomTabHookInstalled = WMInstallDidMoveHook(
            NSClassFromString(@"MMTabBar"),
            (IMP)WMCustomTabDidMove,
            &WMCustomTabDidMoveOriginal
        );
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
        WMInstallDynamicBarHooks();
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        NSArray<NSNotificationName> *notifications = @[
            UIApplicationDidFinishLaunchingNotification,
            UIApplicationDidBecomeActiveNotification,
            UIWindowDidBecomeVisibleNotification
        ];
        for (NSNotificationName name in notifications) {
            [center addObserverForName:name
                               object:nil
                                queue:NSOperationQueue.mainQueue
                           usingBlock:^(__unused NSNotification *notification) {
                               dispatch_async(
                                   dispatch_get_main_queue(),
                                   ^{
                                       WMInstallDynamicBarHooks();
                                       WMGlassifyWindows();
                                   }
                               );
                           }];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            WMInstallDynamicBarHooks();
            WMGlassifyWindows();
        });
    });
}

@end
