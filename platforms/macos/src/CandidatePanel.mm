#import "CandidatePanel.h"
#include <cmath>

@interface MetasequoiaCandidateWindow : NSPanel
@end
@implementation MetasequoiaCandidateWindow
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface MetasequoiaCandidateButton : NSButton
@property(nonatomic) BOOL candidateHighlighted;
@end
@implementation MetasequoiaCandidateButton
- (BOOL)acceptsFirstResponder { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { (void)event; return YES; }
- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    if (self.candidateHighlighted)
    {
        [NSColor.selectedContentBackgroundColor setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 1, 1) xRadius:6 yRadius:6] fill];
    }
    NSColor *color = self.candidateHighlighted ? NSColor.selectedMenuItemTextColor : NSColor.labelColor;
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *attributes = @{NSFontAttributeName:self.font, NSForegroundColorAttributeName:color, NSParagraphStyleAttributeName:paragraph};
    const NSSize size = [self.title sizeWithAttributes:attributes];
    [self.title drawInRect:NSMakeRect(8, (self.bounds.size.height - size.height) / 2,
                                     self.bounds.size.width - 16, size.height) withAttributes:attributes];
}
@end

@implementation MetasequoiaCandidatePanel
{
    NSPanel *_window;
    NSArray<NSAttributedString *> *_data;
    NSFont *_font;
    NSInteger _selected;
}
- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _data = @[];
        _font = [NSFont systemFontOfSize:18];
        _selected = NSNotFound;
        _window = [[MetasequoiaCandidateWindow alloc] initWithContentRect:NSZeroRect
            styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
            backing:NSBackingStoreBuffered defer:NO];
        _window.releasedWhenClosed = NO;
        _window.level = NSPopUpMenuWindowLevel;
        _window.hidesOnDeactivate = NO;
        _window.opaque = NO;
        _window.backgroundColor = NSColor.clearColor;
        _window.hasShadow = YES;
        _window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
        NSVisualEffectView *content = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
        content.material = NSVisualEffectMaterialPopover;
        content.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        content.state = NSVisualEffectStateActive;
        content.wantsLayer = YES;
        content.layer.cornerRadius = 9;
        content.layer.masksToBounds = YES;
        _window.contentView = content;
    }
    return self;
}
- (void)dealloc { [_window orderOut:nil]; }
- (NSPanel *)window { return _window; }
- (void)setPanelType:(IMKCandidatePanelType)type { _panelType = type; [self layoutCandidates]; }
- (void)setHasPreviousPage:(BOOL)value { _hasPreviousPage = value; [self layoutCandidates]; }
- (void)setHasNextPage:(BOOL)value { _hasNextPage = value; [self layoutCandidates]; }
- (void)setAttributes:(NSDictionary *)attributes
{
    NSFont *font = attributes[NSFontAttributeName];
    if ([font isKindOfClass:NSFont.class]) _font = font;
    [self layoutCandidates];
}
- (void)setCandidateData:(NSArray<NSAttributedString *> *)candidates
{
    _data = [candidates copy];
    _selected = _data.count > 0 ? 0 : NSNotFound;
    [self layoutCandidates];
    if (_data.count == 0) [self hide];
}
- (NSScreen *)screenForCaret
{
    for (NSScreen *screen in NSScreen.screens)
        if (NSPointInRect(NSMakePoint(NSMinX(self.caretRect), NSMidY(self.caretRect)), screen.frame)) return screen;
    return NSScreen.mainScreen;
}
- (void)layoutCandidates
{
    for (NSView *view in [_window.contentView.subviews copy]) [view removeFromSuperview];
    const CGFloat inset = 5;
    const CGFloat rowHeight = ceil(_font.ascender - _font.descender + _font.leading) + 12;
    const BOOL vertical = _panelType == kIMKSingleColumnScrollingCandidatePanel;
    NSMutableArray<NSNumber *> *widths = [NSMutableArray array];
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    CGFloat width = 0;
    const BOOL paging = _hasPreviousPage || _hasNextPage;
    const CGFloat screenWidth = [self screenForCaret].visibleFrame.size.width;
    const CGFloat availableWidth = MAX(80, screenWidth - 20 - 2 * inset - (paging && !vertical ? 56 : 0));
    const CGFloat maximumItemWidth = vertical ? availableWidth : availableWidth / MAX((NSUInteger)1, _data.count);
    for (NSUInteger index = 0; index < _data.count; ++index)
    {
        NSString *title = [NSString stringWithFormat:@"%lu  %@", (unsigned long)index + 1, _data[index].string];
        CGFloat itemWidth = MIN(ceil([title sizeWithAttributes:@{NSFontAttributeName:_font}].width) + 16, maximumItemWidth);
        [titles addObject:title];
        [widths addObject:@(itemWidth)];
        width = vertical ? MAX(width, itemWidth) : width + itemWidth;
    }
    const CGFloat navigationHeight = paging && vertical ? 26 : 0;
    if (paging) width = vertical ? MAX(width, 64) : width + 56;
    NSSize size = NSMakeSize(MAX(width + 2 * inset, 20),
        MAX((vertical ? _data.count : (_data.count > 0 ? 1 : 0)) * rowHeight + navigationHeight + 2 * inset, 10));
    [_window setContentSize:size];
    CGFloat x = inset;
    for (NSUInteger index = 0; index < _data.count; ++index)
    {
        const CGFloat itemWidth = vertical ? width : widths[index].doubleValue;
        const CGFloat y = vertical ? size.height - inset - (index + 1) * rowHeight : inset;
        MetasequoiaCandidateButton *button = [[MetasequoiaCandidateButton alloc] initWithFrame:NSMakeRect(x, y, itemWidth, rowHeight)];
        button.title = titles[index];
        button.font = _font;
        button.bordered = NO;
        button.tag = (NSInteger)index;
        button.target = self;
        button.action = @selector(selectFromMouse:);
        button.candidateHighlighted = (NSInteger)index == _selected;
        button.accessibilityLabel = titles[index];
        button.toolTip = _data[index].string;
        [_window.contentView addSubview:button];
        if (!vertical) x += itemWidth;
    }
    if (paging)
    {
        for (NSUInteger index = 0; index < 2; ++index)
        {
            NSButton *button = [NSButton buttonWithTitle:index == 0 ? @"‹" : @"›" target:self action:@selector(changePage:)];
            button.frame = NSMakeRect(vertical ? inset + index * 28 : x + index * 28, inset, 28,
                                      vertical ? navigationHeight : rowHeight);
            button.bordered = NO;
            button.tag = index == 0 ? -1 : -2;
            button.enabled = index == 0 ? _hasPreviousPage : _hasNextPage;
            button.accessibilityLabel = index == 0 ? @"上一页候选" : @"下一页候选";
            [_window.contentView addSubview:button];
        }
    }
}
- (void)selectFromMouse:(NSButton *)button
{
    if ([self selectCandidateWithIdentifier:button.tag]) [self.delegate candidateSelected:_data[button.tag]];
}
- (void)changePage:(NSButton *)button
{
    if (button.tag == -1 && _hasPreviousPage) [self.delegate candidatePanelPreviousPage];
    if (button.tag == -2 && _hasNextPage) [self.delegate candidatePanelNextPage];
}
- (void)show:(IMKCandidatesLocationHint)hint
{
    (void)hint;
    if (_data.count == 0) { [self hide]; return; }
    NSRect caret = self.caretRect;
    if (!std::isfinite(caret.origin.x) || !std::isfinite(caret.origin.y) ||
        !std::isfinite(caret.size.width) || !std::isfinite(caret.size.height) || caret.size.height <= 0)
    { [self hide]; return; }
    [self layoutCandidates];
    NSRect bounds = [self screenForCaret].visibleFrame;
    NSSize size = _window.frame.size;
    CGFloat x = MIN(MAX(NSMinX(caret), NSMinX(bounds)), MAX(NSMinX(bounds), NSMaxX(bounds) - size.width));
    CGFloat y = NSMinY(caret) - size.height - 4;
    if (y < NSMinY(bounds)) y = NSMaxY(caret) + 4;
    y = MIN(MAX(y, NSMinY(bounds)), MAX(NSMinY(bounds), NSMaxY(bounds) - size.height));
    [_window setFrameOrigin:NSMakePoint(x, y)];
    [_window orderFrontRegardless];
}
- (void)hide { [_window orderOut:nil]; }
- (BOOL)isVisible { return _window.isVisible; }
- (NSRect)candidateFrame { return _window.frame; }
- (NSInteger)candidateIdentifierAtLineNumber:(NSInteger)line
{ return line >= 0 && (NSUInteger)line < _data.count ? line : NSNotFound; }
- (NSInteger)lineNumberForCandidateWithIdentifier:(NSInteger)identifier
{ return [self candidateIdentifierAtLineNumber:identifier]; }
- (NSInteger)candidateStringIdentifier:(NSAttributedString *)candidate
{ return (NSInteger)[_data indexOfObjectIdenticalTo:candidate]; }
- (BOOL)selectCandidateWithIdentifier:(NSInteger)identifier
{
    if ([self candidateIdentifierAtLineNumber:identifier] == NSNotFound) return NO;
    _selected = identifier;
    for (NSView *view in _window.contentView.subviews)
        if ([view isKindOfClass:MetasequoiaCandidateButton.class])
        {
            ((MetasequoiaCandidateButton *)view).candidateHighlighted = view.tag == identifier;
            view.needsDisplay = YES;
        }
    return YES;
}
- (NSInteger)selectedCandidate { return _selected; }
- (NSAttributedString *)selectedCandidateString { return _selected == NSNotFound ? nil : _data[_selected]; }
@end
