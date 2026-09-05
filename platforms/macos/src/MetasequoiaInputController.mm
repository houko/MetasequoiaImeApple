#import "MetasequoiaInputController.h"

#import "DictionaryInstaller.h"
#import "FloatingToolbarPanel.h"
#import "ChineseTextConversion.h"
#include "CandidateFontSize.h"
#include "CandidateDisplay.h"
#include "CandidatePageSize.h"
#include "CandidatePanelStyle.h"
#import "InputMenu.h"
#include "InputModeRouting.h"
#include "FullWidthInput.h"
#include "InputSchemePreference.h"
#include "WubiCommitPolicy.h"
#import "PreferencesWindowController.h"
#import "ShuangpinKeymapPanel.h"
#import "UpdateController.h"
#include "StringConversion.h"
#include "CandidateSelectionState.h"
#include "InputControllerKeyRouting.h"
#include "core/input_session.h"

#import <Carbon/Carbon.h>

#include <memory>
#include <cmath>

namespace
{
constexpr NSTimeInterval kDictionaryRetryDelay = 2.0;

struct SessionPreferences
{
    SchemeType scheme;
    bool autocorrectEnabled;
    bool helpcodeEnabled;
    bool chinesePunctuationEnabled;
    metasequoia::mac::CandidatePanelStyle candidatePanelStyle;
    size_t candidatePageSize;
    size_t candidateFontSize;
    bool candidateLearningEnabled;
    bool wubiAutoCommitUniqueEnabled;
};

SessionPreferences ReadSessionPreferences()
{
    return {
        metasequoia::mac::EngineSchemeForStoredPreference(
            static_cast<int>([MetasequoiaPreferencesWindowController storedScheme])),
        [MetasequoiaPreferencesWindowController storedAutocorrectEnabled] == YES,
        [MetasequoiaPreferencesWindowController storedHelpcodeEnabled] == YES,
        [MetasequoiaPreferencesWindowController storedChinesePunctuationEnabled] == YES,
        metasequoia::mac::NormalizeCandidatePanelStyle(
            [MetasequoiaPreferencesWindowController storedCandidatePanelStyle]),
        metasequoia::mac::NormalizeCandidatePageSize(
            static_cast<size_t>([MetasequoiaPreferencesWindowController storedCandidatePageSize])),
        metasequoia::mac::NormalizeCandidateFontSize(
            static_cast<size_t>([MetasequoiaPreferencesWindowController storedCandidateFontSize])),
        [MetasequoiaPreferencesWindowController storedCandidateLearningEnabled] == YES,
        [MetasequoiaPreferencesWindowController storedWubiAutoCommitUniqueEnabled] == YES,
    };
}

bool SessionMatchesPreferences(const metasequoia::InputSession &session, const SessionPreferences &preferences)
{
    return session.scheme_type() == preferences.scheme &&
           session.quanpin_autocorrect_enabled() == preferences.autocorrectEnabled &&
           session.helpcode_enabled() == preferences.helpcodeEnabled &&
           session.chinese_punctuation_enabled() == preferences.chinesePunctuationEnabled &&
           session.candidate_learning_enabled() == preferences.candidateLearningEnabled;
}
} // namespace

@interface MetasequoiaInputController () <MetasequoiaFloatingToolbarDelegate>
@end

@implementation MetasequoiaInputController
{
    std::unique_ptr<metasequoia::InputSession> _session;
    metasequoia::mac::CandidateSelectionState _candidateSelection;
    IMKCandidates *_candidatePanel;
    MetasequoiaFloatingToolbarPanel *_floatingToolbarPanel;
    MetasequoiaShuangpinKeymapPanel *_shuangpinKeymapPanel;
    NSArray *_candidateData;
    NSUInteger _candidateHighlightedIndex;
    NSUInteger _candidatePageStart;
    BOOL _candidateLineIdentifiersCollapsed;
    BOOL _wubiAutoCommitUniqueEnabled;
    BOOL _serverActive;
    BOOL _shuangpinKeymapEnabled;
    NSTimeInterval _dictionaryRetryAfter;
}

- (instancetype)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient
{
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self != nil)
    {
        _candidatePanel = [[IMKCandidates alloc] initWithServer:server panelType:kIMKSingleRowSteppingCandidatePanel styleType:kIMKMain];
        _floatingToolbarPanel = [MetasequoiaFloatingToolbarPanel sharedPanel];
        _shuangpinKeymapPanel = [[MetasequoiaShuangpinKeymapPanel alloc] init];
        [_candidatePanel setAttributes:metasequoia::mac::CandidatePanelAttributes(
                                           static_cast<size_t>([MetasequoiaPreferencesWindowController storedCandidateFontSize]))];

        if (metasequoia::mac::ShouldPrepareInputSession(
                [MetasequoiaPreferencesWindowController storedEnglishInputMode]))
        {
            [self prepareSessionIfNeeded];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(prepareForLearnedDataReset:)
                                                     name:MetasequoiaWillResetLearnedDataNotification
                                                   object:nil];
        for (NSNotificationName notificationName in @[
                 MetasequoiaFloatingToolbarDidChangeNotification,
                 @"MetasequoiaChinesePunctuationDidChangeNotification",
                 @"MetasequoiaEnglishInputModeDidChangeNotification",
                 @"MetasequoiaFullWidthInputDidChangeNotification",
                 MetasequoiaTraditionalChineseOutputDidChangeNotification,
             ])
        {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(floatingToolbarPreferenceDidChange:)
                                                         name:notificationName
                                                       object:nil];
        }
    }
    return self;
}

- (void)dealloc
{
    [_floatingToolbarPanel deactivateForDelegate:self];
    [_shuangpinKeymapPanel orderOut:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refreshFloatingToolbar
{
    [_floatingToolbarPanel
              updateEnglishInputMode:[MetasequoiaPreferencesWindowController storedEnglishInputMode]
        chinesePunctuationEnabled:[MetasequoiaPreferencesWindowController storedChinesePunctuationEnabled]
                 fullWidthEnabled:[MetasequoiaPreferencesWindowController storedFullWidthInputEnabled]
    traditionalChineseOutputEnabled:[MetasequoiaPreferencesWindowController storedTraditionalChineseOutputEnabled]];
    if (!_serverActive || _floatingToolbarPanel.toolbarDelegate != self)
    {
        return;
    }
    [_floatingToolbarPanel
        setVisible:[MetasequoiaPreferencesWindowController storedFloatingToolbarEnabled]
       forDelegate:self];
}

- (void)floatingToolbarPreferenceDidChange:(NSNotification *)notification
{
    [self refreshFloatingToolbar];
    if ([notification.name isEqualToString:MetasequoiaTraditionalChineseOutputDidChangeNotification] &&
        _serverActive && _session != nullptr && _session->has_composition())
    {
        [self refreshCandidatePanelPreservingSelection];
    }
}

- (void)prepareForLearnedDataReset:(NSNotification *)notification
{
    (void)notification;
    [self commitLeadingCandidate:self.client];
    _session.reset();
    _candidateSelection.reset();
    _candidateHighlightedIndex = 0;
    _candidatePageStart = 0;
    _candidateLineIdentifiersCollapsed = NO;
    _candidateData = @[];
    [_candidatePanel setCandidateData:_candidateData];
    [_candidatePanel hide];
    [_shuangpinKeymapPanel orderOut:nil];
    _dictionaryRetryAfter = 0.0;
}

- (void)reloadSessionFromPreferences
{
    const NSInteger storedScheme = [MetasequoiaPreferencesWindowController storedScheme];
    _shuangpinKeymapEnabled = [MetasequoiaPreferencesWindowController storedShuangpinKeymapEnabled];
    if (storedScheme != 1 || !_shuangpinKeymapEnabled)
    {
        [_shuangpinKeymapPanel orderOut:nil];
    }
    if (_session != nullptr && _session->has_composition())
    {
        return;
    }

    const SessionPreferences preferences = ReadSessionPreferences();
    [_candidatePanel setPanelType:metasequoia::mac::CandidatePanelTypeForStyle(preferences.candidatePanelStyle)];
    [_candidatePanel setSelectionKeys:metasequoia::mac::CandidateSelectionKeys(preferences.candidatePageSize)];
    [_candidatePanel setAttributes:metasequoia::mac::CandidatePanelAttributes(preferences.candidateFontSize)];
    _wubiAutoCommitUniqueEnabled = preferences.wubiAutoCommitUniqueEnabled;
    if (_session != nullptr && SessionMatchesPreferences(*_session, preferences))
    {
        return;
    }
    _session = std::make_unique<metasequoia::InputSession>(
        preferences.scheme, preferences.autocorrectEnabled, preferences.helpcodeEnabled,
        preferences.chinesePunctuationEnabled, preferences.candidateLearningEnabled);
    _candidateSelection.reset();
    _candidateHighlightedIndex = 0;
    _candidatePageStart = 0;
    _candidateLineIdentifiersCollapsed = NO;
    _candidateData = @[];
    [_candidatePanel setCandidateData:_candidateData];
    [_candidatePanel hide];
    [_shuangpinKeymapPanel orderOut:nil];
}

- (BOOL)prepareSessionIfNeeded
{
    if (_session != nullptr)
    {
        return YES;
    }

    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now < _dictionaryRetryAfter)
    {
        return NO;
    }

    NSError *error = nil;
    if (!EnsureMetasequoiaDictionary(&error))
    {
        _dictionaryRetryAfter = now + kDictionaryRetryDelay;
        NSLog(@"Failed to prepare the Metasequoia dictionary: %@", error.localizedDescription);
        return NO;
    }

    _dictionaryRetryAfter = 0.0;
    [self reloadSessionFromPreferences];
    return _session != nullptr;
}

- (void)activateServer:(id)sender
{
    [super activateServer:sender];
    _serverActive = YES;
    _dictionaryRetryAfter = 0.0;
    if (metasequoia::mac::ShouldPrepareInputSession(
            [MetasequoiaPreferencesWindowController storedEnglishInputMode]) &&
        [self prepareSessionIfNeeded])
    {
        [self reloadSessionFromPreferences];
    }
    [self refreshFloatingToolbar];
    [_floatingToolbarPanel
        activateForDelegate:self
                    visible:[MetasequoiaPreferencesWindowController storedFloatingToolbarEnabled]];
}

- (void)trackCandidateAtIndex:(NSUInteger)index
{
    if (_session == nullptr || index >= _candidateData.count || index >= _session->candidates().size())
    {
        return;
    }

    _candidateSelection.update(static_cast<size_t>(index), _session->candidates()[index].word);
    _candidateHighlightedIndex = index;
    _candidatePageStart = metasequoia::mac::CandidatePageStart(
        index, _candidateData.count, _candidatePanel.selectionKeys.count);
}

- (BOOL)selectCandidateAtIndex:(NSUInteger)index pageStart:(NSUInteger)pageStart
{
    if (index >= _candidateData.count || index < pageStart)
    {
        return NO;
    }

    const NSUInteger line = index - pageStart;
    const NSInteger identifier = [_candidatePanel candidateIdentifierAtLineNumber:static_cast<NSInteger>(line)];
    const NSInteger firstIdentifier = [_candidatePanel candidateIdentifierAtLineNumber:0];
    const NSInteger secondIdentifier = [_candidatePanel candidateIdentifierAtLineNumber:1];
    const NSUInteger candidatesOnPage = std::min(_candidatePanel.selectionKeys.count,
                                                  _candidateData.count - pageStart);
    if (candidatesOnPage >= 2 && firstIdentifier != NSNotFound && firstIdentifier == secondIdentifier)
    {
        _candidateLineIdentifiersCollapsed = YES;
    }
    const BOOL lineMappingIsUsable =
        !_candidateLineIdentifiersCollapsed && identifier != NSNotFound &&
        [_candidatePanel lineNumberForCandidateWithIdentifier:identifier] == static_cast<NSInteger>(line) &&
        (candidatesOnPage < 2 || (firstIdentifier != NSNotFound && secondIdentifier != NSNotFound &&
                                  firstIdentifier != secondIdentifier));

    if (lineMappingIsUsable)
    {
        if (![_candidatePanel selectCandidateWithIdentifier:identifier] ||
            ![[_candidatePanel selectedCandidateString].string
                isEqualToString:[_candidateData[index] string]])
        {
            return NO;
        }
        _candidateSelection.begin_navigation();
        [self trackCandidateAtIndex:index];
        return YES;
    }

    const NSInteger operatingSystemMajorVersion = NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
    if (_candidateLineIdentifiersCollapsed && operatingSystemMajorVersion == 26)
    {
        // macOS 26 can collapse every visible-line identifier to zero after setCandidateData:.
        // In that detected OS-specific failure mode the panel accepts the array ordinal.
        if ([_candidatePanel selectCandidateWithIdentifier:static_cast<NSInteger>(index)])
        {
            _candidateSelection.begin_navigation();
            [self trackCandidateAtIndex:index];
            return YES;
        }
    }
    return NO;
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender
{
    if (event.type != NSEventTypeKeyDown)
    {
        return NO;
    }
    const NSEventModifierFlags inputModeModifiers =
        event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    if (metasequoia::mac::ShouldToggleInputMode(
            [MetasequoiaPreferencesWindowController storedInputModeShortcutEnabled], event.keyCode,
            inputModeModifiers))
    {
        [self setEnglishInputMode:![MetasequoiaPreferencesWindowController storedEnglishInputMode] client:sender];
        return YES;
    }
    if ([MetasequoiaPreferencesWindowController storedEnglishInputMode])
    {
        [_shuangpinKeymapPanel orderOut:nil];
        return NO;
    }
    if (metasequoia::mac::IsFullWidthInputToggle(event.keyCode, inputModeModifiers))
    {
        [MetasequoiaPreferencesWindowController setFullWidthInputEnabled:
            ![MetasequoiaPreferencesWindowController storedFullWidthInputEnabled]];
        return YES;
    }
    if ([MetasequoiaPreferencesWindowController storedFullWidthInputEnabled] && event.characters.length == 1 &&
        metasequoia::mac::IsFullWidthDirectCharacter([event.characters characterAtIndex:0], inputModeModifiers))
    {
        const unichar character = [event.characters characterAtIndex:0];
        if (metasequoia::mac::IsFullWidthConvertibleCharacter(character) &&
            ((character >= 'A' && character <= 'Z') || (character >= 'a' && character <= 'z')) &&
            (_session == nullptr || !_session->has_composition()))
        {
            const unichar fullWidthCharacter = metasequoia::mac::FullWidthCharacter(character);
            NSString *converted = [NSString stringWithCharacters:&fullWidthCharacter length:1];
            [sender insertText:converted replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
            return YES;
        }
    }
    if (![self prepareSessionIfNeeded])
    {
        return NO;
    }

    [self reloadSessionFromPreferences];
    const NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    if ((modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption)) != 0)
    {
        [self commitLeadingCandidate:sender];
        return NO;
    }

    metasequoia::KeyResult result;
    const BOOL candidatePageShortcutModified =
        (modifiers & (NSEventModifierFlagShift | NSEventModifierFlagCommand | NSEventModifierFlagControl |
                      NSEventModifierFlagOption)) != 0;
    NSString *charactersIgnoringModifiers = event.charactersIgnoringModifiers;
    const char candidatePageShortcutCharacter =
        charactersIgnoringModifiers.length == 1 && [charactersIgnoringModifiers characterAtIndex:0] <= 0x7f
            ? static_cast<char>([charactersIgnoringModifiers characterAtIndex:0])
            : '\0';
    switch (metasequoia::mac::ClassifyControllerKey(
        event.keyCode, [_candidatePanel isVisible],
        metasequoia::mac::NormalizeCandidatePageShortcut(
            static_cast<int>([MetasequoiaPreferencesWindowController storedCandidatePageShortcut])),
        candidatePageShortcutCharacter, candidatePageShortcutModified))
    {
    case metasequoia::mac::ControllerKeyAction::MoveCandidateLeft:
        if (!metasequoia::mac::IsPrimaryCandidateDirection(event.keyCode, _candidatePanel.panelType))
        {
            return YES;
        }
        _candidateSelection.begin_navigation();
        [_candidatePanel moveLeft:self];
        if (_candidateHighlightedIndex > 0)
        {
            --_candidateHighlightedIndex;
        }
        [self trackCandidateAtIndex:_candidateHighlightedIndex];
        return YES;
    case metasequoia::mac::ControllerKeyAction::MoveCandidateRight:
        if (!metasequoia::mac::IsPrimaryCandidateDirection(event.keyCode, _candidatePanel.panelType))
        {
            return YES;
        }
        _candidateSelection.begin_navigation();
        [_candidatePanel moveRight:self];
        if (_candidateHighlightedIndex + 1 < _candidateData.count)
        {
            ++_candidateHighlightedIndex;
        }
        [self trackCandidateAtIndex:_candidateHighlightedIndex];
        return YES;
    case metasequoia::mac::ControllerKeyAction::MoveCandidateUp:
        if (!metasequoia::mac::IsPrimaryCandidateDirection(event.keyCode, _candidatePanel.panelType))
        {
            return YES;
        }
        _candidateSelection.begin_navigation();
        [_candidatePanel moveUp:self];
        if (_candidateHighlightedIndex > 0)
        {
            --_candidateHighlightedIndex;
        }
        [self trackCandidateAtIndex:_candidateHighlightedIndex];
        return YES;
    case metasequoia::mac::ControllerKeyAction::MoveCandidateDown:
        if (!metasequoia::mac::IsPrimaryCandidateDirection(event.keyCode, _candidatePanel.panelType))
        {
            return YES;
        }
        _candidateSelection.begin_navigation();
        [_candidatePanel moveDown:self];
        if (_candidateHighlightedIndex + 1 < _candidateData.count)
        {
            ++_candidateHighlightedIndex;
        }
        [self trackCandidateAtIndex:_candidateHighlightedIndex];
        return YES;
    case metasequoia::mac::ControllerKeyAction::MoveCandidatePageUp:
    {
        const NSUInteger pageSize = _candidatePanel.selectionKeys.count;
        if (pageSize == 0 || _candidatePageStart == 0)
        {
            return YES;
        }
        const NSUInteger targetPageStart = _candidatePageStart - pageSize;
        [_candidatePanel pageUp:self];
        if (![self selectCandidateAtIndex:targetPageStart pageStart:targetPageStart])
        {
            [_candidatePanel pageDown:self];
        }
        return YES;
    }
    case metasequoia::mac::ControllerKeyAction::MoveCandidatePageDown:
    {
        const NSUInteger pageSize = _candidatePanel.selectionKeys.count;
        if (pageSize == 0 || _candidatePageStart + pageSize >= _candidateData.count)
        {
            return YES;
        }
        const NSUInteger targetPageStart = _candidatePageStart + pageSize;
        [_candidatePanel pageDown:self];
        if (![self selectCandidateAtIndex:targetPageStart pageStart:targetPageStart])
        {
            [_candidatePanel pageUp:self];
        }
        return YES;
    }
    case metasequoia::mac::ControllerKeyAction::MoveCandidateHome:
        [self selectCandidateAtIndex:_candidatePageStart pageStart:_candidatePageStart];
        return YES;
    case metasequoia::mac::ControllerKeyAction::MoveCandidateEnd:
        [self selectCandidateAtIndex:metasequoia::mac::CandidatePageEnd(
                                         _candidatePageStart, _candidateData.count,
                                         _candidatePanel.selectionKeys.count)
                           pageStart:_candidatePageStart];
        return YES;
    case metasequoia::mac::ControllerKeyAction::Backspace:
        result = _session->handle_command(metasequoia::Command::Backspace);
        break;
    case metasequoia::mac::ControllerKeyAction::CommitRaw:
        result = _session->handle_command(metasequoia::Command::CommitRaw);
        break;
    case metasequoia::mac::ControllerKeyAction::Cancel:
        result = _session->handle_command(metasequoia::Command::Cancel);
        break;
    case metasequoia::mac::ControllerKeyAction::CommitCandidate:
        result = _candidateSelection.commit(*_session);
        break;
    case metasequoia::mac::ControllerKeyAction::Character:
    {
        NSString *characters = event.characters;
        if (characters.length == 1)
        {
            const unichar character = [characters characterAtIndex:0];
            if ((character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z'))
            {
                result = metasequoia::mac::HandleCharacterWithWubiAutoCommit(
                    *_session, static_cast<char>(character), _wubiAutoCommitUniqueEnabled);
            }
            else if (character == '\'' && _session->has_composition())
            {
                result = _session->handle_character(static_cast<char>(character));
            }
            else if (character >= '1' && character <= '9')
            {
                result = _candidateSelection.commit_number(
                    *_session, static_cast<char>(character), _candidatePanel.selectionKeys.count);
                if (!result.handled && _session->has_composition())
                {
                    return YES;
                }
            }
            else if (character == ',' || character == '.' || character == '?' || character == '!' ||
                     character == ';' || character == ':' || character == '"' || character == '\'' ||
                     character == '(' || character == ')' || character == '[' || character == ']' ||
                     character == '<' || character == '>' || character == '\\')
            {
                result = _session->handle_punctuation(static_cast<char>(character));
            }
        }
        break;
    }
    }

    if (!result.handled)
    {
        [self commitLeadingCandidate:sender];
        if (_session != nullptr && !_session->has_composition() &&
            [MetasequoiaPreferencesWindowController storedFullWidthInputEnabled] && event.characters.length == 1)
        {
            const unichar character = [event.characters characterAtIndex:0];
            if (metasequoia::mac::IsFullWidthConvertibleCharacter(character))
            {
                const unichar fullWidthCharacter = metasequoia::mac::FullWidthCharacter(character);
                NSString *converted = [NSString stringWithCharacters:&fullWidthCharacter length:1];
                [sender insertText:converted replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
                return YES;
            }
        }
        return NO;
    }
    [self applyResult:result client:sender];
    return YES;
}

- (void)commitLeadingCandidate:(id)sender
{
    if (_session == nullptr || !_session->has_composition())
    {
        return;
    }
    const auto result = _session->handle_command(metasequoia::Command::CommitCandidate);
    if (result.handled)
    {
        [self applyResult:result client:sender];
    }
}

- (void)applyResult:(const metasequoia::KeyResult &)result client:(id)sender
{
    id<IMKTextInput> client = sender;
    const NSRange replacementRange = NSMakeRange(NSNotFound, NSNotFound);
    if (result.commit.has_value())
    {
        const BOOL traditionalOutput =
            _session->scheme_type() != SchemeType::JapaneseRomaji &&
            [MetasequoiaPreferencesWindowController storedTraditionalChineseOutputEnabled];
        NSString *commit = MetasequoiaChineseOutputString(MetasequoiaStringFromUtf8(*result.commit),
                                                           traditionalOutput);
        [client insertText:commit replacementRange:replacementRange];
        _candidateSelection.reset();
        [_candidatePanel hide];
        [_shuangpinKeymapPanel orderOut:nil];
        return;
    }

    NSString *preedit = MetasequoiaStringFromUtf8(_session->preedit());
    [client setMarkedText:preedit selectionRange:NSMakeRange(preedit.length, 0) replacementRange:replacementRange];
    [self updateCandidatePanel];
    [self updateShuangpinKeymapPanelForClient:client];
}

- (void)updateShuangpinKeymapPanelForClient:(id<IMKTextInput>)client
{
    const BOOL hasComposition = _session != nullptr && _session->has_composition();
    const BOOL isShuangpin = _session != nullptr && _session->scheme_type() == SchemeType::Shuangpin;
    if (!MetasequoiaShouldShowShuangpinKeymap(isShuangpin, _shuangpinKeymapEnabled, hasComposition) ||
        client == nil)
    {
        [_shuangpinKeymapPanel orderOut:nil];
        return;
    }

    NSRect caretRect = NSZeroRect;
    [client attributesForCharacterIndex:0 lineHeightRectangle:&caretRect];
    if (!std::isfinite(NSMinX(caretRect)) || !std::isfinite(NSMinY(caretRect)) ||
        !std::isfinite(NSMaxX(caretRect)) || !std::isfinite(NSMaxY(caretRect)) ||
        NSHeight(caretRect) <= 0.0)
    {
        [_shuangpinKeymapPanel orderOut:nil];
        return;
    }

    NSString *preedit = MetasequoiaStringFromUtf8(_session->preedit());
    NSString *highlightedKey = @"";
    if (preedit.length > 0)
    {
        const unichar character = [preedit characterAtIndex:preedit.length - 1];
        if ((character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z'))
        {
            highlightedKey = [NSString stringWithCharacters:&character length:1];
        }
    }
    [_shuangpinKeymapPanel updateHighlightedKey:highlightedKey];

    const CGFloat fontSize = static_cast<CGFloat>(
        [MetasequoiaPreferencesWindowController storedCandidateFontSize]);
    CGFloat candidateClearance = fontSize + 42.0;
    if (_candidatePanel.panelType != kIMKSingleRowSteppingCandidatePanel)
    {
        const NSUInteger visibleCandidates = MIN(
            _candidateData.count,
            static_cast<NSUInteger>([MetasequoiaPreferencesWindowController storedCandidatePageSize]));
        candidateClearance = (fontSize + 10.0) * visibleCandidates + 24.0;
    }
    [_shuangpinKeymapPanel showNearCaretRect:caretRect candidateClearance:candidateClearance];
}

- (void)updateCandidatePanel
{
    [self rebuildCandidatePanelPreservingSelection:NO];
}

- (void)refreshCandidatePanelPreservingSelection
{
    [self rebuildCandidatePanelPreservingSelection:YES];
}

- (void)rebuildCandidatePanelPreservingSelection:(BOOL)preserveSelection
{
    const std::optional<size_t> preservedSelection =
        preserveSelection ? _candidateSelection.selected_index() : std::nullopt;
    if (!preserveSelection)
    {
        _candidateSelection.reset();
        _candidateHighlightedIndex = 0;
        _candidatePageStart = 0;
    }
    _candidateLineIdentifiersCollapsed = NO;
    NSMutableArray *data = [NSMutableArray arrayWithCapacity:_session->candidates().size()];
    const BOOL traditionalOutput =
        _session->scheme_type() != SchemeType::JapaneseRomaji &&
        [MetasequoiaPreferencesWindowController storedTraditionalChineseOutputEnabled];
    NSUInteger candidateIndex = 0;
    for (const WordItem &candidate : _session->candidates())
    {
        NSString *display = MetasequoiaStringFromUtf8(metasequoia::mac::CandidateDisplayText(
            candidate, _session->scheme_type(), _session->helpcode_enabled()));
        NSString *convertedDisplay = MetasequoiaChineseOutputString(display, traditionalOutput);
        [data addObject:MetasequoiaIndexedCandidateString(convertedDisplay, candidateIndex)];
        ++candidateIndex;
    }
    _candidateData = [data copy];
    [_candidatePanel setCandidateData:_candidateData];
    if (_session->has_composition() && _candidateData.count > 0)
    {
        [_candidatePanel show:kIMKLocateCandidatesBelowHint];
        if (_candidateData.count >= 2)
        {
            const NSInteger firstIdentifier = [_candidatePanel candidateIdentifierAtLineNumber:0];
            const NSInteger secondIdentifier = [_candidatePanel candidateIdentifierAtLineNumber:1];
            _candidateLineIdentifiersCollapsed =
                firstIdentifier != NSNotFound && firstIdentifier == secondIdentifier;
        }
        if (preservedSelection.has_value() && preservedSelection.value() < _candidateData.count)
        {
            const NSUInteger selectedIndex = static_cast<NSUInteger>(preservedSelection.value());
            const NSUInteger pageSize = _candidatePanel.selectionKeys.count;
            const NSUInteger selectedPageStart = metasequoia::mac::CandidatePageStart(
                selectedIndex, _candidateData.count, pageSize);
            _candidateHighlightedIndex = selectedIndex;
            _candidatePageStart = selectedPageStart;
            if (pageSize > 0)
            {
                for (NSUInteger pageStart = 0; pageStart < selectedPageStart; pageStart += pageSize)
                {
                    [_candidatePanel pageDown:self];
                }
            }
            [self selectCandidateAtIndex:selectedIndex pageStart:selectedPageStart];
        }
    }
    else
    {
        [_candidatePanel hide];
    }
}

- (NSArray *)candidates:(id)sender
{
    (void)sender;
    return _candidateData != nil ? _candidateData : @[];
}

- (void)candidateSelectionChanged:(NSAttributedString *)candidateString
{
    (void)candidateString;
}

- (void)candidateSelected:(NSAttributedString *)candidateString
{
    if (_session == nullptr)
    {
        return;
    }
    NSUInteger index = MetasequoiaCandidateIndex(candidateString);
    if (index == NSNotFound)
    {
        const NSInteger selectedIdentifier = [_candidatePanel selectedCandidate];
        NSUInteger identifierIndex = NSNotFound;
        if (selectedIdentifier != NSNotFound)
        {
            for (NSUInteger candidateIndex = 0; candidateIndex < _candidateData.count; ++candidateIndex)
            {
                if ([_candidatePanel candidateStringIdentifier:_candidateData[candidateIndex]] != selectedIdentifier)
                {
                    continue;
                }
                if (identifierIndex != NSNotFound)
                {
                    identifierIndex = NSNotFound;
                    break;
                }
                identifierIndex = candidateIndex;
            }
        }
        index = identifierIndex;
    }
    if (index == NSNotFound)
    {
        const NSInteger selectedIdentifier = [_candidatePanel selectedCandidate];
        const NSInteger selectedLine = selectedIdentifier == NSNotFound
                                           ? NSNotFound
                                           : [_candidatePanel lineNumberForCandidateWithIdentifier:selectedIdentifier];
        if (selectedLine != NSNotFound && selectedLine >= 0)
        {
            index = _candidatePageStart + static_cast<NSUInteger>(selectedLine);
        }
    }
    if (index == NSNotFound)
    {
        NSMutableArray<NSString *> *displayStrings = [NSMutableArray arrayWithCapacity:_candidateData.count];
        for (NSAttributedString *candidate in _candidateData)
        {
            [displayStrings addObject:candidate.string];
        }
        index = MetasequoiaUniqueStringIndex(displayStrings, candidateString.string);
    }
    if (index == NSNotFound || index >= _session->candidates().size())
    {
        return;
    }
    const auto result = _session->select_candidate(static_cast<size_t>(index));
    if (result.handled)
    {
        [self applyResult:result client:self.client];
    }
}

- (id)composedString:(id)sender
{
    (void)sender;
    return _session == nullptr ? @"" : MetasequoiaStringFromUtf8(_session->preedit());
}

- (NSAttributedString *)originalString:(id)sender
{
    (void)sender;
    NSString *raw = _session == nullptr ? @"" : MetasequoiaStringFromUtf8(_session->preedit());
    return [[NSAttributedString alloc] initWithString:raw];
}

- (void)commitComposition:(id)sender
{
    [self commitLeadingCandidate:sender];
}

- (void)deactivateServer:(id)sender
{
    _serverActive = NO;
    [_floatingToolbarPanel deactivateForDelegate:self];
    [self commitComposition:sender];
    [_candidatePanel hide];
    [_shuangpinKeymapPanel orderOut:nil];
    [super deactivateServer:sender];
}

- (void)showPreferences:(id)sender
{
    (void)sender;
    [[MetasequoiaPreferencesWindowController sharedController] showAndActivate];
}

- (void)checkForUpdates:(id)sender
{
    [[MetasequoiaUpdateController sharedController] checkForUpdates:sender];
}

- (void)setEnglishInputMode:(BOOL)enabled client:(id)sender
{
    if (enabled)
    {
        [self commitLeadingCandidate:sender];
    }
    _candidateSelection.reset();
    [_candidatePanel hide];
    [_shuangpinKeymapPanel orderOut:nil];
    [MetasequoiaPreferencesWindowController setEnglishInputMode:enabled];
}

- (void)floatingToolbarDidRequestToggleInputMode:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    [self setEnglishInputMode:![MetasequoiaPreferencesWindowController storedEnglishInputMode]
                       client:self.client];
}

- (void)floatingToolbarDidRequestTogglePunctuation:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    [self commitLeadingCandidate:self.client];
    [MetasequoiaPreferencesWindowController setChinesePunctuationEnabled:
        ![MetasequoiaPreferencesWindowController storedChinesePunctuationEnabled]];
    if (_session != nullptr)
    {
        [self reloadSessionFromPreferences];
    }
}

- (void)floatingToolbarDidRequestToggleFullWidth:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    [MetasequoiaPreferencesWindowController setFullWidthInputEnabled:
        ![MetasequoiaPreferencesWindowController storedFullWidthInputEnabled]];
}

- (void)floatingToolbarDidRequestToggleTraditionalOutput:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    [MetasequoiaPreferencesWindowController setTraditionalChineseOutputEnabled:
        ![MetasequoiaPreferencesWindowController storedTraditionalChineseOutputEnabled]];
}

- (void)floatingToolbarDidRequestOpenSettings:(MetasequoiaFloatingToolbarPanel *)toolbar
{
    (void)toolbar;
    [self showPreferences:nil];
}

- (void)selectChineseMode:(id)sender
{
    (void)sender;
    [self setEnglishInputMode:NO client:self.client];
}

- (void)selectEnglishMode:(id)sender
{
    (void)sender;
    [self setEnglishInputMode:YES client:self.client];
}

- (void)selectSimplifiedOutput:(id)sender
{
    (void)sender;
    [MetasequoiaPreferencesWindowController setTraditionalChineseOutputEnabled:NO];
}

- (void)selectTraditionalOutput:(id)sender
{
    (void)sender;
    [MetasequoiaPreferencesWindowController setTraditionalChineseOutputEnabled:YES];
}

- (NSMenu *)menu
{
    return CreateMetasequoiaInputMenu(
        self, [MetasequoiaPreferencesWindowController storedEnglishInputMode],
        [MetasequoiaPreferencesWindowController storedTraditionalChineseOutputEnabled]);
}

- (NSUInteger)recognizedEvents:(id)sender
{
    (void)sender;
    return NSEventMaskKeyDown;
}
@end
