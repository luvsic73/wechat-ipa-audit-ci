#import "WMLiquidGlassStyle.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static void *WMLiquidGlassBackdropKey = &WMLiquidGlassBackdropKey;
static void *WMGlassBottomConstraintKey = &WMGlassBottomConstraintKey;
static void *WMReduceTransparencyStateKey =
    &WMReduceTransparencyStateKey;
static void *WMDarkerSystemColorsStateKey =
    &WMDarkerSystemColorsStateKey;
static IMP WMCustomNavigationDidMoveOriginal = NULL;
static IMP WMCustomTabDidMoveOriginal = NULL;
static IMP WMCustomNavigationLayoutOriginal = NULL;
static IMP WMCustomTabLayoutOriginal = NULL;
static BOOL WMCustomNavigationHookInstalled = NO;
static BOOL WMCustomTabHookInstalled = NO;

static UIVisualEffect *WMGlassEffect(void) {
    if (UIAccessibilityIsReduceTransparencyEnabled()) {
        return nil;
    }
    Class effectClass = NSClassFromString(@"UIGlassEffect");
    if (effectClass != Nil) {
        id effect = [effectClass new];
        SEL setInteractive = NSSelectorFromString(@"setInteractive:");
        if ([effect respondsToSelector:setInteractive]) {
            void (*setBool)(id, SEL, BOOL) =
                (void (*)(id, SEL, BOOL))objc_msgSend;
            setBool(effect, setInteractive, NO);
        }
        if ([effect isKindOfClass:UIVisualEffect.class]) {
            return effect;
        }
    }
    UIBlurEffectStyle style = UIAccessibilityDarkerSystemColorsEnabled()
        ? UIBlurEffectStyleSystemThickMaterial
        : UIBlurEffectStyleSystemMaterial;
    return [UIBlurEffect effectWithStyle:style];
}

static void WMUpdateGlassBackdrop(UIVisualEffectView *backdrop) {
    BOOL reduceTransparency =
        UIAccessibilityIsReduceTransparencyEnabled();
    BOOL darkerSystemColors =
        UIAccessibilityDarkerSystemColorsEnabled();
    NSNumber *previousReduce = objc_getAssociatedObject(
        backdrop,
        WMReduceTransparencyStateKey
    );
    NSNumber *previousDarker = objc_getAssociatedObject(
        backdrop,
        WMDarkerSystemColorsStateKey
    );
    if (previousReduce != nil &&
        previousDarker != nil &&
        previousReduce.boolValue == reduceTransparency &&
        previousDarker.boolValue == darkerSystemColors) {
        return;
    }
    backdrop.effect = WMGlassEffect();
    backdrop.backgroundColor = reduceTransparency
        ? UIColor.secondarySystemBackgroundColor
        : UIColor.clearColor;
    objc_setAssociatedObject(
        backdrop,
        WMReduceTransparencyStateKey,
        @(reduceTransparency),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
    objc_setAssociatedObject(
        backdrop,
        WMDarkerSystemColorsStateKey,
        @(darkerSystemColors),
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

static void WMUpdateFloatingTabLayout(
    UIView *bar,
    UIVisualEffectView *backdrop
) {
    CGFloat safeBottom = MAX(bar.safeAreaInsets.bottom, 8.0);
    NSLayoutConstraint *bottom = objc_getAssociatedObject(
        backdrop,
        WMGlassBottomConstraintKey
    );
    bottom.constant = -safeBottom;
    CGFloat height = MAX(
        44.0,
        CGRectGetHeight(bar.bounds) - 4.0 - safeBottom
    );
    backdrop.layer.cornerRadius = height * 0.5;
    backdrop.layer.cornerCurve = kCACornerCurveContinuous;
    backdrop.clipsToBounds = YES;
}

static void WMPrepareSystemTabBar(UIView *bar) {
    if (![bar isKindOfClass:UITabBar.class]) {
        return;
    }
    UITabBar *tabBar = (UITabBar *)bar;
    tabBar.translucent = YES;
    tabBar.barTintColor = UIColor.clearColor;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
}

static void WMInstallGlassBackdrop(UIView *bar, BOOL floating) {
    UIVisualEffectView *backdrop =
        objc_getAssociatedObject(bar, WMLiquidGlassBackdropKey);
    if (backdrop != nil && backdrop.superview == bar) {
        WMUpdateGlassBackdrop(backdrop);
        if (floating) {
            WMUpdateFloatingTabLayout(bar, backdrop);
        }
        return;
    }
    if (backdrop == nil) {
        backdrop = [[UIVisualEffectView alloc] initWithEffect:nil];
        backdrop.translatesAutoresizingMaskIntoConstraints = NO;
        backdrop.userInteractionEnabled = NO;
        backdrop.accessibilityElementsHidden = YES;
        backdrop.accessibilityIdentifier = floating
            ? @"wechatmods.floating-tab-glass"
            : @"wechatmods.liquid-glass-backdrop";
        objc_setAssociatedObject(
            bar,
            WMLiquidGlassBackdropKey,
            backdrop,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }
    WMUpdateGlassBackdrop(backdrop);
    [bar insertSubview:backdrop atIndex:0];
    if (floating) {
        NSLayoutConstraint *bottom = [
            backdrop.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor
        ];
        objc_setAssociatedObject(
            backdrop,
            WMGlassBottomConstraintKey,
            bottom,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
        [NSLayoutConstraint activateConstraints:@[
            [backdrop.leadingAnchor
                constraintEqualToAnchor:bar.leadingAnchor
                               constant:12.0],
            [backdrop.trailingAnchor
                constraintEqualToAnchor:bar.trailingAnchor
                               constant:-12.0],
            [backdrop.topAnchor
                constraintEqualToAnchor:bar.topAnchor
                               constant:4.0],
            bottom
        ]];
        WMUpdateFloatingTabLayout(bar, backdrop);
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [backdrop.leadingAnchor
                constraintEqualToAnchor:bar.leadingAnchor],
            [backdrop.trailingAnchor
                constraintEqualToAnchor:bar.trailingAnchor],
            [backdrop.topAnchor
                constraintEqualToAnchor:bar.topAnchor],
            [backdrop.bottomAnchor
                constraintEqualToAnchor:bar.bottomAnchor]
        ]];
    }
}

static void WMGlassifyNavigationBar(UIView *bar) {
    bar.opaque = NO;
    bar.backgroundColor = UIColor.clearColor;
    WMInstallGlassBackdrop(bar, NO);
}

static void WMGlassifyTabBar(UIView *bar) {
    bar.opaque = NO;
    bar.backgroundColor = UIColor.clearColor;
    bar.clipsToBounds = NO;
    WMPrepareSystemTabBar(bar);
    WMInstallGlassBackdrop(bar, YES);
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
    if (bar.window != nil) {
        WMGlassifyNavigationBar(bar);
    }
}

static void WMCustomTabDidMove(UIView *bar, SEL selector) {
    if (WMCustomTabDidMoveOriginal != NULL) {
        ((void (*)(id, SEL))WMCustomTabDidMoveOriginal)(
            bar,
            selector
        );
    }
    if (bar.window != nil) {
        WMGlassifyTabBar(bar);
    }
}

static void WMCustomNavigationLayout(
    UIView *bar,
    SEL selector
) {
    if (WMCustomNavigationLayoutOriginal != NULL) {
        ((void (*)(id, SEL))WMCustomNavigationLayoutOriginal)(
            bar,
            selector
        );
    }
    if (bar.window != nil) {
        WMGlassifyNavigationBar(bar);
    }
}

static void WMCustomTabLayout(UIView *bar, SEL selector) {
    if (WMCustomTabLayoutOriginal != NULL) {
        ((void (*)(id, SEL))WMCustomTabLayoutOriginal)(
            bar,
            selector
        );
    }
    if (bar.window != nil) {
        WMGlassifyTabBar(bar);
    }
}

static BOOL WMInstallHook(
    Class viewClass,
    SEL selector,
    IMP replacement,
    IMP *original
) {
    if (viewClass == Nil) {
        return NO;
    }
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

static BOOL WMInstallCustomBarHooks(
    Class viewClass,
    IMP didMoveReplacement,
    IMP *didMoveOriginal,
    IMP layoutReplacement,
    IMP *layoutOriginal
) {
    BOOL didMoveInstalled = WMInstallHook(
        viewClass,
        NSSelectorFromString(@"didMoveToWindow"),
        didMoveReplacement,
        didMoveOriginal
    );
    BOOL layoutInstalled = WMInstallHook(
        viewClass,
        NSSelectorFromString(@"layoutSubviews"),
        layoutReplacement,
        layoutOriginal
    );
    return didMoveInstalled && layoutInstalled;
}

static void WMInstallDynamicBarHooks(void) {
    if (!WMCustomNavigationHookInstalled) {
        Class navigationClass = NSClassFromString(@"MMUINavigationBar");
        WMCustomNavigationHookInstalled = WMInstallCustomBarHooks(
            navigationClass,
            (IMP)WMCustomNavigationDidMove,
            &WMCustomNavigationDidMoveOriginal,
            (IMP)WMCustomNavigationLayout,
            &WMCustomNavigationLayoutOriginal
        );
    }
    if (!WMCustomTabHookInstalled) {
        Class tabClass = NSClassFromString(@"MMTabBar");
        WMCustomTabHookInstalled = WMInstallCustomBarHooks(
            tabClass,
            (IMP)WMCustomTabDidMove,
            &WMCustomTabDidMoveOriginal,
            (IMP)WMCustomTabLayout,
            &WMCustomTabLayoutOriginal
        );
    }
}

static void WMRefreshVisibleLayouts(void) {
    for (UIScene *scene
         in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            (scene.activationState !=
                UISceneActivationStateForegroundActive &&
             scene.activationState !=
                UISceneActivationStateForegroundInactive)) {
            continue;
        }
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isHidden ||
                window.alpha <= 0.0 ||
                window.rootViewController == nil) {
                continue;
            }
            UIView *rootView = window.rootViewController.view;
            [rootView setNeedsLayout];
            [rootView layoutIfNeeded];
        }
    }
}

@implementation WMLiquidGlassStyle

+ (void)install {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        WMInstallDynamicBarHooks();
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        for (NSNotificationName name in @[
            UIApplicationDidFinishLaunchingNotification,
            UIApplicationDidBecomeActiveNotification,
            UIWindowDidBecomeVisibleNotification,
            UIAccessibilityReduceTransparencyStatusDidChangeNotification,
            UIAccessibilityDarkerSystemColorsStatusDidChangeNotification
        ]) {
            [center addObserverForName:name
                               object:nil
                                queue:NSOperationQueue.mainQueue
                           usingBlock:^(
                               __unused NSNotification *notification
                           ) {
                               WMInstallDynamicBarHooks();
                               WMRefreshVisibleLayouts();
                           }];
        }
        WMRefreshVisibleLayouts();
    });
}

@end
