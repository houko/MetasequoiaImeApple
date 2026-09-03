#include "../src/InputControllerKeyRouting.h"

#import <InputMethodKit/InputMethodKit.h>

#include <Carbon/Carbon.h>

#include <initializer_list>
#include <stdexcept>
#include <utility>

namespace
{
void require(bool condition, const char *message)
{
    if (!condition)
    {
        throw std::runtime_error(message);
    }
}
} // namespace

int main()
{
    using metasequoia::mac::ControllerKeyAction;
    using metasequoia::mac::CandidatePageEnd;
    using metasequoia::mac::CandidatePageStart;
    using metasequoia::mac::ClassifyControllerKey;

    require(ClassifyControllerKey(kVK_Return, true) == ControllerKeyAction::CommitRaw,
            "Return did not remain a raw commit while candidates were visible.");
    require(ClassifyControllerKey(kVK_ANSI_KeypadEnter, true) == ControllerKeyAction::CommitRaw,
            "Keypad Enter did not remain a raw commit while candidates were visible.");
    require(ClassifyControllerKey(kVK_Space, true) == ControllerKeyAction::CommitCandidate,
            "Space did not remain a leading-candidate commit while candidates were visible.");
    require(ClassifyControllerKey(kVK_ANSI_2, true) == ControllerKeyAction::Character,
            "Number keys no longer reached controller-side candidate selection.");

    const std::initializer_list<std::pair<unsigned short, ControllerKeyAction>> navigationKeys = {
        {kVK_LeftArrow, ControllerKeyAction::MoveCandidateLeft},
        {kVK_RightArrow, ControllerKeyAction::MoveCandidateRight},
        {kVK_UpArrow, ControllerKeyAction::MoveCandidateUp},
        {kVK_DownArrow, ControllerKeyAction::MoveCandidateDown},
        {kVK_PageUp, ControllerKeyAction::MoveCandidatePageUp},
        {kVK_PageDown, ControllerKeyAction::MoveCandidatePageDown},
        {kVK_Home, ControllerKeyAction::MoveCandidateHome},
        {kVK_End, ControllerKeyAction::MoveCandidateEnd},
    };
    for (const auto &[keyCode, expectedAction] : navigationKeys)
    {
        require(ClassifyControllerKey(keyCode, true) == expectedAction,
                "A navigation key did not map to its candidate-panel command.");
        require(ClassifyControllerKey(keyCode, false) == ControllerKeyAction::Character,
                "A navigation key was swallowed while the candidate panel was hidden.");
    }
    require([IMKCandidates instancesRespondToSelector:@selector(moveLeft:)], "IMKCandidates does not support moveLeft:.");
    require([IMKCandidates instancesRespondToSelector:@selector(moveRight:)], "IMKCandidates does not support moveRight:.");
    require([IMKCandidates instancesRespondToSelector:@selector(moveUp:)], "IMKCandidates does not support moveUp:.");
    require([IMKCandidates instancesRespondToSelector:@selector(moveDown:)], "IMKCandidates does not support moveDown:.");
    require([IMKCandidates instancesRespondToSelector:@selector(pageUp:)], "IMKCandidates does not support pageUp:.");
    require([IMKCandidates instancesRespondToSelector:@selector(pageDown:)], "IMKCandidates does not support pageDown:.");
    require([IMKCandidates instancesRespondToSelector:@selector(candidateIdentifierAtLineNumber:)],
            "IMKCandidates cannot map visible lines to candidate identifiers.");
    require([IMKCandidates instancesRespondToSelector:@selector(lineNumberForCandidateWithIdentifier:)],
            "IMKCandidates cannot validate candidate identifiers against visible lines.");
    require([IMKCandidates instancesRespondToSelector:@selector(selectCandidateWithIdentifier:)],
            "IMKCandidates cannot select candidates by identifier.");
    require([IMKCandidates instancesRespondToSelector:@selector(selectedCandidateString)],
            "IMKCandidates cannot report the selected candidate contents.");

    require(CandidatePageStart(0, 20, 9) == 0 && CandidatePageEnd(0, 20, 9) == 8,
            "The first candidate page boundaries were incorrect.");
    require(CandidatePageStart(11, 20, 9) == 9 && CandidatePageEnd(11, 20, 9) == 17,
            "The middle candidate page boundaries were incorrect.");
    require(CandidatePageStart(19, 20, 9) == 18 && CandidatePageEnd(19, 20, 9) == 19,
            "The partial final candidate page boundaries were incorrect.");
    require(CandidatePageStart(100, 20, 9) == 18 && CandidatePageEnd(100, 20, 9) == 19,
            "An out-of-range selection was not clamped to the final candidate page.");
    require(CandidatePageStart(0, 0, 9) == 0 && CandidatePageEnd(0, 0, 9) == 0,
            "An empty candidate list did not retain safe page boundaries.");
    return 0;
}
