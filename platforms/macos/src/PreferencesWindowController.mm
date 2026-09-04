#import "PreferencesWindowController.h"

#include "CandidateFontSize.h"
#include "CandidatePageSize.h"
#include "CandidatePanelStyle.h"
#include "InputSchemePreference.h"
#import "DictionaryInstaller.h"
#import "UpdateController.h"

#include <cstring>

NSNotificationName const MetasequoiaWillResetLearnedDataNotification =
    @"MetasequoiaWillResetLearnedDataNotification";
NSNotificationName const MetasequoiaStandalonePreferencesDidCloseNotification =
    @"MetasequoiaStandalonePreferencesDidCloseNotification";

bool MetasequoiaShouldShowPreferences(int argc, const char *argv[])
{
    return argc == 2 && argv != nullptr && argv[1] != nullptr && std::strcmp(argv[1], "--show-settings") == 0;
}

namespace
{
constexpr CGFloat kWindowWidth = 720.0;
constexpr CGFloat kWindowHeight = 560.0;
NSString * const kSchemePreferenceKey = @"MetasequoiaImeInputScheme";
NSString * const kAutocorrectPreferenceKey = @"MetasequoiaImeQuanpinAutocorrect";
NSString * const kHelpcodePreferenceKey = @"MetasequoiaImeHelpcodeEnabled";
NSString * const kChinesePunctuationPreferenceKey = @"MetasequoiaImeChinesePunctuation";
NSString * const kCandidatePanelStylePreferenceKey = @"MetasequoiaImeCandidatePanelStyle";
NSString * const kCandidatePageSizePreferenceKey = @"MetasequoiaImeCandidatePageSize";
NSString * const kCandidateFontSizePreferenceKey = @"MetasequoiaImeCandidateFontSize";
NSString * const kCandidateLearningPreferenceKey = @"MetasequoiaImeCandidateLearning";
NSString * const kEnglishInputModePreferenceKey = @"MetasequoiaImeEnglishInputMode";
NSString * const kInputModeShortcutPreferenceKey = @"MetasequoiaImeInputModeShortcutEnabled";

NSColor *MetasequoiaBrandColor()
{
    return [NSColor colorWithName:@"MetasequoiaBrandColor" dynamicProvider:^NSColor *(NSAppearance *appearance) {
        NSString *match = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        if ([match isEqualToString:NSAppearanceNameDarkAqua])
        {
            return [NSColor colorWithSRGBRed:0.08 green:0.38 blue:0.35 alpha:1.0];
        }
        return [NSColor colorWithSRGBRed:0.07 green:0.49 blue:0.45 alpha:1.0];
    }];
}

void ConfigureCard(NSBox *card)
{
    card.boxType = NSBoxCustom;
    card.titlePosition = NSNoTitle;
    card.borderWidth = 1.0;
    card.cornerRadius = 12.0;
    card.borderColor = [NSColor separatorColor];
    card.fillColor = [NSColor controlBackgroundColor];
    card.translatesAutoresizingMaskIntoConstraints = NO;
}

NSTextField *SectionLabel(NSString *title)
{
    NSTextField *label = [NSTextField labelWithString:title];
    label.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
    label.textColor = [NSColor secondaryLabelColor];
    return label;
}

NSView *PreferenceRow(NSString *title, NSView *control)
{
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    NSTextField *label = [NSTextField labelWithString:title];
    label.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    control.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];
    [row addSubview:control];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:34.0],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:control.leadingAnchor constant:-12.0],
        [control.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [control.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [control.widthAnchor constraintEqualToConstant:188.0],
    ]];
    return row;
}

NSBox *CardWithViews(NSArray<NSView *> *views, CGFloat spacing)
{
    NSBox *card = [[NSBox alloc] initWithFrame:NSZeroRect];
    ConfigureCard(card);
    NSStackView *stack = [NSStackView stackViewWithViews:views];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.distribution = NSStackViewDistributionFill;
    stack.spacing = spacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12.0],
    ]];
    return card;
}

NSView *PreferencesPage(NSString *title, NSString *summary, NSArray<NSView *> *content)
{
    NSView *page = [[NSView alloc] initWithFrame:NSZeroRect];
    page.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *titleLabel = [NSTextField labelWithString:title];
    titleLabel.font = [NSFont systemFontOfSize:24.0 weight:NSFontWeightSemibold];
    NSTextField *descriptionLabel = [NSTextField labelWithString:summary];
    descriptionLabel.textColor = [NSColor secondaryLabelColor];
    descriptionLabel.maximumNumberOfLines = 2;
    NSStackView *stack = [NSStackView stackViewWithViews:@[ titleLabel, descriptionLabel ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.distribution = NSStackViewDistributionFill;
    stack.spacing = 7.0;
    for (NSView *view in content)
    {
        [stack addArrangedSubview:view];
        [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }
    [stack setCustomSpacing:22.0 afterView:descriptionLabel];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:page.leadingAnchor constant:30.0],
        [stack.trailingAnchor constraintEqualToAnchor:page.trailingAnchor constant:-30.0],
        [stack.topAnchor constraintEqualToAnchor:page.topAnchor constant:28.0],
    ]];
    return page;
}
} // namespace

@implementation MetasequoiaPreferencesWindowController
{
    NSArray<NSButton *> *_schemeButtons;
    NSButton *_autocorrectButton;
    NSButton *_helpcodeButton;
    NSButton *_chinesePunctuationButton;
    NSPopUpButton *_candidatePanelStyleButton;
    NSPopUpButton *_candidatePageSizeButton;
    NSPopUpButton *_candidateFontSizeButton;
    NSButton *_candidateLearningButton;
    NSButton *_inputModeShortcutButton;
    NSButton *_resetLearningButton;
    NSTextField *_statusLabel;
    NSButton *_updateButton;
    NSArray<NSView *> *_preferencePages;
    NSArray<NSButton *> *_navigationButtons;
    BOOL _standaloneLaunch;
}

+ (instancetype)sharedController
{
    static MetasequoiaPreferencesWindowController *controller = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [[self alloc] init];
    });
    return controller;
}

+ (void)prepareInputSessionsForLearnedDataReset
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MetasequoiaWillResetLearnedDataNotification
                                                        object:nil];
}

+ (NSInteger)storedScheme
{
    const NSInteger scheme = [[NSUserDefaults standardUserDefaults] integerForKey:kSchemePreferenceKey];
    return metasequoia::mac::NormalizeStoredInputScheme(static_cast<int>(scheme));
}

+ (void)setStoredScheme:(NSInteger)scheme
{
    const NSInteger normalizedScheme = metasequoia::mac::NormalizeStoredInputScheme(static_cast<int>(scheme));
    [[NSUserDefaults standardUserDefaults] setInteger:normalizedScheme forKey:kSchemePreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaInputSchemeDidChangeNotification"
                                                        object:@(normalizedScheme)];
}

+ (BOOL)storedAutocorrectEnabled
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kAutocorrectPreferenceKey];
    return value == nil ? YES : [value boolValue];
}

+ (void)setAutocorrectEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kAutocorrectPreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaQuanpinAutocorrectDidChangeNotification"
                                                        object:@(enabled)];
}

+ (BOOL)storedHelpcodeEnabled
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kHelpcodePreferenceKey];
    return value == nil ? YES : [value boolValue];
}

+ (void)setHelpcodeEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kHelpcodePreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaHelpcodeDidChangeNotification"
                                                        object:@(enabled)];
}

+ (BOOL)storedChinesePunctuationEnabled
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kChinesePunctuationPreferenceKey];
    return value == nil ? YES : [value boolValue];
}

+ (void)setChinesePunctuationEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kChinesePunctuationPreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaChinesePunctuationDidChangeNotification"
                                                        object:@(enabled)];
}

+ (NSInteger)storedCandidatePanelStyle
{
    const NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kCandidatePanelStylePreferenceKey];
    return static_cast<NSInteger>(metasequoia::mac::NormalizeCandidatePanelStyle(value));
}

+ (void)setCandidatePanelStyle:(NSInteger)style
{
    const NSInteger normalizedStyle =
        static_cast<NSInteger>(metasequoia::mac::NormalizeCandidatePanelStyle(style));
    [[NSUserDefaults standardUserDefaults] setInteger:normalizedStyle forKey:kCandidatePanelStylePreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaCandidatePanelStyleDidChangeNotification"
                                                        object:@(normalizedStyle)];
}

+ (NSInteger)storedCandidatePageSize
{
    const NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kCandidatePageSizePreferenceKey];
    return static_cast<NSInteger>(metasequoia::mac::NormalizeCandidatePageSize(static_cast<size_t>(value)));
}

+ (void)setCandidatePageSize:(NSInteger)pageSize
{
    const NSInteger normalizedPageSize = static_cast<NSInteger>(
        metasequoia::mac::NormalizeCandidatePageSize(static_cast<size_t>(pageSize)));
    [[NSUserDefaults standardUserDefaults] setInteger:normalizedPageSize forKey:kCandidatePageSizePreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaCandidatePageSizeDidChangeNotification"
                                                        object:@(normalizedPageSize)];
}

+ (NSInteger)storedCandidateFontSize
{
    const NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kCandidateFontSizePreferenceKey];
    return static_cast<NSInteger>(metasequoia::mac::NormalizeCandidateFontSize(static_cast<size_t>(value)));
}

+ (void)setCandidateFontSize:(NSInteger)fontSize
{
    const NSInteger normalizedFontSize = static_cast<NSInteger>(
        metasequoia::mac::NormalizeCandidateFontSize(static_cast<size_t>(fontSize)));
    [[NSUserDefaults standardUserDefaults] setInteger:normalizedFontSize forKey:kCandidateFontSizePreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaCandidateFontSizeDidChangeNotification"
                                                        object:@(normalizedFontSize)];
}

+ (BOOL)storedCandidateLearningEnabled
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kCandidateLearningPreferenceKey];
    return value == nil ? YES : [value boolValue];
}

+ (void)setCandidateLearningEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kCandidateLearningPreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaCandidateLearningDidChangeNotification"
                                                        object:@(enabled)];
}

+ (BOOL)storedEnglishInputMode
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kEnglishInputModePreferenceKey];
}

+ (void)setEnglishInputMode:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kEnglishInputModePreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaEnglishInputModeDidChangeNotification"
                                                        object:@(enabled)];
}

+ (BOOL)storedInputModeShortcutEnabled
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kInputModeShortcutPreferenceKey];
    return value == nil ? YES : [value boolValue];
}

+ (void)setInputModeShortcutEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kInputModeShortcutPreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaInputModeShortcutDidChangeNotification"
                                                        object:@(enabled)];
}

- (instancetype)initWithWindowNibName:(NSNibName)windowNibName owner:(id)owner
{
    (void)windowNibName;
    (void)owner;
    return [self init];
}

- (instancetype)initWithWindowNibName:(NSNibName)windowNibName
{
    (void)windowNibName;
    return [self init];
}

- (instancetype)init
{
    NSRect frame = NSMakeRect(0.0, 0.0, kWindowWidth, kWindowHeight);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"水杉输入法设置";
    window.releasedWhenClosed = NO;
    window.restorable = NO;
    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.movableByWindowBackground = YES;

    self = [super initWithWindow:window];
    if (self == nil)
    {
        return nil;
    }
    window.delegate = self;

    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    window.contentView = contentView;

    NSBox *sidebar = [[NSBox alloc] initWithFrame:NSZeroRect];
    sidebar.boxType = NSBoxCustom;
    sidebar.titlePosition = NSNoTitle;
    sidebar.borderWidth = 0.0;
    sidebar.fillColor = MetasequoiaBrandColor();
    sidebar.accessibilityLabel = @"水杉输入法导航";
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;

    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    iconView.image = NSApp.applicationIconImage;
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandTitle = [NSTextField labelWithString:@"水杉输入法"];
    brandTitle.font = [NSFont systemFontOfSize:20.0 weight:NSFontWeightSemibold];
    brandTitle.textColor = [NSColor whiteColor];
    brandTitle.alignment = NSTextAlignmentCenter;
    brandTitle.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandDescription = [NSTextField labelWithString:@"轻巧、专注的中文输入体验"];
    brandDescription.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular];
    brandDescription.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.9];
    brandDescription.alignment = NSTextAlignmentCenter;
    brandDescription.translatesAutoresizingMaskIntoConstraints = NO;

    NSArray<NSString *> *navigationTitles = @[ @"键盘输入", @"外观", @"词库与数据" ];
    NSArray<NSString *> *navigationSymbols = @[ @"keyboard", @"paintpalette", @"books.vertical" ];
    NSMutableArray<NSButton *> *navigationButtons = [NSMutableArray arrayWithCapacity:navigationTitles.count];
    for (NSInteger index = 0; index < static_cast<NSInteger>(navigationTitles.count); ++index)
    {
        NSButton *button = [NSButton buttonWithTitle:navigationTitles[index]
                                              target:self
                                              action:@selector(selectPreferencesPage:)];
        [button setButtonType:NSButtonTypeToggle];
        button.tag = index;
        button.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
        button.attributedTitle =
            [[NSAttributedString alloc] initWithString:navigationTitles[index]
                                            attributes:@{
                                                NSFontAttributeName : button.font,
                                                NSForegroundColorAttributeName : [NSColor whiteColor],
                                            }];
        button.alignment = NSTextAlignmentLeft;
        button.bordered = NO;
        button.contentTintColor = [NSColor whiteColor];
        button.imagePosition = NSImageLeading;
        button.image = [NSImage imageWithSystemSymbolName:navigationSymbols[index]
                                 accessibilityDescription:navigationTitles[index]];
        button.accessibilityLabel = navigationTitles[index];
        button.wantsLayer = YES;
        button.layer.cornerRadius = 8.0;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button.heightAnchor constraintEqualToConstant:38.0].active = YES;
        [navigationButtons addObject:button];
    }
    _navigationButtons = [navigationButtons copy];

    NSStackView *navigationStack = [NSStackView stackViewWithViews:_navigationButtons];
    navigationStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    navigationStack.alignment = NSLayoutAttributeLeading;
    navigationStack.distribution = NSStackViewDistributionFill;
    navigationStack.spacing = 6.0;
    navigationStack.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSButton *button in _navigationButtons)
    {
        [button.widthAnchor constraintEqualToAnchor:navigationStack.widthAnchor].active = YES;
    }

    NSButton *websiteButton = [NSButton buttonWithTitle:@"msime.app" target:self action:@selector(openWebsite:)];
    websiteButton.bordered = NO;
    websiteButton.contentTintColor = [NSColor whiteColor];
    websiteButton.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
    websiteButton.attributedTitle =
        [[NSAttributedString alloc] initWithString:@"msime.app"
                                        attributes:@{
                                            NSFontAttributeName : websiteButton.font,
                                            NSForegroundColorAttributeName : [NSColor whiteColor],
                                        }];
    websiteButton.toolTip = @"打开水杉输入法官网";
    websiteButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandTag = [NSTextField labelWithString:@"METASEQUOIA  ·  macOS"];
    brandTag.font = [NSFont monospacedSystemFontOfSize:9.0 weight:NSFontWeightMedium];
    brandTag.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.8];
    brandTag.alignment = NSTextAlignmentCenter;
    brandTag.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *settingsPanel = [[NSView alloc] initWithFrame:NSZeroRect];
    settingsPanel.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *pageContainer = [[NSView alloc] initWithFrame:NSZeroRect];
    pageContainer.translatesAutoresizingMaskIntoConstraints = NO;

    NSArray<NSString *> *schemeTitles = @[ @"全拼输入", @"小鹤双拼", @"五笔输入（86 五笔）" ];
    NSMutableArray<NSButton *> *schemeButtons = [NSMutableArray arrayWithCapacity:schemeTitles.count];
    NSMutableArray<NSView *> *schemeRows = [NSMutableArray arrayWithCapacity:schemeTitles.count];
    for (NSInteger index = 0; index < static_cast<NSInteger>(schemeTitles.count); ++index)
    {
        NSButton *button = [NSButton radioButtonWithTitle:schemeTitles[index]
                                                  target:self
                                                  action:@selector(schemeChanged:)];
        button.tag = index;
        button.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
        button.accessibilityLabel = schemeTitles[index];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button.heightAnchor constraintEqualToConstant:34.0].active = YES;
        [schemeButtons addObject:button];
        [schemeRows addObject:button];
    }
    _schemeButtons = [schemeButtons copy];

    _autocorrectButton = [NSButton checkboxWithTitle:@"启用全拼自动纠错"
                                              target:self
                                              action:@selector(autocorrectChanged:)];
    _chinesePunctuationButton = [NSButton checkboxWithTitle:@"使用中文标点"
                                                     target:self
                                                     action:@selector(chinesePunctuationChanged:)];
    _inputModeShortcutButton = [NSButton checkboxWithTitle:@"Shift+Space 切换中英文"
                                                    target:self
                                                    action:@selector(inputModeShortcutChanged:)];
    _inputModeShortcutButton.accessibilityLabel = @"Shift+Space 切换中英文";

    NSBox *schemeCard = CardWithViews(schemeRows, 2.0);
    NSBox *behaviorCard =
        CardWithViews(@[ _autocorrectButton, _chinesePunctuationButton, _inputModeShortcutButton ], 9.0);
    schemeCard.accessibilityLabel = @"输入方式卡片";
    behaviorCard.accessibilityLabel = @"中英文状态切换卡片";
    NSView *generalPage =
        PreferencesPage(@"键盘输入", @"选择全拼、双拼或 86 五笔，并调整日常输入行为。",
                        @[ SectionLabel(@"输入方式"), schemeCard, SectionLabel(@"中英文状态切换"), behaviorCard ]);
    generalPage.accessibilityLabel = @"键盘输入设置页";

    _candidatePanelStyleButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_candidatePanelStyleButton addItemsWithTitles:@[ @"横向排列", @"纵向列表" ]];
    _candidatePanelStyleButton.target = self;
    _candidatePanelStyleButton.action = @selector(candidatePanelStyleChanged:);
    _candidatePanelStyleButton.accessibilityLabel = @"候选排列";

    _candidatePageSizeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_candidatePageSizeButton addItemsWithTitles:@[ @"5 个", @"7 个", @"9 个" ]];
    _candidatePageSizeButton.target = self;
    _candidatePageSizeButton.action = @selector(candidatePageSizeChanged:);
    _candidatePageSizeButton.accessibilityLabel = @"每页候选";

    _candidateFontSizeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_candidateFontSizeButton addItemsWithTitles:@[ @"小（16 pt）", @"标准（18 pt）", @"大（20 pt）" ]];
    _candidateFontSizeButton.target = self;
    _candidateFontSizeButton.action = @selector(candidateFontSizeChanged:);
    _candidateFontSizeButton.accessibilityLabel = @"候选字号";

    NSBox *appearanceCard =
        CardWithViews(@[
            PreferenceRow(@"候选排列", _candidatePanelStyleButton),
            PreferenceRow(@"每页候选", _candidatePageSizeButton),
            PreferenceRow(@"候选字号", _candidateFontSizeButton),
        ],
                      4.0);
    appearanceCard.accessibilityLabel = @"候选窗口卡片";
    NSView *appearancePage = PreferencesPage(@"外观", @"调整原生候选窗口的排列、容量与阅读大小。",
                                             @[ SectionLabel(@"候选窗口"), appearanceCard ]);
    appearancePage.accessibilityLabel = @"外观设置页";

    _helpcodeButton = [NSButton checkboxWithTitle:@"启用辅助码" target:self action:@selector(helpcodeChanged:)];
    _candidateLearningButton =
        [NSButton checkboxWithTitle:@"记住候选词频" target:self action:@selector(candidateLearningChanged:)];

    _statusLabel = [NSTextField labelWithString:@"检查词库状态…"];
    _statusLabel.accessibilityLabel = @"词库状态";
    _statusLabel.textColor = [NSColor secondaryLabelColor];
    _statusLabel.maximumNumberOfLines = 2;

    _resetLearningButton = [NSButton buttonWithTitle:@"清除学习数据…"
                                              target:self
                                              action:@selector(confirmResetLearningData:)];
    _resetLearningButton.bezelStyle = NSBezelStyleRounded;
    _resetLearningButton.contentTintColor = [NSColor systemRedColor];
    _resetLearningButton.accessibilityLabel = @"清除学习数据";

    NSBox *learningCard = CardWithViews(@[ _helpcodeButton, _candidateLearningButton ], 9.0);
    NSBox *dictionaryCard = CardWithViews(@[ _statusLabel ], 0.0);
    NSBox *resetCard = CardWithViews(@[ PreferenceRow(@"候选词频、用户词典与拼音学习记录", _resetLearningButton) ], 0.0);
    learningCard.accessibilityLabel = @"候选与学习卡片";
    NSView *dataPage =
        PreferencesPage(@"词库与数据", @"管理候选学习、辅助码与本机词库状态。",
                        @[ SectionLabel(@"候选与学习"), learningCard, SectionLabel(@"词库状态"), dictionaryCard,
                           SectionLabel(@"数据与隐私"), resetCard ]);
    dataPage.accessibilityLabel = @"词库与数据设置页";

    _preferencePages = @[ generalPage, appearancePage, dataPage ];

    NSButton *restoreButton = [NSButton buttonWithTitle:@"恢复默认设置" target:self action:@selector(restoreDefaults:)];
    restoreButton.bezelStyle = NSBezelStyleRounded;
    restoreButton.translatesAutoresizingMaskIntoConstraints = NO;

    _updateButton = [NSButton buttonWithTitle:@"检查更新…"
                                        target:self
                                        action:@selector(checkForUpdates:)];
    _updateButton.bezelStyle = NSBezelStyleInline;
    _updateButton.accessibilityLabel = @"软件更新";
    _updateButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *closeButton = [NSButton buttonWithTitle:@"关闭" target:self action:@selector(close:)];
    closeButton.bezelStyle = NSBezelStyleRounded;
    closeButton.keyEquivalent = @"\r";
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;

    [contentView addSubview:sidebar];
    [sidebar addSubview:iconView];
    [sidebar addSubview:brandTitle];
    [sidebar addSubview:brandDescription];
    [sidebar addSubview:navigationStack];
    [sidebar addSubview:websiteButton];
    [sidebar addSubview:brandTag];
    [contentView addSubview:settingsPanel];
    [settingsPanel addSubview:pageContainer];
    for (NSView *page in _preferencePages)
    {
        [pageContainer addSubview:page];
        [NSLayoutConstraint activateConstraints:@[
            [page.leadingAnchor constraintEqualToAnchor:pageContainer.leadingAnchor],
            [page.trailingAnchor constraintEqualToAnchor:pageContainer.trailingAnchor],
            [page.topAnchor constraintEqualToAnchor:pageContainer.topAnchor],
            [page.bottomAnchor constraintEqualToAnchor:pageContainer.bottomAnchor],
        ]];
    }
    [settingsPanel addSubview:restoreButton];
    [settingsPanel addSubview:_updateButton];
    [settingsPanel addSubview:closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [sidebar.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [sidebar.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:190.0],
        [iconView.topAnchor constraintEqualToAnchor:sidebar.topAnchor constant:44.0],
        [iconView.centerXAnchor constraintEqualToAnchor:sidebar.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:52.0],
        [iconView.heightAnchor constraintEqualToConstant:52.0],
        [brandTitle.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:16.0],
        [brandTitle.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:16.0],
        [brandTitle.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-16.0],
        [brandDescription.topAnchor constraintEqualToAnchor:brandTitle.bottomAnchor constant:8.0],
        [brandDescription.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:16.0],
        [brandDescription.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-16.0],
        [navigationStack.topAnchor constraintEqualToAnchor:brandDescription.bottomAnchor constant:26.0],
        [navigationStack.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:16.0],
        [navigationStack.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-16.0],
        [websiteButton.centerXAnchor constraintEqualToAnchor:sidebar.centerXAnchor],
        [websiteButton.bottomAnchor constraintEqualToAnchor:brandTag.topAnchor constant:-10.0],
        [brandTag.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:12.0],
        [brandTag.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-12.0],
        [brandTag.bottomAnchor constraintEqualToAnchor:sidebar.bottomAnchor constant:-20.0],
        [settingsPanel.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [settingsPanel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [settingsPanel.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [settingsPanel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [pageContainer.leadingAnchor constraintEqualToAnchor:settingsPanel.leadingAnchor],
        [pageContainer.trailingAnchor constraintEqualToAnchor:settingsPanel.trailingAnchor],
        [pageContainer.topAnchor constraintEqualToAnchor:settingsPanel.topAnchor],
        [pageContainer.bottomAnchor constraintEqualToAnchor:restoreButton.topAnchor constant:-16.0],
        [restoreButton.leadingAnchor constraintEqualToAnchor:settingsPanel.leadingAnchor constant:30.0],
        [restoreButton.bottomAnchor constraintEqualToAnchor:settingsPanel.bottomAnchor constant:-20.0],
        [_updateButton.centerXAnchor constraintEqualToAnchor:settingsPanel.centerXAnchor],
        [_updateButton.centerYAnchor constraintEqualToAnchor:restoreButton.centerYAnchor],
        [closeButton.trailingAnchor constraintEqualToAnchor:settingsPanel.trailingAnchor constant:-30.0],
        [closeButton.centerYAnchor constraintEqualToAnchor:restoreButton.centerYAnchor],
        [closeButton.widthAnchor constraintGreaterThanOrEqualToConstant:80.0],
    ]];
    [self selectPreferencesPage:_navigationButtons.firstObject];
    [self refreshUpdateButton];
    return self;
}

- (void)refreshUpdateButton
{
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    _updateButton.title = version.length == 0 ? @"检查更新…" : [NSString stringWithFormat:@"检查更新（v%@）…", version];
    _updateButton.toolTip = @"通过 msime.app 检查水杉输入法的最新正式版本";
    _updateButton.accessibilityHelp = version.length == 0
                                          ? @"通过 msime.app 检查最新正式版本"
                                          : [NSString stringWithFormat:@"当前版本 v%@，通过 msime.app 检查最新正式版本", version];
    _updateButton.contentTintColor = nil;
    _updateButton.enabled = YES;
}

- (void)checkForUpdates:(id)sender
{
    [[MetasequoiaUpdateController sharedController] checkForUpdates:sender];
}

- (void)selectPreferencesPage:(id)sender
{
    NSButton *selectedButton = [sender isKindOfClass:[NSButton class]] ? (NSButton *)sender : nil;
    const NSInteger selectedIndex = selectedButton == nil ? 0 : selectedButton.tag;
    for (NSInteger index = 0; index < static_cast<NSInteger>(_preferencePages.count); ++index)
    {
        const BOOL selected = index == selectedIndex;
        _preferencePages[index].hidden = !selected;
        NSButton *button = _navigationButtons[index];
        button.state = selected ? NSControlStateValueOn : NSControlStateValueOff;
        button.accessibilityValue = @(selected);
        NSColor *backgroundColor =
            selected ? [[NSColor whiteColor] colorWithAlphaComponent:0.16] : [NSColor clearColor];
        button.layer.backgroundColor = backgroundColor.CGColor;
    }
}

- (void)openWebsite:(id)sender
{
    (void)sender;
    NSURL *website = [NSURL URLWithString:@"https://msime.app/"];
    if (website != nil)
    {
        [[NSWorkspace sharedWorkspace] openURL:website];
    }
}

- (void)refreshControls
{
    const NSInteger storedScheme = [MetasequoiaPreferencesWindowController storedScheme];
    for (NSInteger index = 0; index < static_cast<NSInteger>(_schemeButtons.count); ++index)
    {
        _schemeButtons[index].state = index == storedScheme ? NSControlStateValueOn : NSControlStateValueOff;
    }
    _autocorrectButton.state = [MetasequoiaPreferencesWindowController storedAutocorrectEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    _helpcodeButton.state = [MetasequoiaPreferencesWindowController storedHelpcodeEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    _chinesePunctuationButton.state = [MetasequoiaPreferencesWindowController storedChinesePunctuationEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [_candidatePanelStyleButton selectItemAtIndex:[MetasequoiaPreferencesWindowController storedCandidatePanelStyle]];
    [_candidatePageSizeButton selectItemAtIndex:static_cast<NSInteger>(metasequoia::mac::CandidatePageSizeOptionIndex(
                                                        static_cast<size_t>([MetasequoiaPreferencesWindowController storedCandidatePageSize])))];
    [_candidateFontSizeButton selectItemAtIndex:static_cast<NSInteger>(metasequoia::mac::CandidateFontSizeOptionIndex(
                                                        static_cast<size_t>([MetasequoiaPreferencesWindowController storedCandidateFontSize])))];
    _candidateLearningButton.state = [MetasequoiaPreferencesWindowController storedCandidateLearningEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    _inputModeShortcutButton.state = [MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)refreshDictionaryStatus
{
    NSError *error = nil;
    if (EnsureMetasequoiaDictionary(&error))
    {
        _statusLabel.stringValue = @"词库已就绪；设置将在当前输入结束后的下一次按键生效。";
        _statusLabel.textColor = [NSColor secondaryLabelColor];
        _statusLabel.toolTip = nil;
        return;
    }

    _statusLabel.stringValue = @"词库不可用，请重新安装水杉输入法。";
    _statusLabel.textColor = [NSColor systemRedColor];
    _statusLabel.toolTip = error.localizedDescription;
}

- (void)presentAndActivate
{
    [self refreshControls];
    [self refreshDictionaryStatus];
    [self refreshUpdateButton];
    if (_standaloneLaunch)
    {
        _resetLearningButton.enabled = NO;
        _resetLearningButton.toolTip = @"请从水杉输入菜单打开设置后再清除学习数据。";
        _resetLearningButton.accessibilityHelp = @"独立设置不能安全清除学习数据；请从水杉输入菜单打开设置。";
    }
    else
    {
        _resetLearningButton.enabled = YES;
        _resetLearningButton.toolTip = nil;
        _resetLearningButton.accessibilityHelp = nil;
    }
    [self showWindow:nil];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showAndActivate
{
    _standaloneLaunch = NO;
    [self presentAndActivate];
}

- (void)showAndActivateForStandaloneLaunch
{
    _standaloneLaunch = YES;
    [self presentAndActivate];
}

- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    if (_standaloneLaunch)
    {
        _standaloneLaunch = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:MetasequoiaStandalonePreferencesDidCloseNotification
                              object:self];
        });
    }
}

- (void)autocorrectChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setAutocorrectEnabled:button.state == NSControlStateValueOn];
}

- (void)helpcodeChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setHelpcodeEnabled:button.state == NSControlStateValueOn];
}

- (void)chinesePunctuationChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setChinesePunctuationEnabled:button.state == NSControlStateValueOn];
}

- (void)schemeChanged:(id)sender
{
    NSButton *schemeButton = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setStoredScheme:schemeButton.tag];
}

- (void)candidatePanelStyleChanged:(id)sender
{
    NSPopUpButton *styleButton = (NSPopUpButton *)sender;
    [MetasequoiaPreferencesWindowController setCandidatePanelStyle:styleButton.indexOfSelectedItem];
}

- (void)candidatePageSizeChanged:(id)sender
{
    NSPopUpButton *pageSizeButton = (NSPopUpButton *)sender;
    const size_t pageSize =
        metasequoia::mac::CandidatePageSizeForOptionIndex(static_cast<size_t>(pageSizeButton.indexOfSelectedItem));
    [MetasequoiaPreferencesWindowController setCandidatePageSize:static_cast<NSInteger>(pageSize)];
}

- (void)candidateFontSizeChanged:(id)sender
{
    NSPopUpButton *fontSizeButton = (NSPopUpButton *)sender;
    const size_t fontSize =
        metasequoia::mac::CandidateFontSizeForOptionIndex(static_cast<size_t>(fontSizeButton.indexOfSelectedItem));
    [MetasequoiaPreferencesWindowController setCandidateFontSize:static_cast<NSInteger>(fontSize)];
}

- (void)candidateLearningChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setCandidateLearningEnabled:button.state == NSControlStateValueOn];
}

- (void)inputModeShortcutChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setInputModeShortcutEnabled:button.state == NSControlStateValueOn];
}

- (void)confirmResetLearningData:(id)sender
{
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"清除所有学习数据？";
    alert.informativeText = @"候选词频、用户词典和拼音学习记录将永久删除。此操作无法撤销，输入方案等设置不会改变。";
    [alert addButtonWithTitle:@"取消"];
    [alert addButtonWithTitle:@"清除"];
    alert.buttons[0].keyEquivalent = @"\r";
    alert.buttons[1].keyEquivalent = @"";
    alert.buttons[1].hasDestructiveAction = YES;
    alert.buttons[1].accessibilityLabel = @"确认清除学习数据";
    alert.window.defaultButtonCell = (NSButtonCell *)alert.buttons[0].cell;

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSAlertSecondButtonReturn)
        {
            return;
        }

        self->_resetLearningButton.enabled = NO;
        self->_statusLabel.stringValue = @"正在清除学习数据…";
        self->_statusLabel.textColor = [NSColor secondaryLabelColor];
        self->_statusLabel.toolTip = nil;
        [MetasequoiaPreferencesWindowController prepareInputSessionsForLearnedDataReset];

        NSError *error = nil;
        if (ResetMetasequoiaLearnedDataForCurrentUser(&error))
        {
            self->_statusLabel.stringValue = @"学习数据已清除；新的输入将从默认词频开始。";
            self->_statusLabel.textColor = [NSColor systemGreenColor];
            self->_statusLabel.toolTip = nil;
        }
        else
        {
            self->_statusLabel.stringValue = @"学习数据未能清除，请稍后重试。";
            self->_statusLabel.textColor = [NSColor systemRedColor];
            self->_statusLabel.toolTip = error.localizedDescription;
        }
        self->_resetLearningButton.enabled = YES;
    }];
}

- (void)restoreDefaults:(id)sender
{
    (void)sender;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in @[
             kSchemePreferenceKey,
             kAutocorrectPreferenceKey,
             kHelpcodePreferenceKey,
             kChinesePunctuationPreferenceKey,
             kCandidatePanelStylePreferenceKey,
             kCandidatePageSizePreferenceKey,
             kCandidateFontSizePreferenceKey,
             kCandidateLearningPreferenceKey,
             kInputModeShortcutPreferenceKey,
         ])
    {
        [defaults removeObjectForKey:key];
    }

    NSNotificationCenter *notifications = [NSNotificationCenter defaultCenter];
    [notifications postNotificationName:@"MetasequoiaInputSchemeDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedScheme])];
    [notifications postNotificationName:@"MetasequoiaQuanpinAutocorrectDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedAutocorrectEnabled])];
    [notifications postNotificationName:@"MetasequoiaHelpcodeDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedHelpcodeEnabled])];
    [notifications postNotificationName:@"MetasequoiaChinesePunctuationDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedChinesePunctuationEnabled])];
    [notifications postNotificationName:@"MetasequoiaCandidatePanelStyleDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedCandidatePanelStyle])];
    [notifications postNotificationName:@"MetasequoiaCandidatePageSizeDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedCandidatePageSize])];
    [notifications postNotificationName:@"MetasequoiaCandidateFontSizeDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedCandidateFontSize])];
    [notifications postNotificationName:@"MetasequoiaCandidateLearningDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedCandidateLearningEnabled])];
    [notifications postNotificationName:@"MetasequoiaInputModeShortcutDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled])];
    [self refreshControls];
}

- (void)close:(id)sender
{
    [self.window performClose:sender];
}

@end
