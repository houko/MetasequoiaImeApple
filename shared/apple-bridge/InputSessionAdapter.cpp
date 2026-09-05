#include "InputSessionAdapter.h"

#include "core/input_session.h"

#include <utility>

namespace metasequoia::apple {
class InputSessionAdapter::Impl {
public:
  explicit Impl(SchemeType scheme = SchemeType::Quanpin)
      : session{scheme, true, true, true, false} {}

  InputSession session;
};

namespace {
InputSnapshot MakeSnapshot(const InputSession &session, KeyResult result) {
  InputSnapshot snapshot;
  snapshot.handled = result.handled;
  snapshot.commit = std::move(result.commit);
  snapshot.diagnostic = std::move(result.diagnostic);
  snapshot.preedit = session.preedit();
  snapshot.candidates.reserve(session.candidates().size());
  for (const auto &candidate : session.candidates()) {
    snapshot.candidates.push_back(candidate.word);
  }
  return snapshot;
}
} // namespace

InputSessionAdapter::InputSessionAdapter() : impl_(std::make_unique<Impl>()) {}

InputSessionAdapter::~InputSessionAdapter() = default;

InputSnapshot InputSessionAdapter::handle_character(char character) {
  // The engine accepts A-Z during a composition as helpcode input, which no Apple frontend offers.
  // Reject it here so an uppercase letter stays unhandled and the frontend passes it to the client,
  // matching what core/input_session.h still documents and what the macOS controller does.
  if (character >= 'A' && character <= 'Z') {
    return MakeSnapshot(impl_->session, KeyResult{});
  }
  return MakeSnapshot(impl_->session,
                      impl_->session.handle_character(character));
}

InputSnapshot InputSessionAdapter::handle_candidate_key(char character) {
  return MakeSnapshot(impl_->session,
                      impl_->session.handle_candidate_key(character));
}

InputSnapshot InputSessionAdapter::handle_punctuation(char character) {
  return MakeSnapshot(impl_->session,
                      impl_->session.handle_punctuation(character));
}

InputSnapshot InputSessionAdapter::handle_backspace() {
  return MakeSnapshot(impl_->session,
                      impl_->session.handle_command(Command::Backspace));
}

InputSnapshot InputSessionAdapter::commit_candidate() {
  return MakeSnapshot(impl_->session,
                      impl_->session.handle_command(Command::CommitCandidate));
}

InputSnapshot InputSessionAdapter::commit_raw() {
  return MakeSnapshot(impl_->session,
                      impl_->session.handle_command(Command::CommitRaw));
}

InputSnapshot InputSessionAdapter::cancel() {
  return MakeSnapshot(impl_->session,
                      impl_->session.handle_command(Command::Cancel));
}

InputSnapshot InputSessionAdapter::select_candidate(std::size_t index) {
  return MakeSnapshot(impl_->session, impl_->session.select_candidate(index));
}

InputSnapshot InputSessionAdapter::switch_to_shuangpin(bool uses_shuangpin) {
  if (uses_shuangpin == this->uses_shuangpin()) {
    return MakeSnapshot(impl_->session, {});
  }
  const auto result = impl_->session.finish_composition();
  auto snapshot = MakeSnapshot(impl_->session, result);
  const auto scheme =
      uses_shuangpin ? SchemeType::Shuangpin : SchemeType::Quanpin;
  impl_ = std::make_unique<Impl>(scheme);
  return snapshot;
}

bool InputSessionAdapter::uses_shuangpin() const {
  return impl_->session.scheme_type() == SchemeType::Shuangpin;
}
} // namespace metasequoia::apple
