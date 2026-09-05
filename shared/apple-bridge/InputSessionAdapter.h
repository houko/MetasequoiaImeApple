#pragma once

#include <cstddef>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace metasequoia::apple {
struct InputSnapshot {
  bool handled = false;
  std::optional<std::string> commit;
  std::string preedit;
  std::vector<std::string> candidates;
  // Set when the engine could answer the key but something behind it failed, such as a local input
  // mode whose table is missing or a word that could not be learned. Input stays usable, so a
  // frontend reports it rather than treating it as an error.
  std::optional<std::string> diagnostic;
};

class InputSessionAdapter {
public:
  InputSessionAdapter();
  ~InputSessionAdapter();

  InputSessionAdapter(const InputSessionAdapter &) = delete;
  InputSessionAdapter &operator=(const InputSessionAdapter &) = delete;

  InputSnapshot handle_character(char character);
  InputSnapshot handle_candidate_key(char character);
  InputSnapshot handle_punctuation(char character);
  InputSnapshot handle_backspace();
  InputSnapshot commit_candidate();
  InputSnapshot commit_raw();
  InputSnapshot cancel();
  InputSnapshot select_candidate(std::size_t index);
  InputSnapshot switch_to_shuangpin(bool uses_shuangpin);
  bool uses_shuangpin() const;

private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};
} // namespace metasequoia::apple
