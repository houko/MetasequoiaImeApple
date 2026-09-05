// The controller only forwards a capital to the session when nothing is being composed and Shift is
// the only modifier. These tests pin the engine side of that arrangement: which capitals open a
// mode, that the rest stay unhandled so the application still inserts them, and that a disabled
// mode gives its trigger letter back.
#include "core/input_session.h"

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <stdexcept>
#include <string>

namespace {
void Require(bool condition, const char *message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

metasequoia::LocalModeOptions AppleOptions(bool enabled) {
  metasequoia::LocalModeOptions options;
  options.unicode = enabled;
  options.date_time = enabled;
  options.quick_phrase = enabled;
  options.super_jianpin = enabled;
  // These four read others.db, english.db and dict_japanese.dat, none of which this bundle fetches.
  options.emoji = false;
  options.kaomoji = false;
  options.temporary_english = false;
  options.temporary_japanese = false;
  return options;
}

int RunTest() {
  const std::filesystem::path dataDirectory =
      std::filesystem::temp_directory_path() /
      ("metasequoia-local-input-modes-" +
       std::to_string(
           std::chrono::high_resolution_clock::now().time_since_epoch().count()));
  std::filesystem::create_directories(dataDirectory);
  if (setenv("METASEQUOIA_IME_DATA_DIR", dataDirectory.c_str(), 1) != 0) {
    throw std::runtime_error("Failed to set the test data directory.");
  }

  {
    metasequoia::InputSession session;
    session.set_local_mode_options(AppleOptions(true));

    const auto unicode = session.handle_character('U', true);
    Require(unicode.handled && session.preedit() == "U",
            "Shift+U did not open the Unicode mode.");
    Require(session.local_input_mode() == metasequoia::LocalInputMode::Unicode,
            "Shift+U did not report the Unicode mode.");

    // The code point is hexadecimal, so the mode has to take digits as input. The controller routes
    // them here only while this mode is open; every other mode leaves digits to candidate numbers.
    Require(session.handle_character('4').handled && session.preedit() == "U4",
            "The Unicode mode rejected a hexadecimal digit.");
    Require(session.handle_command(metasequoia::Command::Cancel).handled,
            "Cancel did not close the Unicode mode.");
    Require(session.local_input_mode() == metasequoia::LocalInputMode::None,
            "Cancel left a local mode open.");
  }

  {
    metasequoia::InputSession session;
    session.set_local_mode_options(AppleOptions(true));

    // A capital that opens nothing has to come back unhandled, or the keyboard would swallow it
    // instead of letting the application insert it.
    const auto passthrough = session.handle_character('Z', true);
    Require(!passthrough.handled,
            "A capital that opens no mode was swallowed by the session.");
    Require(session.local_input_mode() == metasequoia::LocalInputMode::None,
            "A capital that opens no mode still changed the local mode.");

    // The four modes whose data this bundle does not ship must not open at all.
    for (const char trigger : {'E', 'M', 'Y', 'R'}) {
      const auto result = session.handle_character(trigger, true);
      Require(!result.handled,
              "A local mode without packaged data was opened by its trigger.");
      Require(session.local_input_mode() == metasequoia::LocalInputMode::None,
              "A local mode without packaged data reported itself as open.");
    }
  }

  {
    metasequoia::InputSession session;
    session.set_local_mode_options(AppleOptions(false));

    // With the preference off the trigger is an ordinary capital again.
    const auto disabled = session.handle_character('U', true);
    Require(!disabled.handled,
            "Shift+U opened the Unicode mode while local modes were disabled.");
    Require(session.local_input_mode() == metasequoia::LocalInputMode::None,
            "A disabled local mode still opened.");
  }

  {
    metasequoia::InputSession session;
    session.set_local_mode_options(AppleOptions(true));

    // The engine guards every trigger on there being no composition, which is the same condition
    // the controller checks before forwarding a capital at all.
    Require(session.handle_character('n').handled, "The guard fixture did not start a composition.");
    const auto duringComposition = session.handle_character('U', true);
    Require(session.local_input_mode() == metasequoia::LocalInputMode::None,
            "A trigger opened a local mode on top of a live composition.");
    (void)duringComposition;
  }

  std::filesystem::remove_all(dataDirectory);
  return 0;
}
} // namespace

int main() {
  try {
    return RunTest();
  } catch (const std::exception &exception) {
    std::fprintf(stderr, "%s\n", exception.what());
    return 1;
  }
}
