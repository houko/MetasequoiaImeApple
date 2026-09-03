#include "InputSession.h"

#include <algorithm>
#include <cctype>

namespace metasequoia::mac
{
InputSession::InputSession() : engine_(SchemeType::Quanpin)
{
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
    std::string text = index < candidates().size() ? candidates()[index].word : preedit();
    engine_.reset();
    return {true, std::move(text)};
}
} // namespace metasequoia::mac
