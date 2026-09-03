#include "../src/InputControllerKeyRouting.h"
#include "../src/CandidatePanelStyle.h"
#include "../src/CandidatePageSize.h"
#include "../src/InputModeRouting.h"

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
    using metasequoia::mac::CandidatePanelStyle;
    using metasequoia::mac::CandidatePanelTypeForStyle;
    using metasequoia::mac::CandidatePageSizeForOptionIndex;
    using metasequoia::mac::CandidatePageSizeOptionIndex;
    using metasequoia::mac::CandidateSelectionKeys;
    using metasequoia::mac::ClassifyControllerKey;
    using metasequoia::mac::IsPrimaryCandidateDirection;
    using metasequoia::mac::NormalizeCandidatePageSize;
    using metasequoia::mac::NormalizeCandidatePanelStyle;
    using metasequoia::mac::IsInputModeToggle;

    require(IsInputModeToggle(kVK_Space, NSEventModifierFlagShift),
            "Shift+Space did not map to input-mode switching.");
    require(!IsInputModeToggle(kVK_Space, 0) &&
                !IsInputModeToggle(kVK_ANSI_A, NSEventModifierFlagShift) &&
                !IsInputModeToggle(kVK_Space, NSEventModifierFlagShift | NSEventModifierFlagCommand),
            "A non-toggle shortcut unexpectedly mapped to input-mode switching.");
    require(metasequoia::mac::ShouldPrepareInputSession(false) &&
                !metasequoia::mac::ShouldPrepareInputSession(true),
            "Direct English mode did not bypass input-session preparation.");

    require(NormalizeCandidatePanelStyle(0) == CandidatePanelStyle::Horizontal &&
                NormalizeCandidatePanelStyle(1) == CandidatePanelStyle::Vertical &&
                NormalizeCandidatePanelStyle(99) == CandidatePanelStyle::Horizontal,
            "The stored candidate layout was not normalized safely.");
    require(CandidatePanelTypeForStyle(CandidatePanelStyle::Horizontal) == kIMKSingleRowSteppingCandidatePanel &&
                CandidatePanelTypeForStyle(CandidatePanelStyle::Vertical) == kIMKSingleColumnScrollingCandidatePanel,
            "The candidate layout preference did not map to the expected native panel types.");
    require(IsPrimaryCandidateDirection(kVK_LeftArrow, kIMKSingleRowSteppingCandidatePanel) &&
                IsPrimaryCandidateDirection(kVK_RightArrow, kIMKSingleRowSteppingCandidatePanel) &&
                !IsPrimaryCandidateDirection(kVK_UpArrow, kIMKSingleRowSteppingCandidatePanel) &&
                !IsPrimaryCandidateDirection(kVK_DownArrow, kIMKSingleRowSteppingCandidatePanel),
            "The horizontal candidate panel did not restrict navigation to its primary axis.");
    require(!IsPrimaryCandidateDirection(kVK_LeftArrow, kIMKSingleColumnScrollingCandidatePanel) &&
                !IsPrimaryCandidateDirection(kVK_RightArrow, kIMKSingleColumnScrollingCandidatePanel) &&
                IsPrimaryCandidateDirection(kVK_UpArrow, kIMKSingleColumnScrollingCandidatePanel) &&
                IsPrimaryCandidateDirection(kVK_DownArrow, kIMKSingleColumnScrollingCandidatePanel),
            "The vertical candidate panel did not restrict navigation to its primary axis.");
    require(NormalizeCandidatePageSize(5) == 5 && NormalizeCandidatePageSize(7) == 7 &&
                NormalizeCandidatePageSize(9) == 9 && NormalizeCandidatePageSize(0) == 9 &&
                NormalizeCandidatePageSize(99) == 9,
            "The stored candidate page size was not normalized safely.");
    require(CandidatePageSizeForOptionIndex(0) == 5 && CandidatePageSizeForOptionIndex(1) == 7 &&
                CandidatePageSizeForOptionIndex(2) == 9 && CandidatePageSizeForOptionIndex(99) == 9 &&
                CandidatePageSizeOptionIndex(5) == 0 && CandidatePageSizeOptionIndex(7) == 1 &&
                CandidatePageSizeOptionIndex(9) == 2,
            "The candidate page-size options did not map to persisted values.");
    NSArray<NSNumber *> *fiveSelectionKeys = CandidateSelectionKeys(5);
    NSArray<NSNumber *> *nineSelectionKeys = CandidateSelectionKeys(9);
    require(fiveSelectionKeys.count == 5 && nineSelectionKeys.count == 9 &&
                fiveSelectionKeys.firstObject.unsignedShortValue == kVK_ANSI_1 &&
                fiveSelectionKeys.lastObject.unsignedShortValue == kVK_ANSI_5 &&
                nineSelectionKeys.lastObject.unsignedShortValue == kVK_ANSI_9,
            "The candidate page size did not produce the expected number-key mappings.");

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
