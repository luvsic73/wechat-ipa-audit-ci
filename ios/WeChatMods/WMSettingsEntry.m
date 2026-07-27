#import "WMSettingsEntry.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "WMSettingsViewController.h"

static IMP WMOriginalSettingsReload = NULL;
static Ivar WMSettingsTableManagerIvar = NULL;
static BOOL WMSettingsEntryInstalled = NO;

static void WMOpenSettings(id object, __unused SEL selector) {
    if (![object isKindOfClass:UIViewController.class]) {
        return;
    }
    UIViewController *host = object;
    WMSettingsViewController *settings =
        [WMSettingsViewController new];
    if (host.navigationController != nil) {
        [host.navigationController
            pushViewController:settings
                     animated:YES];
    } else {
        UINavigationController *navigation =
            [[UINavigationController alloc]
                initWithRootViewController:settings];
        [host presentViewController:navigation
                           animated:YES
                         completion:nil];
    }
}

static void WMInsertSettingsRow(id object) {
    id tableManager = object_getIvar(
        object,
        WMSettingsTableManagerIvar
    );
    Class sectionClass =
        NSClassFromString(@"WCTableViewSectionManager");
    Class cellClass =
        NSClassFromString(@"WCTableViewNormalCellManager");
    SEL sectionFactory = NSSelectorFromString(@"sectionInfoDefaut");
    SEL cellFactory = NSSelectorFromString(
        @"normalCellForSel:target:title:accessoryType:"
    );
    SEL addCell = NSSelectorFromString(@"addCell:");
    SEL insertSection = NSSelectorFromString(@"insertSection:At:");
    if (tableManager == nil ||
        ![sectionClass respondsToSelector:sectionFactory] ||
        ![cellClass respondsToSelector:cellFactory] ||
        ![tableManager respondsToSelector:insertSection]) {
        return;
    }

    id (*makeSection)(id, SEL) =
        (id (*)(id, SEL))objc_msgSend;
    id section = makeSection(sectionClass, sectionFactory);
    if (section == nil || ![section respondsToSelector:addCell]) {
        return;
    }

    id (*makeCell)(id, SEL, SEL, id, id, long long) =
        (id (*)(id, SEL, SEL, id, id, long long))objc_msgSend;
    id cell = makeCell(
        cellClass,
        cellFactory,
        NSSelectorFromString(@"wm_openWeChatModsSettings"),
        object,
        @"微信 Glass",
        UITableViewCellAccessoryDisclosureIndicator
    );
    if (cell == nil) {
        return;
    }

    void (*sendObject)(id, SEL, id) =
        (void (*)(id, SEL, id))objc_msgSend;
    sendObject(section, addCell, cell);
    void (*insert)(id, SEL, id, unsigned int) =
        (void (*)(id, SEL, id, unsigned int))objc_msgSend;
    insert(tableManager, insertSection, section, 0);

    SEL getTableView = NSSelectorFromString(@"getTableView");
    if ([tableManager respondsToSelector:getTableView]) {
        id (*getObject)(id, SEL) =
            (id (*)(id, SEL))objc_msgSend;
        UITableView *tableView = getObject(
            tableManager,
            getTableView
        );
        if ([tableView isKindOfClass:UITableView.class]) {
            [tableView reloadData];
        }
    }
}

static void WMSettingsReload(id object, SEL selector) {
    if (WMOriginalSettingsReload != NULL) {
        ((void (*)(id, SEL))WMOriginalSettingsReload)(
            object,
            selector
        );
    }
    WMInsertSettingsRow(object);
}

@implementation WMSettingsEntry

+ (BOOL)install {
    @synchronized(self) {
        if (WMSettingsEntryInstalled) {
            return YES;
        }
        Class settingsClass =
            NSClassFromString(@"NewSettingViewController");
        SEL reloadSelector =
            NSSelectorFromString(@"reloadTableData");
        Method reloadMethod =
            class_getInstanceMethod(settingsClass, reloadSelector);
        WMSettingsTableManagerIvar =
            class_getInstanceVariable(settingsClass, "m_tableViewMgr");
        if (settingsClass == Nil ||
            reloadMethod == NULL ||
            WMSettingsTableManagerIvar == NULL ||
            method_getNumberOfArguments(reloadMethod) != 2 ||
            method_getTypeEncoding(reloadMethod)[0] != 'v') {
            return NO;
        }

        SEL openSelector =
            NSSelectorFromString(@"wm_openWeChatModsSettings");
        if (![settingsClass instancesRespondToSelector:openSelector] &&
            !class_addMethod(
                settingsClass,
                openSelector,
                (IMP)WMOpenSettings,
                "v@:"
            )) {
            return NO;
        }
        WMOriginalSettingsReload = method_setImplementation(
            reloadMethod,
            (IMP)WMSettingsReload
        );
        WMSettingsEntryInstalled =
            WMOriginalSettingsReload != NULL;
        return WMSettingsEntryInstalled;
    }
}

@end
