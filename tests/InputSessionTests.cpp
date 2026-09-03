#include "../src/InputSession.h"
#include "../src/CandidateSelectionState.h"
#include "../vendor/MetasequoiaImeEngine/core/data_path.h"

#include <sqlite3.h>

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <stdexcept>
#include <string>

namespace
{
class Database
{
  public:
    explicit Database(const std::filesystem::path &path)
    {
        if (sqlite3_open(metasequoia::path_to_utf8(path).c_str(), &database_) != SQLITE_OK)
        {
            throw std::runtime_error("Failed to create the input-session test dictionary.");
        }
    }

    ~Database()
    {
        sqlite3_close(database_);
    }

    void execute(const char *sql)
    {
        char *error = nullptr;
        if (sqlite3_exec(database_, sql, nullptr, nullptr, &error) != SQLITE_OK)
        {
            const std::string message = error == nullptr ? "SQLite operation failed." : error;
            sqlite3_free(error);
            throw std::runtime_error(message);
        }
    }

  private:
    sqlite3 *database_ = nullptr;
};

void type(metasequoia::mac::InputSession &session, const std::string &text)
{
    for (const char character : text)
    {
        if (!session.handle_character(character).handled)
        {
            throw std::runtime_error("A pinyin character was not handled.");
        }
    }
}

void require(bool condition, const char *message)
{
    if (!condition)
    {
        throw std::runtime_error(message);
    }
}
} // namespace

int main()
{
    const auto suffix = std::to_string(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    const std::filesystem::path data_directory = std::filesystem::temp_directory_path() / std::filesystem::u8path("metasequoia-mac-词库-" + suffix);
    std::filesystem::create_directories(data_directory);
    if (setenv("METASEQUOIA_IME_DATA_DIR", metasequoia::path_to_utf8(data_directory).c_str(), 1) != 0)
    {
        throw std::runtime_error("Failed to set the test data directory.");
    }

    {
        Database database(data_directory / "msime.db");
        database.execute("CREATE TABLE tbl_2_n(key TEXT, jp TEXT, value TEXT, weight INTEGER)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '你好', 200)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '拟好', 100)");

        metasequoia::mac::InputSession default_session;
        require(default_session.scheme_type() == SchemeType::Quanpin, "The default input scheme should be full pinyin.");
        require(default_session.quanpin_autocorrect_enabled(), "Pinyin autocorrect should be enabled by default.");
        require(default_session.helpcode_enabled(), "Helpcode should be enabled by default.");
        metasequoia::mac::InputSession shuangpin_session(SchemeType::Shuangpin);
        require(shuangpin_session.scheme_type() == SchemeType::Shuangpin, "The requested double-pinyin scheme was not retained.");
        metasequoia::mac::InputSession no_autocorrect_session(SchemeType::Quanpin, false);
        require(!no_autocorrect_session.quanpin_autocorrect_enabled(), "The requested pinyin autocorrect setting was not retained.");
        metasequoia::mac::InputSession no_helpcode_session(SchemeType::Quanpin, true, false);
        require(!no_helpcode_session.helpcode_enabled(), "The requested helpcode setting was not retained.");
        metasequoia::mac::InputSession ascii_punctuation_session(SchemeType::Quanpin, true, true, false);
        require(!ascii_punctuation_session.chinese_punctuation_enabled(), "The requested punctuation setting was not retained.");
        require(!ascii_punctuation_session.handle_punctuation('.').handled, "Disabled Chinese punctuation swallowed ASCII punctuation.");

        metasequoia::mac::InputSession uppercase_session;
        require(!uppercase_session.handle_character('N').handled,
                "An uppercase letter was swallowed while no composition was active.");
        type(uppercase_session, "ni");
        require(!uppercase_session.handle_character('H').handled && uppercase_session.preedit() == "ni",
                "An uppercase letter entered the active pinyin composition.");
        uppercase_session.handle_command(metasequoia::mac::Command::Cancel);

        metasequoia::mac::InputSession session;
        type(session, "nihao");
        require(session.preedit() == "nihao", "The marked text did not mirror the raw pinyin.");
        require(session.candidates().size() >= 2, "The real engine did not return both SQLite candidates.");

        type(session, "nihao");
        const auto space = session.handle_command(metasequoia::mac::Command::CommitCandidate);
        require(space.handled && space.commit == "你好", "Space did not commit the leading candidate.");

        type(session, "nihao");
        const auto composed_punctuation = session.handle_punctuation(',');
        require(composed_punctuation.handled && composed_punctuation.commit == "你好，", "Punctuation did not commit the candidate atomically.");
        const auto idle_punctuation = session.handle_punctuation('.');
        require(idle_punctuation.handled && idle_punctuation.commit == "。", "Idle Chinese punctuation was not converted.");
        require(session.handle_punctuation('"').commit == "“" && session.handle_punctuation('"').commit == "”",
                "Double quotes did not alternate between opening and closing Chinese quotes.");
        require(session.handle_punctuation('\'').commit == "‘" && session.handle_punctuation('\'').commit == "’",
                "Single quotes did not alternate between opening and closing Chinese quotes.");
        require(session.handle_punctuation('(').commit == "（" && session.handle_punctuation(')').commit == "）",
                "Parentheses were not converted to Chinese punctuation.");
        require(session.handle_punctuation('[').commit == "【" && session.handle_punctuation(']').commit == "】",
                "Square brackets were not converted to Chinese punctuation.");
        require(session.handle_punctuation('<').commit == "《" && session.handle_punctuation('>').commit == "》",
                "Book-title brackets were not converted to Chinese punctuation.");
        require(session.handle_punctuation('\\').commit == "、", "The enumeration comma was not converted.");

        type(session, "ni");
        require(session.handle_character('\'').handled && session.preedit() == "ni'",
                "An apostrophe inside composition was not retained as a pinyin delimiter.");
        session.handle_command(metasequoia::mac::Command::Cancel);

        type(session, "nihao");
        const auto digit = session.handle_candidate_key('2');
        require(digit.handled && digit.commit == "拟好", "The 2 key did not commit the second candidate.");

        metasequoia::mac::InputSession learned_session;
        type(learned_session, "nihao");
        require(!learned_session.candidates().empty() && learned_session.candidates().front().word == "拟好",
                "Selecting a candidate did not promote it for the next matching input.");

        metasequoia::mac::CandidateSelectionState candidate_selection;
        metasequoia::mac::InputSession unarmed_selection_session;
        type(unarmed_selection_session, "nihao");
        const std::string initial_leading_candidate = unarmed_selection_session.candidates().front().word;
        candidate_selection.update(1, unarmed_selection_session.candidates()[1].word);
        const auto initial_selection = candidate_selection.commit(unarmed_selection_session);
        require(initial_selection.handled && initial_selection.commit == initial_leading_candidate,
                "An unsolicited candidate selection callback replaced the leading candidate.");

        metasequoia::mac::InputSession highlighted_session;
        type(highlighted_session, "nihao");
        const std::string highlighted_candidate = highlighted_session.candidates()[1].word;
        candidate_selection.begin_navigation();
        candidate_selection.update(1, highlighted_candidate);
        const auto highlighted = candidate_selection.commit(highlighted_session);
        require(highlighted.handled && highlighted.commit == highlighted_candidate,
                "Space did not commit the candidate highlighted by the native panel.");

        metasequoia::mac::InputSession leading_session;
        type(leading_session, "nihao");
        const std::string leading_candidate = leading_session.candidates().front().word;
        candidate_selection.begin_navigation();
        candidate_selection.update(1, leading_session.candidates()[1].word);
        candidate_selection.reset();
        const auto leading = candidate_selection.commit(leading_session);
        require(leading.handled && leading.commit == leading_candidate,
                "Clearing the native highlight did not restore leading-candidate commit.");

        metasequoia::mac::InputSession stale_selection_session;
        type(stale_selection_session, "nihao");
        const std::string stale_fallback_candidate = stale_selection_session.candidates().front().word;
        candidate_selection.begin_navigation();
        candidate_selection.update(1, "candidate-from-an-old-composition");
        const auto stale_fallback = candidate_selection.commit(stale_selection_session);
        require(stale_fallback.handled && stale_fallback.commit == stale_fallback_candidate,
                "A stale native highlight did not fall back to the leading candidate.");

        type(session, "nihao");
        const auto out_of_range_digit = session.handle_candidate_key('9');
        require(!out_of_range_digit.handled && session.preedit() == "nihao", "An out-of-range candidate key changed composition.");
        session.handle_command(metasequoia::mac::Command::Cancel);

        const auto idle_digit = session.handle_candidate_key('1');
        require(!idle_digit.handled, "A candidate key was swallowed while no composition was active.");

        type(session, "nihao");
        session.handle_command(metasequoia::mac::Command::Backspace);
        require(session.preedit() == "niha", "Backspace did not remove the last pinyin character.");
        const auto raw = session.handle_command(metasequoia::mac::Command::CommitRaw);
        require(raw.handled && raw.commit == "niha", "Return did not commit raw input.");

        type(session, "nihao");
        const auto cancel = session.handle_command(metasequoia::mac::Command::Cancel);
        require(cancel.handled && !cancel.commit.has_value() && session.preedit().empty(), "Escape did not cancel composition.");

        const auto idle_backspace = session.handle_command(metasequoia::mac::Command::Backspace);
        require(!idle_backspace.handled, "Backspace was swallowed while no composition was active.");

        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选三', 90)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选四', 80)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选五', 70)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选六', 60)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选七', 50)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选八', 40)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选九', 30)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选十', 20)");
        database.execute("INSERT INTO tbl_2_n VALUES('ni''hao', 'nh', '候选十一', 10)");

        metasequoia::mac::InputSession paged_session;
        type(paged_session, "nihao");
        require(paged_session.candidates().size() >= 11, "The paging test dictionary did not return enough candidates.");
        const std::string first_candidate_on_second_page = paged_session.candidates()[9].word;
        candidate_selection.begin_navigation();
        candidate_selection.update(9, first_candidate_on_second_page);
        const auto out_of_range_page_digit = candidate_selection.commit_number(paged_session, '9');
        require(!out_of_range_page_digit.handled && paged_session.has_composition(),
                "An unavailable number on the current candidate page changed composition.");
        const auto page_digit = candidate_selection.commit_number(paged_session, '1');
        require(page_digit.handled && page_digit.commit == first_candidate_on_second_page,
                "The 1 key did not commit the first candidate on the visible page.");

        metasequoia::mac::InputSession compact_page_session;
        type(compact_page_session, "nihao");
        const std::string compact_page_candidate = compact_page_session.candidates()[5].word;
        candidate_selection.begin_navigation();
        candidate_selection.update(5, compact_page_candidate);
        const auto compact_page_digit = candidate_selection.commit_number(compact_page_session, '1', 5);
        require(compact_page_digit.handled && compact_page_digit.commit == compact_page_candidate,
                "The 1 key did not use the configured five-candidate page boundary.");

        metasequoia::mac::InputSession hidden_compact_candidate_session;
        type(hidden_compact_candidate_session, "nihao");
        candidate_selection.reset();
        const auto hidden_compact_candidate =
            candidate_selection.commit_number(hidden_compact_candidate_session, '6', 5);
        require(!hidden_compact_candidate.handled && hidden_compact_candidate_session.has_composition(),
                "A number key selected a candidate hidden by the configured page size.");

        metasequoia::mac::InputSession middle_of_page_session;
        type(middle_of_page_session, "nihao");
        const std::string first_candidate_from_middle = middle_of_page_session.candidates()[9].word;
        candidate_selection.begin_navigation();
        candidate_selection.update(10, middle_of_page_session.candidates()[10].word);
        const auto middle_page_digit = candidate_selection.commit_number(middle_of_page_session, '1');
        require(middle_page_digit.handled && middle_page_digit.commit == first_candidate_from_middle,
                "A highlight in the middle of a page did not preserve that page for number selection.");

        metasequoia::mac::InputSession stale_page_session;
        type(stale_page_session, "nihao");
        const std::string stale_page_fallback = stale_page_session.candidates().front().word;
        candidate_selection.begin_navigation();
        candidate_selection.update(10, "candidate-from-an-old-composition");
        const auto stale_page_digit = candidate_selection.commit_number(stale_page_session, '1');
        require(stale_page_digit.handled && stale_page_digit.commit == stale_page_fallback,
                "A stale page highlight did not fall back to the first candidate page.");
    }

    std::filesystem::remove_all(data_directory);
    return 0;
}
