#pragma once

#include "../vendor/MetasequoiaImeEngine/core/ime_session.h"

#include <optional>
#include <string>

namespace metasequoia::mac
{
enum class Command
{
    Backspace,
    CommitCandidate,
    CommitRaw,
    Cancel,
};

struct KeyResult
{
    bool handled = false;
    std::optional<std::string> commit;
};

class InputSession
{
  public:
    explicit InputSession(SchemeType scheme_type = SchemeType::Quanpin);

    KeyResult handle_character(char character);
    KeyResult handle_command(Command command);
    KeyResult select_candidate(size_t index);
    KeyResult select_candidate(const std::string &candidate);

    SchemeType scheme_type() const;
    bool has_composition() const;
    const std::string &preedit() const;
    const std::vector<WordItem> &candidates() const;

  private:
    KeyResult commit(size_t index);

    ImeSession engine_;
};
} // namespace metasequoia::mac
