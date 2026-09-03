#import "PreferencesWindowController.h"

namespace
{
constexpr CGFloat kWindowWidth = 480.0;
constexpr CGFloat kWindowHeight = 276.0;
} // namespace

@implementation MetasequoiaPreferencesWindowController

+ (instancetype)sharedController
{
    static MetasequoiaPreferencesWindowController *controller = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [[self alloc] init];
    });
    return controller;
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

    NSPopUpButton *schemeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [schemeButton addItemWithTitle:@"全拼（当前支持）"];
    schemeButton.enabled = NO;
    schemeButton.accessibilityLabel = @"输入方案";
    schemeButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *statusLabel = [NSTextField labelWithString:@"更多设置将在后续版本提供。"];
    statusLabel.textColor = [NSColor secondaryLabelColor];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *closeButton = [NSButton buttonWithTitle:@"关闭" target:self action:@selector(close:)];
    closeButton.bezelStyle = NSBezelStyleRounded;
    closeButton.keyEquivalent = @"\r";
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;

    [contentView addSubview:titleLabel];
    [contentView addSubview:descriptionLabel];
    [contentView addSubview:schemeLabel];
    [contentView addSubview:schemeButton];
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
        [schemeButton.centerYAnchor constraintEqualToAnchor:schemeLabel.centerYAnchor],
        [schemeButton.leadingAnchor constraintEqualToAnchor:schemeLabel.trailingAnchor constant:12.0],
        [schemeButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-32.0],
        [statusLabel.topAnchor constraintEqualToAnchor:schemeButton.bottomAnchor constant:20.0],
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
    [self showWindow:nil];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)close:(id)sender
{
    (void)sender;
    [self.window orderOut:nil];
}

@end
