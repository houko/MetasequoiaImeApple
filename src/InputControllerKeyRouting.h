#pragma once

#include <Carbon/Carbon.h>

#include <algorithm>
#include <cstddef>

namespace metasequoia::mac
{
enum class ControllerKeyAction
{
    Character,
    MoveCandidateLeft,
    MoveCandidateRight,
    MoveCandidateUp,
    MoveCandidateDown,
    MoveCandidatePageUp,
    MoveCandidatePageDown,
    MoveCandidateHome,
    MoveCandidateEnd,
    Backspace,
    CommitRaw,
    Cancel,
    CommitCandidate,
};

constexpr size_t CandidatePageStart(size_t selectedIndex, size_t candidateCount, size_t pageSize)
{
    if (candidateCount == 0 || pageSize == 0)
    {
        return 0;
    }
    return std::min(selectedIndex, candidateCount - 1) / pageSize * pageSize;
}

constexpr size_t CandidatePageEnd(size_t selectedIndex, size_t candidateCount, size_t pageSize)
{
    if (candidateCount == 0 || pageSize == 0)
    {
        return 0;
    }
    return std::min(CandidatePageStart(selectedIndex, candidateCount, pageSize) + pageSize - 1,
                    candidateCount - 1);
}

constexpr ControllerKeyAction ClassifyControllerKey(unsigned short keyCode, bool candidatePanelVisible)
{
    if (candidatePanelVisible)
    {
        switch (keyCode)
        {
        case kVK_LeftArrow:
            return ControllerKeyAction::MoveCandidateLeft;
        case kVK_RightArrow:
            return ControllerKeyAction::MoveCandidateRight;
        case kVK_UpArrow:
            return ControllerKeyAction::MoveCandidateUp;
        case kVK_DownArrow:
            return ControllerKeyAction::MoveCandidateDown;
        case kVK_PageUp:
            return ControllerKeyAction::MoveCandidatePageUp;
        case kVK_PageDown:
            return ControllerKeyAction::MoveCandidatePageDown;
        case kVK_Home:
            return ControllerKeyAction::MoveCandidateHome;
        case kVK_End:
            return ControllerKeyAction::MoveCandidateEnd;
        default:
            break;
        }
    }

    switch (keyCode)
    {
    case kVK_Delete:
        return ControllerKeyAction::Backspace;
    case kVK_Return:
    case kVK_ANSI_KeypadEnter:
        return ControllerKeyAction::CommitRaw;
    case kVK_Escape:
        return ControllerKeyAction::Cancel;
    case kVK_Space:
        return ControllerKeyAction::CommitCandidate;
    default:
        return ControllerKeyAction::Character;
    }
}
} // namespace metasequoia::mac
