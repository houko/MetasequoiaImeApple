#import "MetasequoiaInputController.h"

#import "DictionaryInstaller.h"
#include "CandidateFontSize.h"
#include "CandidatePageSize.h"
#include "CandidatePanelStyle.h"
#import "InputMenu.h"
#include "InputModeRouting.h"
#import "PreferencesWindowController.h"
#include "CandidateSelectionState.h"
#include "InputControllerKeyRouting.h"
#include "InputSession.h"

#import <Carbon/Carbon.h>

#include <memory>

namespace
{
constexpr NSTimeInterval kDictionaryRetryDelay = 2.0;

NSString *StringFromUtf8(const std::string &value)
{
    return [[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding];
}

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
};

SessionPreferences ReadSessionPreferences()
{
    const NSInteger storedScheme = [MetasequoiaPreferencesWindowController storedScheme];
    return {
        storedScheme == 1 ? SchemeType::Shuangpin : SchemeType::Quanpin,
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
    };
}

bool SessionMatchesPreferences(const metasequoia::mac::InputSession &session, const SessionPreferences &preferences)
{
    return session.scheme_type() == preferences.scheme &&
           session.quanpin_autocorrect_enabled() == preferences.autocorrectEnabled &&
           session.helpcode_enabled() == preferences.helpcodeEnabled &&
           session.chinese_punctuation_enabled() == preferences.chinesePunctuationEnabled &&
           session.candidate_learning_enabled() == preferences.candidateLearningEnabled;
}
} // namespace

@implementation MetasequoiaInputController
{
    std::unique_ptr<metasequoia::mac::InputSession> _session;
    metasequoia::mac::CandidateSelectionState _candidateSelection;
    IMKCandidates *_candidatePanel;
    NSArray *_candidateData;
    NSUInteger _candidateHighlightedIndex;
    NSUInteger _candidatePageStart;
    BOOL _candidateLineIdentifiersCollapsed;
    NSTimeInterval _dictionaryRetryAfter;
}

- (instancetype)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient
{
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self != nil)
    {
        _candidatePanel = [[IMKCandidates alloc] initWithServer:server panelType:kIMKSingleRowSteppingCandidatePanel styleType:kIMKMain];
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
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    _dictionaryRetryAfter = 0.0;
}

- (void)reloadSessionFromPreferences
{
    if (_session != nullptr && _session->has_composition())
    {
        return;
    }

    const SessionPreferences preferences = ReadSessionPreferences();
    [_candidatePanel setPanelType:metasequoia::mac::CandidatePanelTypeForStyle(preferences.candidatePanelStyle)];
    [_candidatePanel setSelectionKeys:metasequoia::mac::CandidateSelectionKeys(preferences.candidatePageSize)];
    [_candidatePanel setAttributes:metasequoia::mac::CandidatePanelAttributes(preferences.candidateFontSize)];
    if (_session != nullptr && SessionMatchesPreferences(*_session, preferences))
    {
        return;
    }
    _session = std::make_unique<metasequoia::mac::InputSession>(
        preferences.scheme, preferences.autocorrectEnabled, preferences.helpcodeEnabled,
        preferences.chinesePunctuationEnabled, preferences.candidateLearningEnabled);
    _candidateSelection.reset();
    _candidateHighlightedIndex = 0;
    _candidatePageStart = 0;
    _candidateLineIdentifiersCollapsed = NO;
    _candidateData = @[];
    [_candidatePanel setCandidateData:_candidateData];
    [_candidatePanel hide];
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
    _dictionaryRetryAfter = 0.0;
    if (metasequoia::mac::ShouldPrepareInputSession(
            [MetasequoiaPreferencesWindowController storedEnglishInputMode]) &&
        [self prepareSessionIfNeeded])
    {
        [self reloadSessionFromPreferences];
    }
}

- (void)trackCandidateAtIndex:(NSUInteger)index
{
    if (index >= _candidateData.count)
    {
        return;
    }

    NSString *candidate = _candidateData[index];
    const char *utf8 = candidate.UTF8String;
    if (utf8 != nullptr)
    {
        _candidateSelection.update(static_cast<size_t>(index), utf8);
        _candidateHighlightedIndex = index;
        _candidatePageStart = metasequoia::mac::CandidatePageStart(
            index, _candidateData.count, _candidatePanel.selectionKeys.count);
    }
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
            ![[_candidatePanel selectedCandidateString].string isEqualToString:_candidateData[index]])
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
        return NO;
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

    metasequoia::mac::KeyResult result;
    switch (metasequoia::mac::ClassifyControllerKey(event.keyCode, [_candidatePanel isVisible]))
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
        result = _session->handle_command(metasequoia::mac::Command::Backspace);
        break;
    case metasequoia::mac::ControllerKeyAction::CommitRaw:
        result = _session->handle_command(metasequoia::mac::Command::CommitRaw);
        break;
    case metasequoia::mac::ControllerKeyAction::Cancel:
        result = _session->handle_command(metasequoia::mac::Command::Cancel);
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
                result = _session->handle_character(static_cast<char>(character));
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
    const auto result = _session->handle_command(metasequoia::mac::Command::CommitCandidate);
    if (result.handled)
    {
        [self applyResult:result client:sender];
    }
}

- (void)applyResult:(const metasequoia::mac::KeyResult &)result client:(id)sender
{
    id<IMKTextInput> client = sender;
    const NSRange replacementRange = NSMakeRange(NSNotFound, NSNotFound);
    if (result.commit.has_value())
    {
        [client insertText:StringFromUtf8(*result.commit) replacementRange:replacementRange];
        _candidateSelection.reset();
        [_candidatePanel hide];
        return;
    }

    NSString *preedit = StringFromUtf8(_session->preedit());
    [client setMarkedText:preedit selectionRange:NSMakeRange(preedit.length, 0) replacementRange:replacementRange];
    [self updateCandidatePanel];
}

- (void)updateCandidatePanel
{
    _candidateSelection.reset();
    _candidateHighlightedIndex = 0;
    _candidatePageStart = 0;
    _candidateLineIdentifiersCollapsed = NO;
    NSMutableArray *data = [NSMutableArray arrayWithCapacity:_session->candidates().size()];
    for (const WordItem &candidate : _session->candidates())
    {
        [data addObject:StringFromUtf8(candidate.word)];
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
    const char *utf8 = candidateString.string.UTF8String;
    if (utf8 == nullptr)
    {
        return;
    }
    const auto result = _session->select_candidate(utf8);
    if (result.handled)
    {
        [self applyResult:result client:self.client];
    }
}

- (id)composedString:(id)sender
{
    (void)sender;
    return _session == nullptr ? @"" : StringFromUtf8(_session->preedit());
}

- (NSAttributedString *)originalString:(id)sender
{
    (void)sender;
    NSString *raw = _session == nullptr ? @"" : StringFromUtf8(_session->preedit());
    return [[NSAttributedString alloc] initWithString:raw];
}

- (void)commitComposition:(id)sender
{
    [self commitLeadingCandidate:sender];
}

- (void)deactivateServer:(id)sender
{
    [self commitComposition:sender];
    [_candidatePanel hide];
    [super deactivateServer:sender];
}

- (void)showPreferences:(id)sender
{
    (void)sender;
    [[MetasequoiaPreferencesWindowController sharedController] showAndActivate];
}

- (void)setEnglishInputMode:(BOOL)enabled client:(id)sender
{
    if (enabled)
    {
        [self commitLeadingCandidate:sender];
    }
    _candidateSelection.reset();
    [_candidatePanel hide];
    [MetasequoiaPreferencesWindowController setEnglishInputMode:enabled];
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

- (NSMenu *)menu
{
    return CreateMetasequoiaInputMenu(self, [MetasequoiaPreferencesWindowController storedEnglishInputMode]);
}

- (NSUInteger)recognizedEvents:(id)sender
{
    (void)sender;
    return NSEventMaskKeyDown;
}
@end
