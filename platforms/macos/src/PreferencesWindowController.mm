#import "PreferencesWindowController.h"

#include "CandidateFontSize.h"
#include "CandidatePageSize.h"
#include "CandidatePanelStyle.h"
#include "InputControllerKeyRouting.h"
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
constexpr CGFloat kWindowHeight = 660.0;
NSString * const kSchemePreferenceKey = @"MetasequoiaImeInputScheme";
NSString * const kAutocorrectPreferenceKey = @"MetasequoiaImeQuanpinAutocorrect";
NSString * const kHelpcodePreferenceKey = @"MetasequoiaImeHelpcodeEnabled";
NSString * const kChinesePunctuationPreferenceKey = @"MetasequoiaImeChinesePunctuation";
NSString * const kCandidatePanelStylePreferenceKey = @"MetasequoiaImeCandidatePanelStyle";
NSString * const kCandidatePageSizePreferenceKey = @"MetasequoiaImeCandidatePageSize";
NSString * const kCandidateFontSizePreferenceKey = @"MetasequoiaImeCandidateFontSize";
NSString * const kCandidatePageShortcutPreferenceKey = @"MetasequoiaImeCandidatePageShortcut";
NSString * const kCandidateLearningPreferenceKey = @"MetasequoiaImeCandidateLearning";
NSString * const kEnglishInputModePreferenceKey = @"MetasequoiaImeEnglishInputMode";
NSString * const kInputModeShortcutPreferenceKey = @"MetasequoiaImeInputModeShortcutEnabled";
NSString * const kFullWidthInputPreferenceKey = @"MetasequoiaImeFullWidthInputEnabled";
NSString * const kWubiAutoCommitUniquePreferenceKey = @"MetasequoiaImeWubiAutoCommitUnique";

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

NSColor *MetasequoiaSidebarColor()
{
    return [NSColor colorWithName:@"MetasequoiaSidebarColor" dynamicProvider:^NSColor *(NSAppearance *appearance) {
        NSString *match = [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
        if ([match isEqualToString:NSAppearanceNameDarkAqua])
        {
            return [NSColor colorWithSRGBRed:0.12 green:0.18 blue:0.20 alpha:1.0];
        }
        return [NSColor colorWithSRGBRed:0.88 green:0.92 blue:0.95 alpha:1.0];
    }];
}

NSColor *MetasequoiaSidebarPrimaryTextColor()
{
    return [NSColor labelColor];
}

NSColor *MetasequoiaSidebarSecondaryTextColor()
{
    return [NSColor secondaryLabelColor];
}

NSColor *MetasequoiaSidebarSelectionColor()
{
    return [NSColor colorWithName:@"MetasequoiaSidebarSelectionColor"
                  dynamicProvider:^NSColor *(NSAppearance *appearance) {
        NSString *match = [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
        if ([match isEqualToString:NSAppearanceNameDarkAqua])
        {
            return [[NSColor whiteColor] colorWithAlphaComponent:0.16];
        }
        return [[NSColor whiteColor] colorWithAlphaComponent:0.92];
    }];
}

NSColor *CandidatePreviewPanelColor()
{
    return [NSColor colorWithName:@"MetasequoiaCandidatePreviewPanelColor"
                  dynamicProvider:^NSColor *(NSAppearance *appearance) {
        NSString *match =
            [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
        if ([match isEqualToString:NSAppearanceNameDarkAqua])
        {
            return [NSColor colorWithSRGBRed:0.16 green:0.18 blue:0.18 alpha:1.0];
        }
        return [NSColor whiteColor];
    }];
}

NSColor *CandidatePreviewAccentColor()
{
    return [NSColor colorWithName:@"MetasequoiaCandidatePreviewAccentColor"
                  dynamicProvider:^NSColor *(NSAppearance *appearance) {
        NSString *match =
            [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
        if ([match isEqualToString:NSAppearanceNameDarkAqua])
        {
            return [NSColor colorWithSRGBRed:0.35 green:0.85 blue:0.78 alpha:1.0];
        }
        return MetasequoiaBrandColor();
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

NSView *CardHeader(NSString *title)
{
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    NSTextField *label = [NSTextField labelWithString:title];
    label.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold];
    label.textColor = [NSColor labelColor];
    label.accessibilityLabel = [title stringByAppendingString:@"标题"];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:34.0],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

NSBox *CardSeparator()
{
    NSBox *separator = [[NSBox alloc] initWithFrame:NSZeroRect];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [separator.heightAnchor constraintEqualToConstant:1.0].active = YES;
    return separator;
}

NSView *SchemeChoiceRow(NSButton *choice, NSView *accessory)
{
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    choice.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:choice];
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [row.heightAnchor constraintEqualToConstant:44.0],
        [choice.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [choice.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    if (accessory == nil)
    {
        [constraints addObject:[choice.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor]];
    }
    else
    {
        accessory.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:accessory];
        [constraints addObjectsFromArray:@[
            [choice.trailingAnchor constraintLessThanOrEqualToAnchor:accessory.leadingAnchor constant:-12.0],
            [accessory.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [accessory.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [accessory.widthAnchor constraintEqualToConstant:150.0],
        ]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
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
    for (NSView *view in views)
    {
        [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }
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

@interface MetasequoiaCandidatePreviewView : NSView
- (void)updatePanelStyle:(NSInteger)panelStyle pageSize:(NSInteger)pageSize fontSize:(NSInteger)fontSize;
- (NSColor *)previewPanelFillColor;
- (NSColor *)previewAccentColor;
@end

@implementation MetasequoiaCandidatePreviewView
{
    NSInteger _panelStyle;
    NSInteger _pageSize;
    CGFloat _candidateFontSize;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self != nil)
    {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.accessibilityLabel = @"候选窗口预览";
        self.accessibilityRole = NSAccessibilityGroupRole;
        [self.heightAnchor constraintEqualToConstant:190.0].active = YES;
        [self updatePanelStyle:0 pageSize:9 fontSize:18];
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (NSColor *)previewPanelFillColor
{
    return CandidatePreviewPanelColor();
}

- (NSColor *)previewAccentColor
{
    return CandidatePreviewAccentColor();
}

- (void)updatePanelStyle:(NSInteger)panelStyle pageSize:(NSInteger)pageSize fontSize:(NSInteger)fontSize
{
    _panelStyle = panelStyle;
    _pageSize = pageSize;
    _candidateFontSize = fontSize;
    NSString *layout = panelStyle == 1 ? @"纵向列表" : @"横向排列";
    self.accessibilityValue = [NSString stringWithFormat:@"%@，%ld 个候选，%ld pt", layout,
                                                         static_cast<long>(pageSize),
                                                         static_cast<long>(fontSize)];
    self.accessibilityHelp = @"预览会随候选排列、每页候选和候选字号实时变化";
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    NSRect canvas = NSInsetRect(self.bounds, 1.0, 1.0);
    NSBezierPath *canvasPath = [NSBezierPath bezierPathWithRoundedRect:canvas xRadius:12.0 yRadius:12.0];
    [[NSColor controlBackgroundColor] setFill];
    [canvasPath fill];
    [[NSColor separatorColor] setStroke];
    canvasPath.lineWidth = 1.0;
    [canvasPath stroke];

    NSDictionary<NSAttributedStringKey, id> *captionAttributes = @{
        NSFontAttributeName : [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName : [NSColor secondaryLabelColor],
    };
    [@"输入效果" drawAtPoint:NSMakePoint(15.0, 12.0) withAttributes:captionAttributes];
    NSString *pageSummary = [NSString stringWithFormat:@"每页 %ld 个", static_cast<long>(_pageSize)];
    NSSize pageSummarySize = [pageSummary sizeWithAttributes:captionAttributes];
    [pageSummary drawAtPoint:NSMakePoint(NSMaxX(canvas) - pageSummarySize.width - 14.0, 12.0)
              withAttributes:captionAttributes];

    NSRect panelRect = NSMakeRect(14.0, 35.0, NSWidth(self.bounds) - 28.0, NSHeight(self.bounds) - 49.0);
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowBlurRadius = 8.0;
    shadow.shadowOffset = NSMakeSize(0.0, 2.0);
    shadow.shadowColor = [[NSColor blackColor] colorWithAlphaComponent:0.12];
    [NSGraphicsContext saveGraphicsState];
    [shadow set];
    NSBezierPath *panelPath = [NSBezierPath bezierPathWithRoundedRect:panelRect xRadius:9.0 yRadius:9.0];
    [[self previewPanelFillColor] setFill];
    [panelPath fill];
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor separatorColor] setStroke];
    panelPath.lineWidth = 1.0;
    [panelPath stroke];

    NSDictionary<NSAttributedStringKey, id> *preeditAttributes = @{
        NSFontAttributeName : [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName : [self previewAccentColor],
    };
    [@"shuǐ shān shū rù fǎ" drawAtPoint:NSMakePoint(NSMinX(panelRect) + 12.0, NSMinY(panelRect) + 9.0)
                           withAttributes:preeditAttributes];

    NSArray<NSString *> *samples = @[ @"水杉", @"输入法", @"水仙", @"水山", @"水衫", @"水善", @"谁删", @"税闪", @"水扇" ];
    NSDictionary<NSAttributedStringKey, id> *numberAttributes = @{
        NSFontAttributeName : [NSFont monospacedDigitSystemFontOfSize:10.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName : [NSColor tertiaryLabelColor],
    };
    NSDictionary<NSAttributedStringKey, id> *candidateAttributes = @{
        NSFontAttributeName : [NSFont systemFontOfSize:_candidateFontSize weight:NSFontWeightRegular],
        NSForegroundColorAttributeName : [NSColor labelColor],
    };
    const NSInteger candidateCount = MIN(_pageSize, static_cast<NSInteger>(samples.count));
    if (_panelStyle == 1)
    {
        const NSInteger visibleCount = MIN(candidateCount, 5);
        const CGFloat rowSpacing = MIN(_candidateFontSize + 3.0, 22.0);
        for (NSInteger index = 0; index < visibleCount; ++index)
        {
            const CGFloat y = NSMinY(panelRect) + 27.0 + (index * rowSpacing);
            [[NSString stringWithFormat:@"%ld", static_cast<long>(index + 1)]
                drawAtPoint:NSMakePoint(NSMinX(panelRect) + 12.0, y + 4.0)
              withAttributes:numberAttributes];
            [samples[index] drawAtPoint:NSMakePoint(NSMinX(panelRect) + 34.0, y)
                          withAttributes:candidateAttributes];
        }
        if (candidateCount > visibleCount)
        {
            NSString *remaining = [NSString stringWithFormat:@"另有 %ld 个",
                                                               static_cast<long>(candidateCount - visibleCount)];
            NSSize remainingSize = [remaining sizeWithAttributes:captionAttributes];
            [remaining drawAtPoint:NSMakePoint(NSMaxX(panelRect) - remainingSize.width - 12.0,
                                                NSMaxY(panelRect) - remainingSize.height - 8.0)
                     withAttributes:captionAttributes];
        }
    }
    else
    {
        CGFloat x = NSMinX(panelRect) + 12.0;
        const CGFloat y = NSMinY(panelRect) + 53.0;
        NSSize ellipsisSize = [@"…" sizeWithAttributes:candidateAttributes];
        const CGFloat contentMaxX = NSMaxX(panelRect) - 12.0;
        for (NSInteger index = 0; index < candidateCount; ++index)
        {
            NSString *number = [NSString stringWithFormat:@"%ld", static_cast<long>(index + 1)];
            NSString *candidate = samples[index];
            NSSize numberSize = [number sizeWithAttributes:numberAttributes];
            NSSize candidateSize = [candidate sizeWithAttributes:candidateAttributes];
            const CGFloat itemWidth = numberSize.width + 4.0 + candidateSize.width;
            const BOOL hasFollowingCandidate = index + 1 < candidateCount;
            const CGFloat truncationReserve = hasFollowingCandidate ? 8.0 + ellipsisSize.width : 0.0;
            if (x + itemWidth + truncationReserve > contentMaxX)
            {
                if (x + ellipsisSize.width <= contentMaxX)
                {
                    [@"…" drawAtPoint:NSMakePoint(x, y) withAttributes:candidateAttributes];
                }
                break;
            }
            [number drawAtPoint:NSMakePoint(x, y + 4.0) withAttributes:numberAttributes];
            x += numberSize.width + 4.0;
            [candidate drawAtPoint:NSMakePoint(x, y) withAttributes:candidateAttributes];
            x += candidateSize.width + (hasFollowingCandidate ? 14.0 : 0.0);
        }
    }
}

@end

@implementation MetasequoiaPreferencesWindowController
{
    NSArray<NSButton *> *_schemeButtons;
    NSPopUpButton *_shuangpinSchemeButton;
    NSPopUpButton *_wubiSchemeButton;
    NSView *_wubiSettingsRow;
    NSButton *_autocorrectButton;
    NSButton *_helpcodeButton;
    NSButton *_chinesePunctuationButton;
    NSPopUpButton *_candidatePanelStyleButton;
    NSPopUpButton *_candidatePageSizeButton;
    NSPopUpButton *_candidateFontSizeButton;
    NSPopUpButton *_candidatePageShortcutButton;
    MetasequoiaCandidatePreviewView *_candidatePreview;
    NSButton *_candidateLearningButton;
    NSButton *_inputModeShortcutButton;
    NSButton *_fullWidthInputButton;
    NSButton *_wubiAutoCommitButton;
    NSButton *_resetLearningButton;
    NSTextField *_statusLabel;
    NSTextField *_versionLabel;
    NSTextField *_automaticUpdateLabel;
    NSButton *_updatePageButton;
    NSArray<NSView *> *_preferencePages;
    NSArray<NSButton *> *_navigationButtons;
    MetasequoiaUpdateController *_updateController;
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

+ (NSInteger)storedCandidatePageShortcut
{
    const NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kCandidatePageShortcutPreferenceKey];
    return static_cast<NSInteger>(metasequoia::mac::NormalizeCandidatePageShortcut(static_cast<int>(value)));
}

+ (void)setCandidatePageShortcut:(NSInteger)shortcut
{
    const NSInteger normalizedShortcut =
        static_cast<NSInteger>(metasequoia::mac::NormalizeCandidatePageShortcut(static_cast<int>(shortcut)));
    [[NSUserDefaults standardUserDefaults] setInteger:normalizedShortcut forKey:kCandidatePageShortcutPreferenceKey];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"MetasequoiaCandidatePageShortcutDidChangeNotification"
                      object:@(normalizedShortcut)];
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

+ (BOOL)storedFullWidthInputEnabled
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:kFullWidthInputPreferenceKey];
    return value == nil ? NO : [value boolValue];
}

+ (void)setFullWidthInputEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kFullWidthInputPreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaFullWidthInputDidChangeNotification"
                                                        object:@(enabled)];
}

+ (BOOL)storedWubiAutoCommitUniqueEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kWubiAutoCommitUniquePreferenceKey];
}

+ (void)setWubiAutoCommitUniqueEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kWubiAutoCommitUniquePreferenceKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MetasequoiaWubiAutoCommitUniqueDidChangeNotification"
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
    return [self initWithUpdateController:[MetasequoiaUpdateController sharedController]];
}

- (instancetype)initWithUpdateController:(MetasequoiaUpdateController *)updateController
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
    _updateController = updateController;

    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    window.contentView = contentView;

    NSBox *sidebar = [[NSBox alloc] initWithFrame:NSZeroRect];
    sidebar.boxType = NSBoxCustom;
    sidebar.titlePosition = NSNoTitle;
    sidebar.borderWidth = 0.0;
    sidebar.fillColor = MetasequoiaSidebarColor();
    sidebar.accessibilityLabel = @"水杉输入法导航";
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;

    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    iconView.image = NSApp.applicationIconImage;
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandTitle = [NSTextField labelWithString:@"水杉输入法"];
    brandTitle.font = [NSFont systemFontOfSize:20.0 weight:NSFontWeightSemibold];
    brandTitle.textColor = MetasequoiaSidebarPrimaryTextColor();
    brandTitle.alignment = NSTextAlignmentLeft;
    brandTitle.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandDescription = [NSTextField labelWithString:@"轻巧、专注的中文输入体验"];
    brandDescription.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular];
    brandDescription.textColor = MetasequoiaSidebarSecondaryTextColor();
    brandDescription.alignment = NSTextAlignmentLeft;
    brandDescription.maximumNumberOfLines = 2;
    brandDescription.translatesAutoresizingMaskIntoConstraints = NO;

    NSArray<NSString *> *navigationTitles = @[ @"键盘输入", @"外观", @"词库与数据", @"更新与反馈" ];
    NSArray<NSString *> *navigationSymbols =
        @[ @"keyboard", @"paintpalette", @"books.vertical", @"exclamationmark.bubble" ];
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
                                                NSForegroundColorAttributeName : MetasequoiaSidebarPrimaryTextColor(),
                                            }];
        button.alignment = NSTextAlignmentLeft;
        button.bordered = NO;
        button.contentTintColor = MetasequoiaSidebarPrimaryTextColor();
        button.imagePosition = NSImageLeading;
        NSImage *navigationImage = [NSImage imageWithSystemSymbolName:navigationSymbols[index]
                                             accessibilityDescription:navigationTitles[index]];
        navigationImage = [navigationImage imageWithSymbolConfiguration:
                                                [NSImageSymbolConfiguration
                                                    configurationWithHierarchicalColor:MetasequoiaSidebarPrimaryTextColor()]];
        [navigationImage setTemplate:NO];
        button.image = navigationImage;
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
    navigationStack.spacing = 8.0;
    navigationStack.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSButton *button in _navigationButtons)
    {
        [button.widthAnchor constraintEqualToAnchor:navigationStack.widthAnchor].active = YES;
    }

    NSButton *websiteButton = [NSButton buttonWithTitle:@"msime.app" target:self action:@selector(openWebsite:)];
    websiteButton.bordered = NO;
    websiteButton.contentTintColor = MetasequoiaSidebarPrimaryTextColor();
    websiteButton.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
    websiteButton.attributedTitle =
        [[NSAttributedString alloc] initWithString:@"msime.app"
                                        attributes:@{
                                            NSFontAttributeName : websiteButton.font,
                                            NSForegroundColorAttributeName : MetasequoiaSidebarPrimaryTextColor(),
                                        }];
    websiteButton.toolTip = @"打开水杉输入法官网";
    websiteButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *brandTag = [NSTextField labelWithString:@"METASEQUOIA  ·  macOS"];
    brandTag.font = [NSFont monospacedSystemFontOfSize:9.0 weight:NSFontWeightMedium];
    brandTag.textColor = MetasequoiaSidebarSecondaryTextColor();
    brandTag.alignment = NSTextAlignmentCenter;
    brandTag.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *settingsPanel = [[NSView alloc] initWithFrame:NSZeroRect];
    settingsPanel.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *pageContainer = [[NSView alloc] initWithFrame:NSZeroRect];
    pageContainer.translatesAutoresizingMaskIntoConstraints = NO;

    NSArray<NSString *> *schemeTitles = @[ @"全拼输入", @"双拼输入", @"五笔输入" ];
    NSMutableArray<NSButton *> *schemeButtons = [NSMutableArray arrayWithCapacity:schemeTitles.count];
    NSMutableArray<NSView *> *schemeRows = [NSMutableArray arrayWithObject:CardHeader(@"输入方式")];
    [schemeRows addObject:CardSeparator()];
    _shuangpinSchemeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_shuangpinSchemeButton addItemWithTitle:@"小鹤双拼"];
    _shuangpinSchemeButton.accessibilityLabel = @"双拼方案";
    _wubiSchemeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_wubiSchemeButton addItemWithTitle:@"86 五笔"];
    _wubiSchemeButton.accessibilityLabel = @"五笔方案";
    for (NSInteger index = 0; index < static_cast<NSInteger>(schemeTitles.count); ++index)
    {
        NSButton *button = [NSButton radioButtonWithTitle:schemeTitles[index]
                                                  target:self
                                                  action:@selector(schemeChanged:)];
        button.tag = index;
        button.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
        button.accessibilityLabel = schemeTitles[index];
        [schemeButtons addObject:button];
        NSView *accessory = index == 1 ? _shuangpinSchemeButton : (index == 2 ? _wubiSchemeButton : nil);
        [schemeRows addObject:SchemeChoiceRow(button, accessory)];
        [schemeRows addObject:CardSeparator()];
    }
    _schemeButtons = [schemeButtons copy];
    NSButton *wubiSettingsButton = [NSButton buttonWithTitle:@"设置"
                                                      target:self
                                                      action:@selector(showWubiSettings:)];
    wubiSettingsButton.bordered = NO;
    wubiSettingsButton.alignment = NSTextAlignmentRight;
    wubiSettingsButton.image = [NSImage imageWithSystemSymbolName:@"chevron.right"
                                         accessibilityDescription:nil];
    wubiSettingsButton.imagePosition = NSImageTrailing;
    wubiSettingsButton.contentTintColor = [NSColor labelColor];
    wubiSettingsButton.attributedTitle =
        [[NSAttributedString alloc] initWithString:wubiSettingsButton.title
                                        attributes:@{
                                            NSFontAttributeName :
                                                [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium],
                                            NSForegroundColorAttributeName : [NSColor labelColor],
                                        }];
    wubiSettingsButton.accessibilityLabel = @"五笔功能设置";
    _wubiSettingsRow = PreferenceRow(@"五笔功能", wubiSettingsButton);
    _wubiSettingsRow.accessibilityLabel = @"五笔功能行";
    [schemeRows addObject:_wubiSettingsRow];

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
    _fullWidthInputButton = [NSButton checkboxWithTitle:@"Option+Shift+H 切换全半角"
                                                   target:self
                                                   action:@selector(fullWidthInputChanged:)];
    _fullWidthInputButton.accessibilityLabel = @"Option+Shift+H 切换全半角";

    _candidatePageShortcutButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_candidatePageShortcutButton addItemsWithTitles:@[ @"- / =", @"[ / ]", @"Page Up / Page Down" ]];
    _candidatePageShortcutButton.target = self;
    _candidatePageShortcutButton.action = @selector(candidatePageShortcutChanged:);
    _candidatePageShortcutButton.accessibilityLabel = @"候选翻页快捷键";

    NSBox *schemeCard = CardWithViews(schemeRows, 0.0);
    NSBox *behaviorCard =
        CardWithViews(@[ _autocorrectButton, _chinesePunctuationButton, _inputModeShortcutButton,
                         _fullWidthInputButton ], 9.0);
    NSBox *shortcutCard = CardWithViews(@[ PreferenceRow(@"上翻 / 下翻", _candidatePageShortcutButton) ], 0.0);
    schemeCard.accessibilityLabel = @"输入方式卡片";
    behaviorCard.accessibilityLabel = @"中英文状态切换卡片";
    shortcutCard.accessibilityLabel = @"候选翻页快捷键卡片";
    NSView *generalPage =
        PreferencesPage(@"键盘输入", @"选择全拼、双拼或 86 五笔，并调整日常输入行为。",
                        @[
                            schemeCard, SectionLabel(@"中英文状态切换"), behaviorCard,
                            SectionLabel(@"候选翻页快捷键"), shortcutCard
                        ]);
    generalPage.accessibilityLabel = @"键盘输入设置页";

    NSButton *backToKeyboardButton = [NSButton buttonWithTitle:@"返回键盘输入"
                                                        target:self
                                                        action:@selector(backToKeyboardInput:)];
    backToKeyboardButton.bezelStyle = NSBezelStyleInline;
    backToKeyboardButton.image = [NSImage imageWithSystemSymbolName:@"chevron.left"
                                           accessibilityDescription:nil];
    backToKeyboardButton.imagePosition = NSImageLeft;
    backToKeyboardButton.alignment = NSTextAlignmentLeft;
    _wubiAutoCommitButton =
        [NSButton checkboxWithTitle:@"四码唯一候选自动上屏"
                             target:self
                             action:@selector(wubiAutoCommitUniqueChanged:)];
    _wubiAutoCommitButton.accessibilityLabel = @"四码唯一候选自动上屏";
    NSTextField *wubiSchemeLabel = [NSTextField labelWithString:@"86 五笔"];
    wubiSchemeLabel.textColor = [NSColor secondaryLabelColor];
    NSBox *wubiOptionsCard =
        CardWithViews(@[ PreferenceRow(@"编码方案", wubiSchemeLabel), _wubiAutoCommitButton ], 8.0);
    wubiOptionsCard.accessibilityLabel = @"五笔选项卡片";
    NSView *wubiPage =
        PreferencesPage(@"五笔设置", @"调整 86 五笔的输入与上屏行为。",
                        @[ backToKeyboardButton, SectionLabel(@"输入行为"), wubiOptionsCard ]);
    wubiPage.accessibilityLabel = @"五笔设置页";

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

    _candidatePreview = [[MetasequoiaCandidatePreviewView alloc] initWithFrame:NSZeroRect];
    NSBox *appearanceCard =
        CardWithViews(@[
            PreferenceRow(@"候选排列", _candidatePanelStyleButton),
            PreferenceRow(@"每页候选", _candidatePageSizeButton),
            PreferenceRow(@"候选字号", _candidateFontSizeButton),
        ],
                      4.0);
    appearanceCard.accessibilityLabel = @"候选窗口卡片";
    NSView *appearancePage = PreferencesPage(@"外观", @"调整原生候选窗口的排列、容量与阅读大小。",
                                             @[ SectionLabel(@"效果预览"), _candidatePreview,
                                                SectionLabel(@"候选窗口"), appearanceCard ]);
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

    _versionLabel = [NSTextField labelWithString:@"开发构建"];
    _versionLabel.textColor = [NSColor secondaryLabelColor];
    _versionLabel.alignment = NSTextAlignmentRight;
    _versionLabel.accessibilityLabel = @"当前版本";

    _automaticUpdateLabel = [NSTextField labelWithString:@"检查自动更新状态…"];
    _automaticUpdateLabel.textColor = [NSColor secondaryLabelColor];
    _automaticUpdateLabel.alignment = NSTextAlignmentRight;
    _automaticUpdateLabel.accessibilityLabel = @"自动更新状态";

    _updatePageButton = [NSButton buttonWithTitle:@"检查更新…"
                                           target:self
                                           action:@selector(checkForUpdates:)];
    _updatePageButton.bezelStyle = NSBezelStyleRounded;
    _updatePageButton.accessibilityLabel = @"立即检查更新";

    NSButton *feedbackButton = [NSButton buttonWithTitle:@"提交反馈…"
                                                    target:self
                                                    action:@selector(openFeedback:)];
    feedbackButton.bezelStyle = NSBezelStyleInline;
    feedbackButton.accessibilityLabel = @"提交反馈";
    feedbackButton.contentTintColor = [NSColor linkColor];
    feedbackButton.attributedTitle =
        [[NSAttributedString alloc] initWithString:feedbackButton.title
                                        attributes:@{
                                            NSFontAttributeName :
                                                [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium],
                                            NSForegroundColorAttributeName : [NSColor linkColor],
                                        }];

    NSButton *productWebsiteButton = [NSButton buttonWithTitle:@"访问 msime.app"
                                                        target:self
                                                        action:@selector(openWebsite:)];
    productWebsiteButton.bezelStyle = NSBezelStyleInline;
    productWebsiteButton.accessibilityLabel = @"访问水杉官网";
    productWebsiteButton.contentTintColor = [NSColor linkColor];
    productWebsiteButton.attributedTitle =
        [[NSAttributedString alloc] initWithString:productWebsiteButton.title
                                        attributes:@{
                                            NSFontAttributeName :
                                                [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium],
                                            NSForegroundColorAttributeName : [NSColor linkColor],
                                        }];

    NSBox *updateCard = CardWithViews(@[
        PreferenceRow(@"当前版本", _versionLabel),
        PreferenceRow(@"自动更新", _automaticUpdateLabel),
        PreferenceRow(@"立即检查", _updatePageButton),
    ], 4.0);
    updateCard.accessibilityLabel = @"软件更新卡片";
    NSBox *feedbackCard = CardWithViews(@[
        PreferenceRow(@"问题反馈与功能建议", feedbackButton),
        PreferenceRow(@"产品主页与使用帮助", productWebsiteButton),
    ], 4.0);
    feedbackCard.accessibilityLabel = @"反馈与帮助卡片";
    NSView *updatesPage =
        PreferencesPage(@"更新与反馈", @"保持水杉输入法为最新版本，并告诉我们哪里还可以做得更好。",
                        @[ SectionLabel(@"软件更新"), updateCard, SectionLabel(@"反馈与帮助"), feedbackCard ]);
    updatesPage.accessibilityLabel = @"更新与反馈设置页";

    _preferencePages = @[ generalPage, appearancePage, dataPage, updatesPage, wubiPage ];

    NSButton *restoreButton = [NSButton buttonWithTitle:@"恢复默认设置" target:self action:@selector(restoreDefaults:)];
    restoreButton.bezelStyle = NSBezelStyleRounded;
    restoreButton.translatesAutoresizingMaskIntoConstraints = NO;

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
    [settingsPanel addSubview:closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [sidebar.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [sidebar.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:260.0],
        [iconView.topAnchor constraintEqualToAnchor:sidebar.topAnchor constant:44.0],
        [iconView.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:26.0],
        [iconView.widthAnchor constraintEqualToConstant:48.0],
        [iconView.heightAnchor constraintEqualToConstant:48.0],
        [brandTitle.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12.0],
        [brandTitle.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-20.0],
        [brandTitle.centerYAnchor constraintEqualToAnchor:iconView.centerYAnchor],
        [brandDescription.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:18.0],
        [brandDescription.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:26.0],
        [brandDescription.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-26.0],
        [navigationStack.topAnchor constraintEqualToAnchor:brandDescription.bottomAnchor constant:28.0],
        [navigationStack.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:18.0],
        [navigationStack.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-18.0],
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
        [closeButton.trailingAnchor constraintEqualToAnchor:settingsPanel.trailingAnchor constant:-30.0],
        [closeButton.centerYAnchor constraintEqualToAnchor:restoreButton.centerYAnchor],
        [closeButton.widthAnchor constraintGreaterThanOrEqualToConstant:80.0],
    ]];
    [self selectPreferencesPage:_navigationButtons.firstObject];
    [self refreshUpdateControls];
    return self;
}

- (void)refreshUpdateControls
{
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    _versionLabel.stringValue = version.length == 0 ? @"开发构建" : [NSString stringWithFormat:@"v%@", version];
    _automaticUpdateLabel.stringValue = _updateController.automaticallyChecksForUpdates
                                            ? @"已开启自动检查"
                                            : @"自动检查已关闭";
    _updatePageButton.toolTip = @"通过 msime.app 检查水杉输入法的最新正式版本";
    _updatePageButton.accessibilityHelp = version.length == 0
                                              ? @"通过 msime.app 检查最新正式版本"
                                              : [NSString stringWithFormat:@"当前版本 v%@，通过 msime.app 检查最新正式版本", version];
    _updatePageButton.enabled = YES;
}

- (void)checkForUpdates:(id)sender
{
    [_updateController checkForUpdates:sender];
}

- (void)selectPreferencesPage:(id)sender
{
    NSButton *selectedButton = [sender isKindOfClass:[NSButton class]] ? (NSButton *)sender : nil;
    const NSInteger selectedIndex = selectedButton == nil ? 0 : selectedButton.tag;
    [self showPreferencesPageAtIndex:selectedIndex sidebarIndex:selectedIndex];
}

- (void)showPreferencesPageAtIndex:(NSInteger)pageIndex sidebarIndex:(NSInteger)sidebarIndex
{
    for (NSInteger index = 0; index < static_cast<NSInteger>(_preferencePages.count); ++index)
    {
        const BOOL selected = index == pageIndex;
        _preferencePages[index].hidden = !selected;
    }
    for (NSInteger index = 0; index < static_cast<NSInteger>(_navigationButtons.count); ++index)
    {
        const BOOL selected = index == sidebarIndex;
        NSButton *button = _navigationButtons[index];
        button.state = selected ? NSControlStateValueOn : NSControlStateValueOff;
        button.accessibilityValue = @(selected);
        NSColor *backgroundColor = selected ? MetasequoiaSidebarSelectionColor() : [NSColor clearColor];
        button.layer.backgroundColor = backgroundColor.CGColor;
    }
}

- (void)showWubiSettings:(id)sender
{
    (void)sender;
    [self refreshControls];
    [self showPreferencesPageAtIndex:4 sidebarIndex:0];
}

- (void)backToKeyboardInput:(id)sender
{
    (void)sender;
    [self showPreferencesPageAtIndex:0 sidebarIndex:0];
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

- (void)openFeedback:(id)sender
{
    (void)sender;
    NSURL *feedback = [NSURL URLWithString:@"https://github.com/metasequoiaime/MSIME-Apple/issues/new"];
    if (feedback != nil)
    {
        [[NSWorkspace sharedWorkspace] openURL:feedback];
    }
}

- (void)refreshControls
{
    const NSInteger storedScheme = [MetasequoiaPreferencesWindowController storedScheme];
    for (NSInteger index = 0; index < static_cast<NSInteger>(_schemeButtons.count); ++index)
    {
        _schemeButtons[index].state = index == storedScheme ? NSControlStateValueOn : NSControlStateValueOff;
    }
    _shuangpinSchemeButton.enabled = storedScheme == 1;
    _wubiSchemeButton.enabled = storedScheme == 2;
    _wubiSettingsRow.hidden = storedScheme != 2;
    _autocorrectButton.state = [MetasequoiaPreferencesWindowController storedAutocorrectEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    _helpcodeButton.state = [MetasequoiaPreferencesWindowController storedHelpcodeEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    _chinesePunctuationButton.state = [MetasequoiaPreferencesWindowController storedChinesePunctuationEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [_candidatePanelStyleButton selectItemAtIndex:[MetasequoiaPreferencesWindowController storedCandidatePanelStyle]];
    [_candidatePageSizeButton selectItemAtIndex:static_cast<NSInteger>(metasequoia::mac::CandidatePageSizeOptionIndex(
                                                        static_cast<size_t>([MetasequoiaPreferencesWindowController storedCandidatePageSize])))];
    [_candidateFontSizeButton selectItemAtIndex:static_cast<NSInteger>(metasequoia::mac::CandidateFontSizeOptionIndex(
                                                        static_cast<size_t>([MetasequoiaPreferencesWindowController storedCandidateFontSize])))];
    [_candidatePageShortcutButton
        selectItemAtIndex:[MetasequoiaPreferencesWindowController storedCandidatePageShortcut]];
    [_candidatePreview updatePanelStyle:[MetasequoiaPreferencesWindowController storedCandidatePanelStyle]
                               pageSize:[MetasequoiaPreferencesWindowController storedCandidatePageSize]
                               fontSize:[MetasequoiaPreferencesWindowController storedCandidateFontSize]];
    _candidateLearningButton.state = [MetasequoiaPreferencesWindowController storedCandidateLearningEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    _inputModeShortcutButton.state = [MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    _fullWidthInputButton.state = [MetasequoiaPreferencesWindowController storedFullWidthInputEnabled]
                                      ? NSControlStateValueOn
                                      : NSControlStateValueOff;
    _wubiAutoCommitButton.state =
        [MetasequoiaPreferencesWindowController storedWubiAutoCommitUniqueEnabled] ? NSControlStateValueOn
                                                                                   : NSControlStateValueOff;
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
    [self refreshUpdateControls];
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
    [self refreshControls];
}

- (void)candidatePanelStyleChanged:(id)sender
{
    NSPopUpButton *styleButton = (NSPopUpButton *)sender;
    [MetasequoiaPreferencesWindowController setCandidatePanelStyle:styleButton.indexOfSelectedItem];
    [_candidatePreview updatePanelStyle:[MetasequoiaPreferencesWindowController storedCandidatePanelStyle]
                               pageSize:[MetasequoiaPreferencesWindowController storedCandidatePageSize]
                               fontSize:[MetasequoiaPreferencesWindowController storedCandidateFontSize]];
}

- (void)candidatePageSizeChanged:(id)sender
{
    NSPopUpButton *pageSizeButton = (NSPopUpButton *)sender;
    const size_t pageSize =
        metasequoia::mac::CandidatePageSizeForOptionIndex(static_cast<size_t>(pageSizeButton.indexOfSelectedItem));
    [MetasequoiaPreferencesWindowController setCandidatePageSize:static_cast<NSInteger>(pageSize)];
    [_candidatePreview updatePanelStyle:[MetasequoiaPreferencesWindowController storedCandidatePanelStyle]
                               pageSize:[MetasequoiaPreferencesWindowController storedCandidatePageSize]
                               fontSize:[MetasequoiaPreferencesWindowController storedCandidateFontSize]];
}

- (void)candidateFontSizeChanged:(id)sender
{
    NSPopUpButton *fontSizeButton = (NSPopUpButton *)sender;
    const size_t fontSize =
        metasequoia::mac::CandidateFontSizeForOptionIndex(static_cast<size_t>(fontSizeButton.indexOfSelectedItem));
    [MetasequoiaPreferencesWindowController setCandidateFontSize:static_cast<NSInteger>(fontSize)];
    [_candidatePreview updatePanelStyle:[MetasequoiaPreferencesWindowController storedCandidatePanelStyle]
                               pageSize:[MetasequoiaPreferencesWindowController storedCandidatePageSize]
                               fontSize:[MetasequoiaPreferencesWindowController storedCandidateFontSize]];
}

- (void)candidateLearningChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setCandidateLearningEnabled:button.state == NSControlStateValueOn];
}

- (void)candidatePageShortcutChanged:(id)sender
{
    NSPopUpButton *shortcutButton = (NSPopUpButton *)sender;
    [MetasequoiaPreferencesWindowController setCandidatePageShortcut:shortcutButton.indexOfSelectedItem];
}

- (void)inputModeShortcutChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setInputModeShortcutEnabled:button.state == NSControlStateValueOn];
}

- (void)fullWidthInputChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setFullWidthInputEnabled:button.state == NSControlStateValueOn];
}

- (void)wubiAutoCommitUniqueChanged:(id)sender
{
    NSButton *button = (NSButton *)sender;
    [MetasequoiaPreferencesWindowController setWubiAutoCommitUniqueEnabled:button.state == NSControlStateValueOn];
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
             kCandidatePageShortcutPreferenceKey,
             kCandidateLearningPreferenceKey,
             kInputModeShortcutPreferenceKey,
             kWubiAutoCommitUniquePreferenceKey,
             kFullWidthInputPreferenceKey,
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
    [notifications postNotificationName:@"MetasequoiaCandidatePageShortcutDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedCandidatePageShortcut])];
    [notifications postNotificationName:@"MetasequoiaCandidateLearningDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedCandidateLearningEnabled])];
    [notifications postNotificationName:@"MetasequoiaInputModeShortcutDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled])];
    [notifications postNotificationName:@"MetasequoiaWubiAutoCommitUniqueDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedWubiAutoCommitUniqueEnabled])];
    [notifications postNotificationName:@"MetasequoiaFullWidthInputDidChangeNotification"
                                  object:@([MetasequoiaPreferencesWindowController storedFullWidthInputEnabled])];
    [self refreshControls];
}

- (void)close:(id)sender
{
    [self.window performClose:sender];
}

@end
