#include "../src/CandidateSelectionState.h"
#include "../../../vendor/MetasequoiaImeEngine/core/data_path.h"
#include "../../../vendor/MetasequoiaImeEngine/user_dictionary/user_dictionary_journal.h"

#include <sqlite3.h>

#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <stdexcept>
#include <string>

namespace {
class Database {
public:
  explicit Database(const std::filesystem::path &path) {
    if (sqlite3_open(metasequoia::path_to_utf8(path).c_str(), &database_) !=
        SQLITE_OK) {
      throw std::runtime_error(
          "Failed to create the candidate-selection test dictionary.");
    }
  }

  ~Database() { sqlite3_close(database_); }

  void execute(const char *sql) {
    char *error = nullptr;
    if (sqlite3_exec(database_, sql, nullptr, nullptr, &error) != SQLITE_OK) {
      const std::string message =
          error == nullptr ? "SQLite operation failed." : error;
      sqlite3_free(error);
      throw std::runtime_error(message);
    }
  }

private:
  sqlite3 *database_ = nullptr;
};

void type(metasequoia::InputSession &session, const std::string &text) {
  for (const char character : text) {
    if (!session.handle_character(character).handled) {
      throw std::runtime_error("A pinyin character was not handled.");
    }
  }
}

void require(bool condition, const char *message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

void run_tests() {
  metasequoia::mac::CandidateSelectionState candidate_selection;

  metasequoia::InputSession unarmed_session;
  type(unarmed_session, "nihao");
  const std::string leading_candidate =
      unarmed_session.candidates().front().word;
  candidate_selection.update(1, unarmed_session.candidates()[1].word);
  const auto unarmed = candidate_selection.commit(unarmed_session);
  require(unarmed.handled && unarmed.commit == leading_candidate,
          "An unsolicited panel callback replaced the leading candidate.");

  metasequoia::InputSession highlighted_session;
  type(highlighted_session, "nihao");
  const std::string highlighted_candidate =
      highlighted_session.candidates()[1].word;
  candidate_selection.begin_navigation();
  candidate_selection.update(1, highlighted_candidate);
  require(candidate_selection.selected_index() == 1,
          "The highlighted engine index was not available for a display-only refresh.");
  const auto highlighted = candidate_selection.commit(highlighted_session);
  require(
      highlighted.handled && highlighted.commit == highlighted_candidate,
      "Space did not commit the candidate highlighted by the native panel.");

  metasequoia::InputSession reset_session;
  type(reset_session, "nihao");
  const std::string reset_leading_candidate =
      reset_session.candidates().front().word;
  candidate_selection.begin_navigation();
  candidate_selection.update(1, reset_session.candidates()[1].word);
  candidate_selection.reset();
  require(!candidate_selection.selected_index().has_value(),
          "Reset retained a stale engine index.");
  const auto reset = candidate_selection.commit(reset_session);
  require(
      reset.handled && reset.commit == reset_leading_candidate,
      "Clearing the native highlight did not restore the leading candidate.");

  metasequoia::InputSession stale_session;
  type(stale_session, "nihao");
  const std::string stale_fallback = stale_session.candidates().front().word;
  candidate_selection.begin_navigation();
  candidate_selection.update(1, "candidate-from-an-old-composition");
  const auto stale = candidate_selection.commit(stale_session);
  require(
      stale.handled && stale.commit == stale_fallback,
      "A stale native highlight did not fall back to the leading candidate.");

  metasequoia::InputSession paged_session;
  type(paged_session, "nihao");
  require(paged_session.candidates().size() >= 11,
          "The paging fixture did not return enough candidates.");
  const std::string second_page_candidate = paged_session.candidates()[9].word;
  candidate_selection.begin_navigation();
  candidate_selection.update(9, second_page_candidate);
  const auto unavailable_digit =
      candidate_selection.commit_number(paged_session, '9');
  require(!unavailable_digit.handled && paged_session.has_composition(),
          "An unavailable number on the current page changed composition.");
  const auto page_digit = candidate_selection.commit_number(paged_session, '1');
  require(page_digit.handled && page_digit.commit == second_page_candidate,
          "The 1 key did not commit the first candidate on the visible page.");

  metasequoia::InputSession compact_page_session;
  type(compact_page_session, "nihao");
  const std::string compact_page_candidate =
      compact_page_session.candidates()[5].word;
  candidate_selection.begin_navigation();
  candidate_selection.update(5, compact_page_candidate);
  const auto compact_page_digit =
      candidate_selection.commit_number(compact_page_session, '1', 5);
  require(compact_page_digit.handled &&
              compact_page_digit.commit == compact_page_candidate,
          "The configured five-candidate page boundary was ignored.");
}
} // namespace

int main() {
  const auto suffix = std::to_string(
      std::chrono::high_resolution_clock::now().time_since_epoch().count());
  const std::filesystem::path data_directory =
      std::filesystem::temp_directory_path() /
      std::filesystem::u8path("metasequoia-mac-selection-" + suffix);
  std::filesystem::create_directories(data_directory);
  if (setenv("METASEQUOIA_IME_DATA_DIR",
             metasequoia::path_to_utf8(data_directory).c_str(), 1) != 0) {
    throw std::runtime_error("Failed to set the test data directory.");
  }

  try {
    {
      Database database(data_directory / "msime.db");
      database.execute("CREATE TABLE tbl_2_n(key TEXT, jp TEXT, value TEXT, "
                       "weight INTEGER)");
      database.execute("INSERT INTO tbl_2_n VALUES"
                       "('ni''hao', 'nh', '候选一', 110),"
                       "('ni''hao', 'nh', '候选二', 100),"
                       "('ni''hao', 'nh', '候选三', 90),"
                       "('ni''hao', 'nh', '候选四', 80),"
                       "('ni''hao', 'nh', '候选五', 70),"
                       "('ni''hao', 'nh', '候选六', 60),"
                       "('ni''hao', 'nh', '候选七', 50),"
                       "('ni''hao', 'nh', '候选八', 40),"
                       "('ni''hao', 'nh', '候选九', 30),"
                       "('ni''hao', 'nh', '候选十', 20),"
                       "('ni''hao', 'nh', '候选十一', 10)");
      run_tests();
    }
    user_dictionary::close_default_user_database();
    std::filesystem::remove_all(data_directory);
  } catch (...) {
    user_dictionary::close_default_user_database();
    std::filesystem::remove_all(data_directory);
    throw;
  }
  return 0;
}
