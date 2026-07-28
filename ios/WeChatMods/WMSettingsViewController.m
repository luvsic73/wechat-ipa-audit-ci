#import "WMSettingsViewController.h"

#import "WMFeatureStore.h"
#import "WMLocalization.h"
#import "WMModuleCatalog.h"
#import "WMModuleDescriptor.h"

#import <objc/runtime.h>

static NSString *const WMModuleHealthKey = @"wechatmods.module-health";
static NSString *const WMBlockedModulesKey = @"wechatmods.blocked-modules";
static NSString *const WMSafeModeKey = @"wechatmods.safe-mode";
static void *WMModuleIDAssociationKey = &WMModuleIDAssociationKey;

@interface WMSettingsViewController ()
@property(nonatomic, copy) NSArray<NSString *> *groups;
@property(nonatomic, copy) NSDictionary<
    NSString *,
    NSArray<WMModuleDescriptor *> *
> *descriptorsByGroup;
@end

@implementation WMSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = WMLocalizedString(
        @"wechatmods.settings.title",
        @"微信 Glass"
    );
    self.navigationItem.largeTitleDisplayMode =
        UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60.0;
    [self rebuildSections];
}

- (void)rebuildSections {
    NSMutableDictionary<
        NSString *,
        NSMutableArray<WMModuleDescriptor *> *
    > *mutableGroups = [NSMutableDictionary dictionary];
    for (WMModuleDescriptor *descriptor
         in WMModuleCatalog.sharedCatalog.descriptors) {
        NSMutableArray<WMModuleDescriptor *> *items =
            mutableGroups[descriptor.group];
        if (items == nil) {
            items = [NSMutableArray array];
            mutableGroups[descriptor.group] = items;
        }
        [items addObject:descriptor];
    }

    NSArray<NSString *> *preferredOrder = @[
        @"messages",
        @"media",
        @"groups",
        @"automation",
        @"interface",
        @"account",
        @"experimental",
        @"contacts",
        @"privacy",
    ];
    NSMutableArray<NSString *> *groups = [NSMutableArray array];
    for (NSString *group in preferredOrder) {
        if (mutableGroups[group].count > 0) {
            [groups addObject:group];
        }
    }
    for (NSString *group in [
        mutableGroups.allKeys
        sortedArrayUsingSelector:@selector(compare:)
    ]) {
        if (![groups containsObject:group]) {
            [groups addObject:group];
        }
    }
    self.groups = groups;
    self.descriptorsByGroup = mutableGroups;
}

- (nullable WMModuleDescriptor *)descriptorForIndexPath:
    (NSIndexPath *)indexPath {
    if (indexPath.section == 0 ||
        indexPath.section == (NSInteger)self.groups.count + 1) {
        return nil;
    }
    NSString *group = self.groups[indexPath.section - 1];
    NSArray<WMModuleDescriptor *> *descriptors =
        self.descriptorsByGroup[group];
    if (indexPath.row >= (NSInteger)descriptors.count) {
        return nil;
    }
    return descriptors[indexPath.row];
}

- (nullable WMModuleDescriptor *)descriptorForModuleID:
    (NSString *)moduleID {
    for (WMModuleDescriptor *descriptor
         in WMModuleCatalog.sharedCatalog.descriptors) {
        if ([descriptor.moduleID isEqualToString:moduleID]) {
            return descriptor;
        }
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:
    (__unused UITableView *)tableView {
    return (NSInteger)self.groups.count + 2;
}

- (NSInteger)tableView:(__unused UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2;
    }
    if (section == (NSInteger)self.groups.count + 1) {
        return 5;
    }
    NSString *group = self.groups[section - 1];
    return (NSInteger)self.descriptorsByGroup[group].count;
}

- (nullable NSString *)tableView:(__unused UITableView *)tableView
         titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return WMLocalizedString(
            @"wechatmods.settings.section.appearance",
            @"外观与加载"
        );
    }
    if (section == (NSInteger)self.groups.count + 1) {
        return WMLocalizedString(
            @"wechatmods.settings.section.runtime",
            @"运行状态"
        );
    }
    NSDictionary<NSString *, NSString *> *titles = @{
        @"messages": WMLocalizedString(
            @"wechatmods.settings.section.messages",
            @"消息"
        ),
        @"media": WMLocalizedString(
            @"wechatmods.settings.section.media",
            @"媒体与文件"
        ),
        @"groups": WMLocalizedString(
            @"wechatmods.settings.section.groups",
            @"群聊"
        ),
        @"automation": WMLocalizedString(
            @"wechatmods.settings.section.automation",
            @"自动化"
        ),
        @"interface": WMLocalizedString(
            @"wechatmods.settings.section.interface",
            @"界面与操作"
        ),
        @"account": WMLocalizedString(
            @"wechatmods.settings.section.account",
            @"账号、推送与多开"
        ),
        @"experimental": WMLocalizedString(
            @"wechatmods.settings.section.experimental",
            @"实验功能"
        ),
        @"contacts": WMLocalizedString(
            @"wechatmods.settings.section.contacts",
            @"联系人"
        ),
        @"privacy": WMLocalizedString(
            @"wechatmods.settings.section.privacy",
            @"隐私"
        ),
    };
    NSString *group = self.groups[section - 1];
    return titles[group] ?: group;
}

- (nullable NSString *)tableView:(__unused UITableView *)tableView
         titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return WMLocalizedString(
            @"wechatmods.settings.footer.common",
            @"每项独立控制；更改后重启微信生效。高风险项会再次确认。"
        );
    }
    return nil;
}

- (UITableViewCell *)specialCellForTableView:(UITableView *)tableView
                                  indexPath:(NSIndexPath *)indexPath {
    static NSString *const identifier = @"wechatmods.special-cell";
    UITableViewCell *cell = [
        tableView
        dequeueReusableCellWithIdentifier:identifier
    ];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleValue1
          reuseIdentifier:identifier];
    }
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font =
        [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.font =
        [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = WMLocalizedString(
                @"wechatmods.settings.glass",
                @"Liquid Glass"
            );
            cell.detailTextLabel.text = WMLocalizedString(
                @"wechatmods.settings.always_on",
                @"固定开启"
            );
        } else {
            cell.textLabel.text = WMLocalizedString(
                @"wechatmods.settings.feature_switches",
                @"功能开关"
            );
            NSString *format = WMLocalizedString(
                @"wechatmods.settings.modules_all_off_format",
                @"%lu 项 · 默认全关"
            );
            cell.detailTextLabel.text = [NSString stringWithFormat:
                format,
                (unsigned long)WMModuleCatalog.sharedCatalog.descriptors.count];
        }
        return cell;
    }

    NSDictionary *blocked = [
        NSUserDefaults.standardUserDefaults
        dictionaryForKey:WMBlockedModulesKey
    ] ?: @{};
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = WMLocalizedString(
                @"wechatmods.settings.safe_mode",
                @"Safe Mode"
            );
            cell.detailTextLabel.text = [
                NSUserDefaults.standardUserDefaults
                boolForKey:WMSafeModeKey
            ] ? WMLocalizedString(
                @"wechatmods.settings.enabled",
                @"已启用"
            ) : WMLocalizedString(
                @"wechatmods.settings.normal",
                @"正常"
            );
            break;
        case 1:
            cell.textLabel.text = WMLocalizedString(
                @"wechatmods.settings.blocked_modules",
                @"被阻断模块"
            );
            cell.detailTextLabel.text =
                [NSString stringWithFormat:@"%lu",
                                           (unsigned long)blocked.count];
            break;
        case 2:
            cell.textLabel.text = WMLocalizedString(
                @"wechatmods.settings.catalog_validation",
                @"目录校验"
            );
            cell.detailTextLabel.text =
                WMModuleCatalog.sharedCatalog.loadErrors.count == 0
                ? WMLocalizedString(
                    @"wechatmods.settings.normal",
                    @"正常"
                )
                : [NSString stringWithFormat:WMLocalizedString(
                    @"wechatmods.settings.error_count_format",
                    @"%lu 个错误"
                ),
                    (unsigned long)
                        WMModuleCatalog.sharedCatalog.loadErrors.count];
            break;
        case 3:
            cell.textLabel.text = WMLocalizedString(
                @"wechatmods.settings.baseline",
                @"微信基线"
            );
            cell.detailTextLabel.text = @"8.0.75";
            break;
        case 4:
            cell.textLabel.text = WMLocalizedString(
                @"wechatmods.settings.coexist_id",
                @"共存标识"
            );
            cell.detailTextLabel.text =
                NSBundle.mainBundle.bundleIdentifier;
            break;
    }
    return cell;
}

- (NSString *)riskSummaryForDescriptor:
    (WMModuleDescriptor *)descriptor {
    NSDictionary<NSString *, NSString *> *labels = @{
        @"low": WMLocalizedString(
            @"wechatmods.risk.low",
            @"低风险"
        ),
        @"medium": WMLocalizedString(
            @"wechatmods.risk.medium",
            @"中风险"
        ),
        @"high": WMLocalizedString(
            @"wechatmods.risk.high",
            @"高风险"
        ),
        @"critical": WMLocalizedString(
            @"wechatmods.risk.critical",
            @"极高风险"
        ),
    };
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:
        labels[descriptor.riskLevel] ?: descriptor.riskLevel];
    if (![descriptor.activationGate isEqualToString:@"ready"]) {
        [parts addObject:WMLocalizedString(
            @"wechatmods.status.awaiting_offline_validation",
            @"等待离线验证"
        )];
    }

    NSDictionary *health = [
        NSUserDefaults.standardUserDefaults
        dictionaryForKey:WMModuleHealthKey
    ];
    NSDictionary *moduleHealth = health[descriptor.moduleID];
    NSString *status = moduleHealth[@"status"];
    if ([status isKindOfClass:NSString.class]) {
        [parts addObject:status];
    }
    return [parts componentsJoinedByString:@" · "];
}

- (UITableViewCell *)moduleCellForTableView:(UITableView *)tableView
                                 descriptor:
    (WMModuleDescriptor *)descriptor {
    static NSString *const identifier = @"wechatmods.module-cell";
    UITableViewCell *cell = [
        tableView
        dequeueReusableCellWithIdentifier:identifier
    ];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleSubtitle
          reuseIdentifier:identifier];
    }
    NSString *title = descriptor.title;
    if (title.length == 0 &&
        [descriptor.moduleID isEqualToString:@"anti-revoke"]) {
        title = @"防撤回";
    }
    title = WMLocalizedString(
        [@"wechatmods.module." stringByAppendingString:
            descriptor.moduleID],
        title ?: descriptor.moduleID
    );
    cell.textLabel.text = title;
    cell.textLabel.font =
        [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.numberOfLines = 0;
    NSString *riskSummary =
        [self riskSummaryForDescriptor:descriptor];
    cell.detailTextLabel.text = riskSummary;
    cell.detailTextLabel.font =
        [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor =
        [descriptor.riskLevel isEqualToString:@"critical"]
        ? UIColor.systemRedColor
        : ([descriptor.riskLevel isEqualToString:@"high"]
            ? UIColor.systemOrangeColor
            : UIColor.secondaryLabelColor);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    UISwitch *toggle = [UISwitch new];
    toggle.on = [WMFeatureStore isModuleEnabled:descriptor.moduleID];
    toggle.enabled =
        [descriptor.activationGate isEqualToString:@"ready"];
    toggle.accessibilityIdentifier = descriptor.moduleID;
    toggle.accessibilityLabel = title;
    NSString *hintFormat = WMLocalizedString(
        toggle.isEnabled
            ? @"wechatmods.accessibility.module_hint_format"
            : @"wechatmods.accessibility.module_blocked_hint_format",
        toggle.isEnabled
            ? @"%@。更改后重启微信生效。"
            : @"%@。当前等待离线验证。"
    );
    toggle.accessibilityHint = [NSString stringWithFormat:
        hintFormat,
        riskSummary
    ];
    objc_setAssociatedObject(
        toggle,
        WMModuleIDAssociationKey,
        descriptor.moduleID,
        OBJC_ASSOCIATION_COPY_NONATOMIC
    );
    [toggle addTarget:self
               action:@selector(toggleChanged:)
     forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WMModuleDescriptor *descriptor =
        [self descriptorForIndexPath:indexPath];
    return descriptor == nil
        ? [self specialCellForTableView:tableView indexPath:indexPath]
        : [self moduleCellForTableView:tableView descriptor:descriptor];
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WMModuleDescriptor *descriptor =
        [self descriptorForIndexPath:indexPath];
    if (descriptor == nil ||
        ![descriptor.activationGate isEqualToString:@"ready"]) {
        return;
    }
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    UISwitch *toggle = [cell.accessoryView isKindOfClass:UISwitch.class]
        ? (UISwitch *)cell.accessoryView
        : nil;
    if (toggle != nil) {
        [toggle setOn:!toggle.isOn animated:YES];
        [self toggleChanged:toggle];
    }
}

- (void)commitDescriptor:(WMModuleDescriptor *)descriptor
                 enabled:(BOOL)enabled {
    [WMFeatureStore setModule:descriptor.moduleID enabled:enabled];
    self.navigationItem.prompt = WMLocalizedString(
        @"wechatmods.prompt.restart_required",
        @"更改后重启微信生效"
    );
    [self.tableView reloadData];
    UIAccessibilityPostNotification(
        UIAccessibilityAnnouncementNotification,
        WMLocalizedString(
            @"wechatmods.accessibility.saved_announcement",
            @"设置已保存，重启微信后生效"
        )
    );
}

- (void)toggleChanged:(UISwitch *)toggle {
    NSString *moduleID =
        objc_getAssociatedObject(toggle, WMModuleIDAssociationKey);
    WMModuleDescriptor *descriptor =
        [self descriptorForModuleID:moduleID];
    if (descriptor == nil) {
        [toggle setOn:NO animated:YES];
        return;
    }
    if (![descriptor.activationGate isEqualToString:@"ready"]) {
        [toggle setOn:NO animated:YES];
        self.navigationItem.prompt = WMLocalizedString(
            @"wechatmods.prompt.awaiting_validation",
            @"该项等待离线验证"
        );
        return;
    }
    BOOL highRisk =
        [descriptor.riskLevel isEqualToString:@"high"] ||
        [descriptor.riskLevel isEqualToString:@"critical"];
    if (!toggle.isOn || !highRisk) {
        [self commitDescriptor:descriptor enabled:toggle.isOn];
        return;
    }

    [toggle setOn:NO animated:YES];
    NSString *message = descriptor.riskReasons.count == 0
        ? WMLocalizedString(
            @"wechatmods.alert.generic_risk",
            @"该功能会改变运行行为。"
        )
        : [descriptor.riskReasons componentsJoinedByString:@"、"];
    UIAlertController *alert = [
        UIAlertController
        alertControllerWithTitle:WMLocalizedString(
            @"wechatmods.alert.high_risk_title",
            @"确认开启高风险功能"
        )
                     message:message
              preferredStyle:UIAlertControllerStyleAlert
    ];
    [alert addAction:[
        UIAlertAction
        actionWithTitle:WMLocalizedString(
            @"wechatmods.alert.keep_disabled",
            @"保持关闭"
        )
                  style:UIAlertActionStyleCancel
                handler:nil
    ]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[
        UIAlertAction
        actionWithTitle:WMLocalizedString(
            @"wechatmods.alert.confirm_enable",
            @"确认开启"
        )
                  style:UIAlertActionStyleDestructive
                handler:^(__unused UIAlertAction *action) {
                    [weakSelf commitDescriptor:descriptor enabled:YES];
                }
    ]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
