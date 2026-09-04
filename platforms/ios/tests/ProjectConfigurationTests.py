import plistlib
import unittest
from pathlib import Path


IOS_ROOT = Path(__file__).resolve().parents[1]


class ProjectConfigurationTests(unittest.TestCase):
    def test_project_defines_distinct_host_and_keyboard_identifiers(self):
        project = (IOS_ROOT / "project.yml").read_text()

        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER: com.houko.metasequoiaime.ios\n", project)
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER: com.houko.metasequoiaime.ios.keyboard\n", project)
        self.assertIn("deploymentTarget:\n    iOS: \"15.0\"", project)

    def test_keyboard_is_local_and_declares_the_system_extension_contract(self):
        with (IOS_ROOT / "KeyboardExtension/Resources/Info.plist").open("rb") as info_file:
            info = plistlib.load(info_file)

        extension = info["NSExtension"]
        attributes = extension["NSExtensionAttributes"]
        self.assertEqual(extension["NSExtensionPointIdentifier"], "com.apple.keyboard-service")
        self.assertEqual(extension["NSExtensionPrincipalClass"], "$(PRODUCT_MODULE_NAME).KeyboardViewController")
        self.assertEqual(attributes["PrimaryLanguage"], "zh-Hans")
        self.assertFalse(attributes["RequestsOpenAccess"])

    def test_keyboard_exposes_required_document_and_next_keyboard_actions(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("textDocumentProxy.insertText", controller)
        self.assertIn("textDocumentProxy.deleteBackward", controller)
        self.assertIn("handleInputModeList(from:", controller)
        self.assertNotIn("URLSession", controller)

    def test_onboarding_exposes_a_regular_text_field_for_keyboard_tryout(self):
        onboarding = (IOS_ROOT / "App/Sources/OnboardingView.swift").read_text()

        self.assertIn('TextField("在这里试试水杉键盘"', onboarding)
        self.assertIn('.accessibilityIdentifier("keyboardTryoutField")', onboarding)

    def test_ci_creates_the_generated_project_output_directory(self):
        workflow = (IOS_ROOT.parents[1] / ".github/workflows/ci.yml").read_text()

        self.assertIn("mkdir -p build/ios", workflow)

    def test_keyboard_routes_composition_through_the_shared_engine_bridge(self):
        project = (IOS_ROOT / "project.yml").read_text()
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("MetasequoiaAppleBridge:", project)
        self.assertIn("shared/apple-bridge", project)
        self.assertIn("vendor/MetasequoiaImeEngine/core", project)
        self.assertIn("MetasequoiaInputSessionBridge", controller)
        self.assertIn("session.handleCharacter", controller)
        self.assertIn("session.commitCandidate", controller)

    def test_keyboard_packages_the_compact_dictionary(self):
        project = (IOS_ROOT / "project.yml").read_text()
        workflow = (IOS_ROOT.parents[1] / ".github/workflows/ci.yml").read_text()

        self.assertIn("platforms/ios/KeyboardExtension/Resources/msime.db", project)
        self.assertIn("platforms/ios/KeyboardExtension/Resources/msime.db.sha256", project)
        self.assertIn("python3 platforms/ios/scripts/prepare_dictionary.py", workflow)

    def test_bridge_installs_the_bundled_dictionary_before_engine_startup(self):
        bridge = (IOS_ROOT.parents[1] / "shared/apple-bridge/MetasequoiaInputSessionBridge.mm").read_text()

        self.assertIn('URLForResource:@"msime" withExtension:@"db"', bridge)
        self.assertIn('URLForResource:@"msime.db" withExtension:@"sha256"', bridge)
        self.assertIn('setenv("METASEQUOIA_IME_DATA_DIR"', bridge)

    def test_keyboard_exposes_engine_owned_number_and_punctuation_routing(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()
        bridge_header = (IOS_ROOT.parents[1] / "shared/apple-bridge/MetasequoiaInputSessionBridge.h").read_text()

        self.assertIn("symbolRows", controller)
        self.assertIn("toggleLayout", controller)
        self.assertIn("session.handleCandidateKey", controller)
        self.assertIn("session.handlePunctuation", controller)
        self.assertIn("handleCandidateKey", bridge_header)
        self.assertIn("handlePunctuation", bridge_header)

    def test_candidate_surface_exposes_numbered_native_chips(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("makeCandidateButton(candidate: candidate, number: index + 1)", controller)
        self.assertIn('configuration.title = "\\(number)  \\(candidate)"', controller)
        self.assertIn("configuration.background.cornerRadius", controller)
        self.assertIn('button.accessibilityLabel = "候选词 \\(number)：\\(candidate)"', controller)

    def test_apostrophe_reaches_the_engine_before_punctuation_conversion(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        separator_route = 'if symbol == "\'" {'
        punctuation_route = "let snapshot = session.handlePunctuation(symbol)"
        self.assertIn(separator_route, controller)
        self.assertIn("session.handleCharacter(symbol)", controller)
        self.assertLess(controller.index(separator_route), controller.index(punctuation_route))

    def test_keyboard_exposes_a_local_chinese_english_mode_switch(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("private var isChineseMode = true", controller)
        self.assertIn("languageModeButton", controller)
        self.assertIn("toggleInputMode", controller)
        self.assertIn("render(session.handleCharacter(character))", controller)
        self.assertIn("textDocumentProxy.insertText(output)", controller)
        self.assertIn("if !isChineseMode {\n      textDocumentProxy.insertText(symbol)", controller)
        self.assertIn("isChineseMode ? session.commitCandidate() : session.cancel()", controller)
        self.assertIn("isChineseMode ? \"中\" : \"英\"", controller)
        self.assertIn('languageModeButton.accessibilityIdentifier = "languageModeButton"', controller)

    def test_english_keyboard_supports_one_shot_shift_and_caps_lock(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("private enum LetterCaseState", controller)
        self.assertIn("case lowercase, shifted, capsLock", controller)
        self.assertIn("private var letterButtons: [(button: UIButton, lowercase: String)]", controller)
        self.assertIn("private weak var shiftButton: UIButton?", controller)
        self.assertIn("toggleLetterCase", controller)
        self.assertIn("letterCaseState = .capsLock", controller)
        self.assertIn("if letterCaseState == .shifted", controller)
        self.assertIn("letterCaseState = .lowercase", controller)
        self.assertIn('button.accessibilityIdentifier = "shiftButton"', controller)

    def test_project_and_ci_run_native_onboarding_ui_tests(self):
        project = (IOS_ROOT / "project.yml").read_text()
        workflow = (IOS_ROOT.parents[1] / ".github/workflows/ci.yml").read_text()
        runner = (IOS_ROOT / "scripts/run_ui_tests.sh").read_text()

        self.assertIn("MetasequoiaImeIOSUITests:", project)
        self.assertIn("platforms/ios/UITests", project)
        self.assertIn("GENERATE_INFOPLIST_FILE: YES", project)
        self.assertIn("MetasequoiaImeIOSUITests", project.split("test:", 1)[1])
        self.assertIn("platforms/ios/scripts/run_ui_tests.sh", workflow)
        self.assertIn("simctl bootstatus", runner)
        self.assertNotIn("sleep ", runner)

    def test_ui_tests_are_main_actor_isolated_for_swift_6(self):
        ui_tests = (IOS_ROOT / "UITests/OnboardingUITests.swift").read_text()

        self.assertIn(
            "@MainActor\n  func testOnboardingExposesEnablementPathAndTryoutField()",
            ui_tests,
        )

    def test_keyboard_action_row_adapts_to_narrow_screens(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn(
            "space.widthAnchor.constraint(equalTo: globe.widthAnchor, multiplier: 1.8)",
            controller,
        )
        self.assertIn(
            "globe.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)",
            controller,
        )
        self.assertIn(
            "enter.widthAnchor.constraint(equalTo: globe.widthAnchor, multiplier: 1.35)",
            controller,
        )
        self.assertNotIn("layoutToggle.widthAnchor.constraint(equalToConstant: 56)", controller)
        self.assertNotIn("space.widthAnchor.constraint(greaterThanOrEqualToConstant: 110)", controller)
        self.assertNotIn("enter.widthAnchor.constraint(equalToConstant: 72)", controller)

    def test_keyboard_exposes_a_persisted_full_and_double_pinyin_switch(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()
        bridge_header = (IOS_ROOT.parents[1] / "shared/apple-bridge/MetasequoiaInputSessionBridge.h").read_text()
        adapter_header = (IOS_ROOT.parents[1] / "shared/apple-bridge/InputSessionAdapter.h").read_text()

        self.assertIn("schemeButton", controller)
        self.assertIn("toggleScheme", controller)
        self.assertIn("UserDefaults.standard.bool(forKey: schemePreferenceKey)", controller)
        self.assertIn("UserDefaults.standard.set(usesShuangpin, forKey: schemePreferenceKey)", controller)
        self.assertIn("session.switch(toShuangpin: usesShuangpin)", controller)
        self.assertIn('usesShuangpin ? "小鹤" : "全拼"', controller)
        self.assertIn('schemeButton.accessibilityIdentifier = "schemeButton"', controller)
        self.assertIn("switchToShuangpin", bridge_header)
        self.assertIn("switch_to_shuangpin", adapter_header)

    def test_globe_key_uses_the_system_input_mode_list(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("#selector(handleInputModeButton(_:event:))", controller)
        self.assertIn("for: .allTouchEvents", controller)
        self.assertIn("touch.phase == .began", controller)
        self.assertIn("render(session.commitRaw())", controller)
        self.assertIn("handleInputModeList(from: sender, with: event)", controller)
        self.assertNotIn("advanceToNextInputMode()", controller)


if __name__ == "__main__":
    unittest.main()
