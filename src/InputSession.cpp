#include "InputSession.h"

#include <algorithm>
#include <cctype>

namespace metasequoia::mac
{
InputSession::InputSession(SchemeType scheme_type, bool quanpin_autocorrect_enabled, bool helpcode_enabled,
                           bool chinese_punctuation_enabled)
    : engine_(scheme_type), quanpin_autocorrect_enabled_(quanpin_autocorrect_enabled), helpcode_enabled_(helpcode_enabled),
      chinese_punctuation_enabled_(chinese_punctuation_enabled)
{
    engine_.set_quanpin_autocorrect_enabled(quanpin_autocorrect_enabled_);
    engine_.set_quanpin_helpcode_enabled(helpcode_enabled_);
    engine_.set_shuangpin_helpcode_enabled(helpcode_enabled_);
}

KeyResult InputSession::handle_character(char character)
{
    const auto unsigned_character = static_cast<unsigned char>(character);
    if (!std::isalpha(unsigned_character) && character != '\'')
    {
        return {};
    }

    const ImeKeyCode key_code = character == '\'' ? ImeKey::Apostrophe : static_cast<ImeKeyCode>(std::toupper(unsigned_character));
    engine_.handle_key(key_code, 0, static_cast<ImeCharacter>(unsigned_character));
    return {true, std::nullopt};
}

KeyResult InputSession::handle_candidate_key(char character)
{
    if (!has_composition() || character < '1' || character > '9')
    {
        return {};
    }
    return select_candidate(static_cast<size_t>(character - '1'));
}

KeyResult InputSession::handle_punctuation(char character)
{
    if (!chinese_punctuation_enabled_)
    {
        return {};
    }

    const char *punctuation = nullptr;
    switch (character)
    {
    case ',':
        punctuation = "，";
        break;
    case '.':
        punctuation = "。";
        break;
    case '?':
        punctuation = "？";
        break;
    case '!':
        punctuation = "！";
        break;
    case ';':
        punctuation = "；";
        break;
    case ':':
        punctuation = "：";
        break;
    default:
        return {};
    }

    std::string text;
    if (has_composition())
    {
        if (candidates().empty())
        {
            text = preedit();
        }
        else
        {
            const WordItem candidate = candidates().front();
            text = candidate.word;
            learn_candidate(candidate);
        }
        engine_.reset();
    }
    text += punctuation;
    return {true, std::move(text)};
}

KeyResult InputSession::handle_command(Command command)
{
    if (!has_composition())
    {
        return {};
    }

    switch (command)
    {
    case Command::Backspace:
        engine_.handle_key(ImeKey::Backspace);
        return {true, std::nullopt};
    case Command::CommitCandidate:
        return commit(0);
    case Command::CommitRaw:
    {
        std::string raw = preedit();
        engine_.reset();
        return {true, std::move(raw)};
    }
    case Command::Cancel:
        engine_.reset();
        return {true, std::nullopt};
    }
    return {};
}

KeyResult InputSession::select_candidate(size_t index)
{
    if (!has_composition() || index >= candidates().size())
    {
        return {};
    }
    return commit(index);
}

KeyResult InputSession::select_candidate(const std::string &candidate)
{
    const auto found = std::find_if(candidates().begin(), candidates().end(), [&](const WordItem &item) { return item.word == candidate; });
    if (found == candidates().end())
    {
        return {};
    }
    return commit(static_cast<size_t>(std::distance(candidates().begin(), found)));
}

SchemeType InputSession::scheme_type() const
{
    return engine_.current_scheme_type();
}

bool InputSession::quanpin_autocorrect_enabled() const
{
    return quanpin_autocorrect_enabled_;
}

bool InputSession::helpcode_enabled() const
{
    return helpcode_enabled_;
}

bool InputSession::chinese_punctuation_enabled() const
{
    return chinese_punctuation_enabled_;
}

bool InputSession::has_composition() const
{
    return !preedit().empty();
}

const std::string &InputSession::preedit() const
{
    return engine_.get_preedit();
}

const std::vector<WordItem> &InputSession::candidates() const
{
    return engine_.get_candidates();
}

KeyResult InputSession::commit(size_t index)
{
    if (index >= candidates().size())
    {
        std::string text = preedit();
        engine_.reset();
        return {true, std::move(text)};
    }

    const WordItem candidate = candidates()[index];
    std::string text = candidate.word;
    learn_candidate(candidate);
    engine_.reset();
    return {true, std::move(text)};
}

void InputSession::learn_candidate(const WordItem &candidate)
{
    if (candidate.source != CandidateSource::Database && candidate.source != CandidateSource::UserDatabase)
    {
        return;
    }

    const std::string &pinyin = candidate.canonical_pinyin.empty() ? candidate.pinyin : candidate.canonical_pinyin;
    (void)engine_.update_weight_by_pinyin_and_word(pinyin, candidate.word);
}
} // namespace metasequoia::mac
