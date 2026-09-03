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
    explicit InputSession(SchemeType scheme_type = SchemeType::Quanpin, bool quanpin_autocorrect_enabled = true,
                          bool helpcode_enabled = true, bool chinese_punctuation_enabled = true);

    KeyResult handle_character(char character);
    KeyResult handle_candidate_key(char character);
    KeyResult handle_punctuation(char character);
    KeyResult handle_command(Command command);
    KeyResult select_candidate(size_t index);
    KeyResult select_candidate(const std::string &candidate);

    SchemeType scheme_type() const;
    bool quanpin_autocorrect_enabled() const;
    bool helpcode_enabled() const;
    bool chinese_punctuation_enabled() const;
    bool has_composition() const;
    const std::string &preedit() const;
    const std::vector<WordItem> &candidates() const;

  private:
    KeyResult commit(size_t index);
    void learn_candidate(const WordItem &candidate);

    ImeSession engine_;
    bool quanpin_autocorrect_enabled_ = true;
    bool helpcode_enabled_ = true;
    bool chinese_punctuation_enabled_ = true;
    bool next_double_quote_is_opening_ = true;
    bool next_single_quote_is_opening_ = true;
};
} // namespace metasequoia::mac
