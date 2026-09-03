#pragma once

#include "CandidatePageSize.h"
#include "InputSession.h"

#include <cstddef>
#include <optional>
#include <string>
#include <utility>

namespace metasequoia::mac
{
class CandidateSelectionState
{
  public:
    static constexpr size_t candidates_per_page = 9;

    void begin_navigation()
    {
        accepts_selection_changes_ = true;
        selected_candidate_.reset();
    }

    void update(size_t candidate_index, std::string candidate)
    {
        if (accepts_selection_changes_)
        {
            selected_candidate_ = Selection{candidate_index, std::move(candidate)};
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
            const auto &candidates = session.candidates();
            if (selected_candidate_->index < candidates.size()
                && candidates[selected_candidate_->index].word == selected_candidate_->word)
            {
                const KeyResult selected = session.select_candidate(selected_candidate_->index);
                if (selected.handled)
                {
                    return selected;
                }
            }
        }
        return session.handle_command(Command::CommitCandidate);
    }

    KeyResult commit_number(InputSession &session, char character, size_t pageSize = candidates_per_page) const
    {
        if (character < '1' || character > '9')
        {
            return {};
        }

        pageSize = NormalizeCandidatePageSize(pageSize);
        const size_t candidateOffset = static_cast<size_t>(character - '1');
        if (candidateOffset >= pageSize)
        {
            return {};
        }

        const auto &candidates = session.candidates();
        if (!selected_candidate_.has_value() || selected_candidate_->index >= candidates.size()
            || candidates[selected_candidate_->index].word != selected_candidate_->word)
        {
            return session.handle_candidate_key(character);
        }

        const size_t pageStart = selected_candidate_->index / pageSize * pageSize;
        return session.select_candidate(pageStart + candidateOffset);
    }

  private:
    struct Selection
    {
        size_t index;
        std::string word;
    };

    bool accepts_selection_changes_ = false;
    std::optional<Selection> selected_candidate_;
};
} // namespace metasequoia::mac
