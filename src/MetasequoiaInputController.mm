#import "MetasequoiaInputController.h"

#import "DictionaryInstaller.h"
#import "PreferencesWindowController.h"
#include "InputSession.h"

#import <Carbon/Carbon.h>

#include <memory>

namespace
{
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
};

SessionPreferences ReadSessionPreferences()
{
    const NSInteger storedScheme = [MetasequoiaPreferencesWindowController storedScheme];
    return {
        storedScheme == 1 ? SchemeType::Shuangpin : SchemeType::Quanpin,
        [MetasequoiaPreferencesWindowController storedAutocorrectEnabled] == YES,
        [MetasequoiaPreferencesWindowController storedHelpcodeEnabled] == YES,
        [MetasequoiaPreferencesWindowController storedChinesePunctuationEnabled] == YES,
    };
}

bool SessionMatchesPreferences(const metasequoia::mac::InputSession &session, const SessionPreferences &preferences)
{
    return session.scheme_type() == preferences.scheme &&
           session.quanpin_autocorrect_enabled() == preferences.autocorrectEnabled &&
           session.helpcode_enabled() == preferences.helpcodeEnabled &&
           session.chinese_punctuation_enabled() == preferences.chinesePunctuationEnabled;
}
} // namespace

@implementation MetasequoiaInputController
{
    std::unique_ptr<metasequoia::mac::InputSession> _session;
    IMKCandidates *_candidatePanel;
    NSArray *_candidateData;
}

- (instancetype)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient
{
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self != nil)
    {
        _candidatePanel = [[IMKCandidates alloc] initWithServer:server panelType:kIMKSingleRowSteppingCandidatePanel styleType:kIMKMain];
        [_candidatePanel setAttributes:@{IMKCandidatesSendServerKeyEventFirst: @NO}];

        NSError *error = nil;
        if (!EnsureMetasequoiaDictionary(&error))
        {
            NSLog(@"Failed to prepare the Metasequoia dictionary: %@", error.localizedDescription);
            return self;
        }
        [self reloadSessionFromPreferences];
    }
    return self;
}

- (void)reloadSessionFromPreferences
{
    const SessionPreferences preferences = ReadSessionPreferences();
    if (_session != nullptr &&
        (_session->has_composition() || SessionMatchesPreferences(*_session, preferences)))
    {
        return;
    }
    _session = std::make_unique<metasequoia::mac::InputSession>(
        preferences.scheme, preferences.autocorrectEnabled, preferences.helpcodeEnabled,
        preferences.chinesePunctuationEnabled);
    _candidateData = @[];
    [_candidatePanel setCandidateData:_candidateData];
}

- (void)activateServer:(id)sender
{
    [super activateServer:sender];
    if (_session == nullptr)
    {
        NSError *error = nil;
        if (!EnsureMetasequoiaDictionary(&error))
        {
            NSLog(@"Failed to prepare the Metasequoia dictionary: %@", error.localizedDescription);
            return;
        }
    }
    [self reloadSessionFromPreferences];
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender
{
    if (event.type != NSEventTypeKeyDown || _session == nullptr)
    {
        return NO;
    }

    const NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    if ((modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption)) != 0)
    {
        [self commitLeadingCandidate:sender];
        return NO;
    }

    metasequoia::mac::KeyResult result;
    switch (event.keyCode)
    {
    case kVK_Delete:
        result = _session->handle_command(metasequoia::mac::Command::Backspace);
        break;
    case kVK_Return:
    case kVK_ANSI_KeypadEnter:
        result = _session->handle_command(metasequoia::mac::Command::CommitRaw);
        break;
    case kVK_Escape:
        result = _session->handle_command(metasequoia::mac::Command::Cancel);
        break;
    case kVK_Space:
        result = _session->handle_command(metasequoia::mac::Command::CommitCandidate);
        break;
    default:
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
                result = _session->handle_candidate_key(static_cast<char>(character));
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
        [_candidatePanel hide];
        return;
    }

    NSString *preedit = StringFromUtf8(_session->preedit());
    [client setMarkedText:preedit selectionRange:NSMakeRange(preedit.length, 0) replacementRange:replacementRange];
    [self updateCandidatePanel];
}

- (void)updateCandidatePanel
{
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

- (NSUInteger)recognizedEvents:(id)sender
{
    (void)sender;
    return NSEventMaskKeyDown;
}
@end
