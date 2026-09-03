#import "PreferencesWindowController.h"

namespace
{
constexpr CGFloat kWindowWidth = 480.0;
constexpr CGFloat kWindowHeight = 276.0;
NSString * const kSchemePreferenceKey = @"MetasequoiaImeInputScheme";
NSString * const kAutocorrectPreferenceKey = @"MetasequoiaImeQuanpinAutocorrect";
NSString * const kHelpcodePreferenceKey = @"MetasequoiaImeHelpcodeEnabled";
} // namespace

@implementation MetasequoiaPreferencesWindowController
{
    NSPopUpButton *_schemeButton;
    NSButton *_autocorrectButton;
    NSButton *_helpcodeButton;
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

    self = [super initWithWindow:window];
    if (self == nil)
    {
        return nil;
    }

    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    window.contentView = contentView;

    NSTextField *titleLabel = [NSTextField labelWithString:@"水杉输入法设置"];
    titleLabel.font = [NSFont boldSystemFontOfSize:24.0];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *descriptionLabel = [NSTextField labelWithString:@"配置输入方案和输入行为。"];
    descriptionLabel.textColor = [NSColor secondaryLabelColor];
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *schemeLabel = [NSTextField labelWithString:@"输入方案"];
    schemeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _schemeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_schemeButton addItemWithTitle:@"全拼"];
    [_schemeButton addItemWithTitle:@"小鹤双拼"];
    _schemeButton.target = self;
    _schemeButton.action = @selector(schemeChanged:);
    _schemeButton.accessibilityLabel = @"输入方案";
    _schemeButton.translatesAutoresizingMaskIntoConstraints = NO;

    _autocorrectButton = [NSButton checkboxWithTitle:@"启用全拼自动纠错" target:self action:@selector(autocorrectChanged:)];
    _autocorrectButton.translatesAutoresizingMaskIntoConstraints = NO;

    _helpcodeButton = [NSButton checkboxWithTitle:@"启用辅助码" target:self action:@selector(helpcodeChanged:)];
    _helpcodeButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *statusLabel = [NSTextField labelWithString:@"输入方案会保存到当前用户设置，并在下一次输入会话中生效。"];
    statusLabel.textColor = [NSColor secondaryLabelColor];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *closeButton = [NSButton buttonWithTitle:@"关闭" target:self action:@selector(close:)];
    closeButton.bezelStyle = NSBezelStyleRounded;
    closeButton.keyEquivalent = @"\r";
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;

    [contentView addSubview:titleLabel];
    [contentView addSubview:descriptionLabel];
    [contentView addSubview:schemeLabel];
    [contentView addSubview:_schemeButton];
    [contentView addSubview:_autocorrectButton];
    [contentView addSubview:_helpcodeButton];
    [contentView addSubview:statusLabel];
    [contentView addSubview:closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:28.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:32.0],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:contentView.trailingAnchor constant:-32.0],
        [descriptionLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [descriptionLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [descriptionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:contentView.trailingAnchor constant:-32.0],
        [schemeLabel.topAnchor constraintEqualToAnchor:descriptionLabel.bottomAnchor constant:34.0],
        [schemeLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [schemeLabel.widthAnchor constraintEqualToConstant:100.0],
        [_schemeButton.centerYAnchor constraintEqualToAnchor:schemeLabel.centerYAnchor],
        [_schemeButton.leadingAnchor constraintEqualToAnchor:schemeLabel.trailingAnchor constant:12.0],
        [_schemeButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-32.0],
        [_autocorrectButton.leadingAnchor constraintEqualToAnchor:_schemeButton.leadingAnchor],
        [_autocorrectButton.topAnchor constraintEqualToAnchor:_schemeButton.bottomAnchor constant:16.0],
        [_helpcodeButton.leadingAnchor constraintEqualToAnchor:_schemeButton.leadingAnchor],
        [_helpcodeButton.topAnchor constraintEqualToAnchor:_autocorrectButton.bottomAnchor constant:10.0],
        [statusLabel.topAnchor constraintEqualToAnchor:_helpcodeButton.bottomAnchor constant:12.0],
        [statusLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:contentView.trailingAnchor constant:-32.0],
        [closeButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-32.0],
        [closeButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0],
        [closeButton.widthAnchor constraintGreaterThanOrEqualToConstant:80.0],
    ]];
    return self;
}

- (void)showAndActivate
{
    [_schemeButton selectItemAtIndex:[MetasequoiaPreferencesWindowController storedScheme]];
    _autocorrectButton.state = [MetasequoiaPreferencesWindowController storedAutocorrectEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    _helpcodeButton.state = [MetasequoiaPreferencesWindowController storedHelpcodeEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
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

- (void)schemeChanged:(id)sender
{
    NSPopUpButton *schemeButton = (NSPopUpButton *)sender;
    [MetasequoiaPreferencesWindowController setStoredScheme:schemeButton.indexOfSelectedItem];
}

- (void)close:(id)sender
{
    (void)sender;
    [self.window orderOut:nil];
}

@end
