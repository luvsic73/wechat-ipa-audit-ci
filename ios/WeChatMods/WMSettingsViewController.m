#import "WMSettingsViewController.h"

#import "WMFeatureStore.h"

static NSString *const WMAntiRevokeModuleID = @"anti-revoke";
static NSString *const WMModuleHealthKey = @"wechatmods.module-health";
static NSString *const WMSafeModeKey = @"wechatmods.safe-mode";

typedef NS_ENUM(NSInteger, WMSettingsSection) {
    WMSettingsSectionInterface,
    WMSettingsSectionMessages,
    WMSettingsSectionStability,
    WMSettingsSectionBuild,
    WMSettingsSectionCount
};

@interface WMSettingsViewController ()
@property(nonatomic, strong) UISwitch *antiRevokeSwitch;
@end

@implementation WMSettingsViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"微信 Glass";
    self.navigationItem.largeTitleDisplayMode =
        UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.rowHeight = 52.0;
    self.tableView.estimatedRowHeight = 52.0;
}

- (NSInteger)numberOfSectionsInTableView:
    (__unused UITableView *)tableView {
    return WMSettingsSectionCount;
}

- (NSInteger)tableView:(__unused UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    switch ((WMSettingsSection)section) {
        case WMSettingsSectionInterface:
            return 2;
        case WMSettingsSectionMessages:
            return 1;
        case WMSettingsSectionStability:
            return 2;
        case WMSettingsSectionBuild:
            return 2;
        case WMSettingsSectionCount:
            return 0;
    }
    return 0;
}

- (NSString *)tableView:(__unused UITableView *)tableView
 titleForHeaderInSection:(NSInteger)section {
    switch ((WMSettingsSection)section) {
        case WMSettingsSectionInterface:
            return @"界面";
        case WMSettingsSectionMessages:
            return @"消息";
        case WMSettingsSectionStability:
            return @"稳定性";
        case WMSettingsSectionBuild:
            return @"构建";
        case WMSettingsSectionCount:
            return nil;
    }
    return nil;
}

- (NSString *)tableView:(__unused UITableView *)tableView
 titleForFooterInSection:(NSInteger)section {
    return section == WMSettingsSectionMessages
        ? @"更改后重启微信生效"
        : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const identifier = @"wechatmods.settings-cell";
    UITableViewCell *cell = [tableView
        dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc]
            initWithStyle:UITableViewCellStyleValue1
          reuseIdentifier:identifier];
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;

    switch ((WMSettingsSection)indexPath.section) {
        case WMSettingsSectionInterface:
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Liquid Glass";
                cell.detailTextLabel.text = @"固定开启";
            } else {
                cell.textLabel.text = @"官方客户端共存";
                cell.detailTextLabel.text =
                    NSBundle.mainBundle.bundleIdentifier;
            }
            break;
        case WMSettingsSectionMessages: {
            cell.textLabel.text = @"防撤回";
            cell.detailTextLabel.text = nil;
            UISwitch *toggle = [UISwitch new];
            toggle.on = [WMFeatureStore
                isModuleEnabled:WMAntiRevokeModuleID
                   defaultValue:YES];
            toggle.accessibilityLabel = @"防撤回";
            [toggle addTarget:self
                       action:@selector(antiRevokeChanged:)
             forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            self.antiRevokeSwitch = toggle;
            break;
        }
        case WMSettingsSectionStability:
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Safe Mode";
                cell.detailTextLabel.text =
                    [NSUserDefaults.standardUserDefaults
                        boolForKey:WMSafeModeKey]
                    ? @"已启用"
                    : @"正常";
            } else {
                cell.textLabel.text = @"防撤回加载";
                NSDictionary *health =
                    [NSUserDefaults.standardUserDefaults
                        dictionaryForKey:WMModuleHealthKey];
                NSNumber *value = health[WMAntiRevokeModuleID];
                cell.detailTextLabel.text = value == nil
                    ? @"等待重启"
                    : (value.boolValue ? @"正常" : @"签名检查未通过");
            }
            break;
        case WMSettingsSectionBuild:
            if (indexPath.row == 0) {
                cell.textLabel.text = @"微信基线";
                cell.detailTextLabel.text = @"8.0.75 (8.0.75.33)";
            } else {
                cell.textLabel.text = @"共存标识";
                cell.detailTextLabel.text =
                    NSBundle.mainBundle.bundleIdentifier;
            }
            break;
        case WMSettingsSectionCount:
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != WMSettingsSectionMessages ||
        indexPath.row != 0) {
        return;
    }
    [self.antiRevokeSwitch
        setOn:!self.antiRevokeSwitch.isOn
     animated:YES];
    [self antiRevokeChanged:self.antiRevokeSwitch];
}

- (void)antiRevokeChanged:(UISwitch *)sender {
    [WMFeatureStore setModule:WMAntiRevokeModuleID
                      enabled:sender.isOn];
    self.navigationItem.prompt = @"更改后重启微信生效";
}

@end
