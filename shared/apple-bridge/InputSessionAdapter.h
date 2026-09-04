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

private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};
} // namespace metasequoia::apple
