#pragma once

#include "InputSession.h"

#include <optional>
#include <string>
#include <utility>

namespace metasequoia::mac
{
class CandidateSelectionState
{
  public:
    void begin_navigation()
    {
        accepts_selection_changes_ = true;
        selected_candidate_.reset();
    }

    void update(std::string candidate)
    {
        if (accepts_selection_changes_)
        {
            selected_candidate_ = std::move(candidate);
        }
    }

    void reset()
    {
        accepts_selection_changes_ = false;
        selected_candidate_.reset();
    }

    KeyResult commit(InputSession &session) const
    {
        if (selected_candidate_.has_value())
        {
            const KeyResult selected = session.select_candidate(*selected_candidate_);
            if (selected.handled)
            {
                return selected;
            }
        }
        return session.handle_command(Command::CommitCandidate);
    }

  private:
    bool accepts_selection_changes_ = false;
    std::optional<std::string> selected_candidate_;
};
} // namespace metasequoia::mac
