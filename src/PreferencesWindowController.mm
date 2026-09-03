#import "PreferencesWindowController.h"

#include "CandidateFontSize.h"
#include "CandidatePageSize.h"
#include "CandidatePanelStyle.h"
#import "DictionaryInstaller.h"

NSNotificationName const MetasequoiaWillResetLearnedDataNotification =
    @"MetasequoiaWillResetLearnedDataNotification";

namespace
{
constexpr CGFloat kWindowWidth = 600.0;
constexpr CGFloat kWindowHeight = 720.0;
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
} // namespace

@implementation MetasequoiaPreferencesWindowController
{
    NSPopUpButton *_schemeButton;
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
    return scheme == 1 ? scheme : 0;
}

+ (void)setStoredScheme:(NSInteger)scheme
{
    const NSInteger normalizedScheme = scheme == 1 ? scheme : 0;
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

    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    window.contentView = contentView;

    NSBox *brandPanel = [[NSBox alloc] initWithFrame:NSZeroRect];
    brandPanel.boxType = NSBoxCustom;
    brandPanel.titlePosition = NSNoTitle;
    brandPanel.borderWidth = 0.0;
    brandPanel.fillColor = MetasequoiaBrandColor();
    brandPanel.accessibilityLabel = @"水杉输入法品牌";
    brandPanel.translatesAutoresizingMaskIntoConstraints = NO;

    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    iconView.image = NSApp.applicationIconImage;
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandTitle = [NSTextField labelWithString:@"水杉输入法"];
    brandTitle.font = [NSFont systemFontOfSize:23.0 weight:NSFontWeightSemibold];
    brandTitle.textColor = [NSColor whiteColor];
    brandTitle.alignment = NSTextAlignmentCenter;
    brandTitle.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandDescription = [NSTextField labelWithString:@"轻巧、专注的中文输入体验"];
    brandDescription.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular];
    brandDescription.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.95];
    brandDescription.alignment = NSTextAlignmentCenter;
    brandDescription.maximumNumberOfLines = 2;
    brandDescription.lineBreakMode = NSLineBreakByWordWrapping;
    brandDescription.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandTag = [NSTextField labelWithString:@"METASEQUOIA  ·  macOS"];
    brandTag.font = [NSFont monospacedSystemFontOfSize:9.0 weight:NSFontWeightMedium];
    brandTag.textColor = [NSColor whiteColor];
    brandTag.alignment = NSTextAlignmentCenter;
    brandTag.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *settingsPanel = [[NSView alloc] initWithFrame:NSZeroRect];
    settingsPanel.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *titleLabel = [NSTextField labelWithString:@"输入设置"];
    titleLabel.font = [NSFont systemFontOfSize:24.0 weight:NSFontWeightSemibold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *descriptionLabel = [NSTextField labelWithString:@"选择输入方案，并调整候选与标点行为。"];
    descriptionLabel.textColor = [NSColor secondaryLabelColor];
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *inputSectionLabel = [NSTextField labelWithString:@"输入方案"];
    inputSectionLabel.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
    inputSectionLabel.textColor = [NSColor secondaryLabelColor];
    inputSectionLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSBox *inputCard = [[NSBox alloc] initWithFrame:NSZeroRect];
    ConfigureCard(inputCard);

    NSTextField *schemeLabel = [NSTextField labelWithString:@"拼音方案"];
    schemeLabel.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    schemeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _schemeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_schemeButton addItemWithTitle:@"全拼"];
    [_schemeButton addItemWithTitle:@"小鹤双拼"];
    _schemeButton.target = self;
    _schemeButton.action = @selector(schemeChanged:);
    _schemeButton.accessibilityLabel = @"输入方案";
    _schemeButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *candidatePanelStyleLabel = [NSTextField labelWithString:@"候选排列"];
    candidatePanelStyleLabel.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    candidatePanelStyleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _candidatePanelStyleButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_candidatePanelStyleButton addItemWithTitle:@"横向排列"];
    [_candidatePanelStyleButton addItemWithTitle:@"纵向列表"];
    _candidatePanelStyleButton.target = self;
    _candidatePanelStyleButton.action = @selector(candidatePanelStyleChanged:);
    _candidatePanelStyleButton.accessibilityLabel = @"候选排列";
    _candidatePanelStyleButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *candidatePageSizeLabel = [NSTextField labelWithString:@"每页候选"];
    candidatePageSizeLabel.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    candidatePageSizeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _candidatePageSizeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_candidatePageSizeButton addItemsWithTitles:@[@"5 个", @"7 个", @"9 个"]];
    _candidatePageSizeButton.target = self;
    _candidatePageSizeButton.action = @selector(candidatePageSizeChanged:);
    _candidatePageSizeButton.accessibilityLabel = @"每页候选";
    _candidatePageSizeButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *candidateFontSizeLabel = [NSTextField labelWithString:@"候选字号"];
    candidateFontSizeLabel.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    candidateFontSizeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _candidateFontSizeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_candidateFontSizeButton addItemsWithTitles:@[@"小（16 pt）", @"标准（18 pt）", @"大（20 pt）"]];
    _candidateFontSizeButton.target = self;
    _candidateFontSizeButton.action = @selector(candidateFontSizeChanged:);
    _candidateFontSizeButton.accessibilityLabel = @"候选字号";
    _candidateFontSizeButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *behaviorSectionLabel = [NSTextField labelWithString:@"输入行为"];
    behaviorSectionLabel.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
    behaviorSectionLabel.textColor = [NSColor secondaryLabelColor];
    behaviorSectionLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSBox *behaviorCard = [[NSBox alloc] initWithFrame:NSZeroRect];
    ConfigureCard(behaviorCard);

    _autocorrectButton = [NSButton checkboxWithTitle:@"启用全拼自动纠错" target:self action:@selector(autocorrectChanged:)];
    _autocorrectButton.translatesAutoresizingMaskIntoConstraints = NO;

    _helpcodeButton = [NSButton checkboxWithTitle:@"启用辅助码" target:self action:@selector(helpcodeChanged:)];
    _helpcodeButton.translatesAutoresizingMaskIntoConstraints = NO;

    _chinesePunctuationButton = [NSButton checkboxWithTitle:@"使用中文标点" target:self action:@selector(chinesePunctuationChanged:)];
    _chinesePunctuationButton.translatesAutoresizingMaskIntoConstraints = NO;

    _candidateLearningButton = [NSButton checkboxWithTitle:@"记住候选词频" target:self action:@selector(candidateLearningChanged:)];
    _candidateLearningButton.translatesAutoresizingMaskIntoConstraints = NO;

    _inputModeShortcutButton = [NSButton checkboxWithTitle:@"Shift+Space 切换中英文"
                                                    target:self
                                                    action:@selector(inputModeShortcutChanged:)];
    _inputModeShortcutButton.accessibilityLabel = @"Shift+Space 切换中英文";
    _inputModeShortcutButton.translatesAutoresizingMaskIntoConstraints = NO;

    _statusLabel = [NSTextField labelWithString:@"检查词库状态…"];
    _statusLabel.accessibilityLabel = @"词库状态";
    _statusLabel.textColor = [NSColor secondaryLabelColor];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *dataSectionLabel = [NSTextField labelWithString:@"数据与隐私"];
    dataSectionLabel.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold];
    dataSectionLabel.textColor = [NSColor secondaryLabelColor];
    dataSectionLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSBox *dataCard = [[NSBox alloc] initWithFrame:NSZeroRect];
    ConfigureCard(dataCard);

    NSTextField *learningDataLabel = [NSTextField labelWithString:@"学习数据"];
    learningDataLabel.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    learningDataLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *learningDataDescription =
        [NSTextField labelWithString:@"清除候选词频、用户词典与拼音学习记录。"];
    learningDataDescription.font = [NSFont systemFontOfSize:11.0];
    learningDataDescription.textColor = [NSColor secondaryLabelColor];
    learningDataDescription.translatesAutoresizingMaskIntoConstraints = NO;

    _resetLearningButton = [NSButton buttonWithTitle:@"清除学习数据…"
                                              target:self
                                              action:@selector(confirmResetLearningData:)];
    _resetLearningButton.bezelStyle = NSBezelStyleRounded;
    _resetLearningButton.contentTintColor = [NSColor systemRedColor];
    _resetLearningButton.accessibilityLabel = @"清除学习数据";
    _resetLearningButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *restoreButton = [NSButton buttonWithTitle:@"恢复默认设置" target:self action:@selector(restoreDefaults:)];
    restoreButton.bezelStyle = NSBezelStyleRounded;
    restoreButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *versionText = version.length == 0 ? @"开发版本" : [@"版本 " stringByAppendingString:version];
    NSTextField *versionLabel = [NSTextField labelWithString:versionText];
    versionLabel.font = [NSFont systemFontOfSize:11.0];
    versionLabel.textColor = [NSColor tertiaryLabelColor];
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *closeButton = [NSButton buttonWithTitle:@"关闭" target:self action:@selector(close:)];
    closeButton.bezelStyle = NSBezelStyleRounded;
    closeButton.keyEquivalent = @"\r";
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;

    [contentView addSubview:brandPanel];
    [brandPanel addSubview:iconView];
    [brandPanel addSubview:brandTitle];
    [brandPanel addSubview:brandDescription];
    [brandPanel addSubview:brandTag];
    [contentView addSubview:settingsPanel];
    [settingsPanel addSubview:titleLabel];
    [settingsPanel addSubview:descriptionLabel];
    [settingsPanel addSubview:inputSectionLabel];
    [settingsPanel addSubview:inputCard];
    [inputCard addSubview:schemeLabel];
    [inputCard addSubview:_schemeButton];
    [inputCard addSubview:candidatePanelStyleLabel];
    [inputCard addSubview:_candidatePanelStyleButton];
    [inputCard addSubview:candidatePageSizeLabel];
    [inputCard addSubview:_candidatePageSizeButton];
    [inputCard addSubview:candidateFontSizeLabel];
    [inputCard addSubview:_candidateFontSizeButton];
    [settingsPanel addSubview:behaviorSectionLabel];
    [settingsPanel addSubview:behaviorCard];
    [behaviorCard addSubview:_autocorrectButton];
    [behaviorCard addSubview:_helpcodeButton];
    [behaviorCard addSubview:_chinesePunctuationButton];
    [behaviorCard addSubview:_inputModeShortcutButton];
    [behaviorCard addSubview:_candidateLearningButton];
    [settingsPanel addSubview:_statusLabel];
    [settingsPanel addSubview:dataSectionLabel];
    [settingsPanel addSubview:dataCard];
    [dataCard addSubview:learningDataLabel];
    [dataCard addSubview:learningDataDescription];
    [dataCard addSubview:_resetLearningButton];
    [settingsPanel addSubview:restoreButton];
    [settingsPanel addSubview:versionLabel];
    [settingsPanel addSubview:closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [brandPanel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [brandPanel.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [brandPanel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [brandPanel.widthAnchor constraintEqualToConstant:176.0],
        [iconView.topAnchor constraintEqualToAnchor:brandPanel.topAnchor constant:48.0],
        [iconView.centerXAnchor constraintEqualToAnchor:brandPanel.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:64.0],
        [iconView.heightAnchor constraintEqualToConstant:64.0],
        [brandTitle.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:20.0],
        [brandTitle.leadingAnchor constraintEqualToAnchor:brandPanel.leadingAnchor constant:16.0],
        [brandTitle.trailingAnchor constraintEqualToAnchor:brandPanel.trailingAnchor constant:-16.0],
        [brandDescription.topAnchor constraintEqualToAnchor:brandTitle.bottomAnchor constant:10.0],
        [brandDescription.leadingAnchor constraintEqualToAnchor:brandPanel.leadingAnchor constant:22.0],
        [brandDescription.trailingAnchor constraintEqualToAnchor:brandPanel.trailingAnchor constant:-22.0],
        [brandTag.leadingAnchor constraintEqualToAnchor:brandPanel.leadingAnchor constant:12.0],
        [brandTag.trailingAnchor constraintEqualToAnchor:brandPanel.trailingAnchor constant:-12.0],
        [brandTag.bottomAnchor constraintEqualToAnchor:brandPanel.bottomAnchor constant:-28.0],
        [settingsPanel.leadingAnchor constraintEqualToAnchor:brandPanel.trailingAnchor],
        [settingsPanel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [settingsPanel.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [settingsPanel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:settingsPanel.topAnchor constant:28.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:settingsPanel.leadingAnchor constant:28.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:settingsPanel.trailingAnchor constant:-28.0],
        [descriptionLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [descriptionLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [descriptionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:settingsPanel.trailingAnchor constant:-28.0],
        [inputSectionLabel.topAnchor constraintEqualToAnchor:descriptionLabel.bottomAnchor constant:24.0],
        [inputSectionLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [inputCard.topAnchor constraintEqualToAnchor:inputSectionLabel.bottomAnchor constant:8.0],
        [inputCard.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [inputCard.trailingAnchor constraintEqualToAnchor:settingsPanel.trailingAnchor constant:-28.0],
        [inputCard.heightAnchor constraintEqualToConstant:196.0],
        [schemeLabel.leadingAnchor constraintEqualToAnchor:inputCard.leadingAnchor constant:18.0],
        [schemeLabel.topAnchor constraintEqualToAnchor:inputCard.topAnchor constant:18.0],
        [_schemeButton.centerYAnchor constraintEqualToAnchor:schemeLabel.centerYAnchor],
        [_schemeButton.trailingAnchor constraintEqualToAnchor:inputCard.trailingAnchor constant:-16.0],
        [_schemeButton.widthAnchor constraintEqualToConstant:180.0],
        [candidatePanelStyleLabel.leadingAnchor constraintEqualToAnchor:schemeLabel.leadingAnchor],
        [candidatePanelStyleLabel.topAnchor constraintEqualToAnchor:schemeLabel.topAnchor constant:48.0],
        [_candidatePanelStyleButton.centerYAnchor constraintEqualToAnchor:candidatePanelStyleLabel.centerYAnchor],
        [_candidatePanelStyleButton.trailingAnchor constraintEqualToAnchor:_schemeButton.trailingAnchor],
        [_candidatePanelStyleButton.widthAnchor constraintEqualToAnchor:_schemeButton.widthAnchor],
        [candidatePageSizeLabel.leadingAnchor constraintEqualToAnchor:schemeLabel.leadingAnchor],
        [candidatePageSizeLabel.topAnchor constraintEqualToAnchor:candidatePanelStyleLabel.topAnchor constant:48.0],
        [_candidatePageSizeButton.centerYAnchor constraintEqualToAnchor:candidatePageSizeLabel.centerYAnchor],
        [_candidatePageSizeButton.trailingAnchor constraintEqualToAnchor:_schemeButton.trailingAnchor],
        [_candidatePageSizeButton.widthAnchor constraintEqualToAnchor:_schemeButton.widthAnchor],
        [candidateFontSizeLabel.leadingAnchor constraintEqualToAnchor:schemeLabel.leadingAnchor],
        [candidateFontSizeLabel.topAnchor constraintEqualToAnchor:candidatePageSizeLabel.topAnchor constant:48.0],
        [_candidateFontSizeButton.centerYAnchor constraintEqualToAnchor:candidateFontSizeLabel.centerYAnchor],
        [_candidateFontSizeButton.trailingAnchor constraintEqualToAnchor:_schemeButton.trailingAnchor],
        [_candidateFontSizeButton.widthAnchor constraintEqualToAnchor:_schemeButton.widthAnchor],
        [behaviorSectionLabel.topAnchor constraintEqualToAnchor:inputCard.bottomAnchor constant:18.0],
        [behaviorSectionLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [behaviorCard.topAnchor constraintEqualToAnchor:behaviorSectionLabel.bottomAnchor constant:8.0],
        [behaviorCard.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [behaviorCard.trailingAnchor constraintEqualToAnchor:settingsPanel.trailingAnchor constant:-28.0],
        [behaviorCard.heightAnchor constraintEqualToConstant:148.0],
        [_autocorrectButton.leadingAnchor constraintEqualToAnchor:behaviorCard.leadingAnchor constant:18.0],
        [_autocorrectButton.topAnchor constraintEqualToAnchor:behaviorCard.topAnchor constant:16.0],
        [_helpcodeButton.leadingAnchor constraintEqualToAnchor:_autocorrectButton.leadingAnchor],
        [_helpcodeButton.topAnchor constraintEqualToAnchor:_autocorrectButton.bottomAnchor constant:8.0],
        [_chinesePunctuationButton.leadingAnchor constraintEqualToAnchor:_autocorrectButton.leadingAnchor],
        [_chinesePunctuationButton.topAnchor constraintEqualToAnchor:_helpcodeButton.bottomAnchor constant:8.0],
        [_inputModeShortcutButton.leadingAnchor constraintEqualToAnchor:_autocorrectButton.leadingAnchor],
        [_inputModeShortcutButton.topAnchor constraintEqualToAnchor:_chinesePunctuationButton.bottomAnchor constant:8.0],
        [_candidateLearningButton.leadingAnchor constraintEqualToAnchor:_autocorrectButton.leadingAnchor],
        [_candidateLearningButton.topAnchor constraintEqualToAnchor:_inputModeShortcutButton.bottomAnchor constant:8.0],
        [_statusLabel.topAnchor constraintEqualToAnchor:behaviorCard.bottomAnchor constant:12.0],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [_statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:settingsPanel.trailingAnchor constant:-28.0],
        [dataSectionLabel.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:16.0],
        [dataSectionLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [dataCard.topAnchor constraintEqualToAnchor:dataSectionLabel.bottomAnchor constant:8.0],
        [dataCard.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [dataCard.trailingAnchor constraintEqualToAnchor:settingsPanel.trailingAnchor constant:-28.0],
        [dataCard.heightAnchor constraintEqualToConstant:72.0],
        [learningDataLabel.leadingAnchor constraintEqualToAnchor:dataCard.leadingAnchor constant:18.0],
        [learningDataLabel.topAnchor constraintEqualToAnchor:dataCard.topAnchor constant:15.0],
        [learningDataLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_resetLearningButton.leadingAnchor
                                                                   constant:-12.0],
        [learningDataDescription.leadingAnchor constraintEqualToAnchor:learningDataLabel.leadingAnchor],
        [learningDataDescription.topAnchor constraintEqualToAnchor:learningDataLabel.bottomAnchor constant:5.0],
        [learningDataDescription.trailingAnchor constraintLessThanOrEqualToAnchor:_resetLearningButton.leadingAnchor
                                                                         constant:-12.0],
        [_resetLearningButton.trailingAnchor constraintEqualToAnchor:dataCard.trailingAnchor constant:-16.0],
        [_resetLearningButton.centerYAnchor constraintEqualToAnchor:dataCard.centerYAnchor],
        [_resetLearningButton.widthAnchor constraintGreaterThanOrEqualToConstant:118.0],
        [restoreButton.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [restoreButton.bottomAnchor constraintEqualToAnchor:settingsPanel.bottomAnchor constant:-20.0],
        [versionLabel.centerXAnchor constraintEqualToAnchor:settingsPanel.centerXAnchor],
        [versionLabel.centerYAnchor constraintEqualToAnchor:restoreButton.centerYAnchor],
        [closeButton.trailingAnchor constraintEqualToAnchor:settingsPanel.trailingAnchor constant:-28.0],
        [closeButton.bottomAnchor constraintEqualToAnchor:settingsPanel.bottomAnchor constant:-20.0],
        [closeButton.widthAnchor constraintGreaterThanOrEqualToConstant:80.0],
    ]];
    return self;
}

- (void)refreshControls
{
    [_schemeButton selectItemAtIndex:[MetasequoiaPreferencesWindowController storedScheme]];
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

- (void)showAndActivate
{
    [self refreshControls];
    [self refreshDictionaryStatus];
    [self showWindow:nil];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
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
    NSPopUpButton *schemeButton = (NSPopUpButton *)sender;
    [MetasequoiaPreferencesWindowController setStoredScheme:schemeButton.indexOfSelectedItem];
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
    (void)sender;
    [self.window orderOut:nil];
}

@end
