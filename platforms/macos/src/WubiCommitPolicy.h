#pragma once

#include "core/input_session.h"

#include <cstddef>

namespace metasequoia::mac
{
inline bool ShouldAutoCommitUniqueWubiCandidate(bool enabled, SchemeType scheme, std::size_t codeLength,
                                                std::size_t candidateCount)
{
    return enabled && scheme == SchemeType::Wubi && codeLength == 4 && candidateCount == 1;
}

inline KeyResult HandleCharacterWithWubiAutoCommit(InputSession &session, char character, bool enabled)
{
    KeyResult result = session.handle_character(character);
    if (result.handled &&
        ShouldAutoCommitUniqueWubiCandidate(enabled, session.scheme_type(), session.preedit().size(),
                                            session.candidates().size()))
    {
        result = session.handle_command(Command::CommitCandidate);
    }
    return result;
}
} // namespace metasequoia::mac
