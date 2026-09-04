#include "InputSessionAdapter.h"

#include "core/input_session.h"

#include <utility>

namespace metasequoia::apple {
class InputSessionAdapter::Impl {
public:
  InputSession session{SchemeType::Quanpin, true, true, true, false};
};

namespace {
InputSnapshot MakeSnapshot(const InputSession &session, KeyResult result) {
  InputSnapshot snapshot;
  snapshot.handled = result.handled;
  snapshot.commit = std::move(result.commit);
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
} // namespace metasequoia::apple
