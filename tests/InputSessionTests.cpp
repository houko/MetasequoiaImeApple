#include "../src/InputSession.h"
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

        type(session, "nihao");
        const auto digit = session.handle_candidate_key('2');
        require(digit.handled && digit.commit == "拟好", "The 2 key did not commit the second candidate.");

        metasequoia::mac::InputSession learned_session;
        type(learned_session, "nihao");
        require(!learned_session.candidates().empty() && learned_session.candidates().front().word == "拟好",
                "Selecting a candidate did not promote it for the next matching input.");

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
    }

    std::filesystem::remove_all(data_directory);
    return 0;
}
