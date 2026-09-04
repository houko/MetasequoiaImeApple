#pragma once

#include "common/helpcode_utils.h"
#include "core/scheme_type.h"
#include "core/word_item.h"

#include <string>

namespace metasequoia::mac
{
inline std::string CandidateDisplayText(const WordItem &candidate, SchemeType scheme, bool helpcodeEnabled)
{
    if (!helpcodeEnabled || (scheme != SchemeType::Quanpin && scheme != SchemeType::Shuangpin))
    {
        return candidate.word;
    }
    return candidate.word + HelpcodeUtils::compute_helpcodes(candidate.word);
}
} // namespace metasequoia::mac
