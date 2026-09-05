import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path


IOS_ROOT = Path(__file__).resolve().parents[1]


class ProjectConfigurationTests(unittest.TestCase):
    def test_host_and_keyboard_bundle_the_required_reason_privacy_manifest(self):
        project = (IOS_ROOT / "project.yml").read_text()
        manifest_path = IOS_ROOT / "SharedResources/PrivacyInfo.xcprivacy"

        with manifest_path.open("rb") as manifest_file:
            manifest = plistlib.load(manifest_file)

        self.assertFalse(manifest["NSPrivacyTracking"])
        self.assertEqual(manifest["NSPrivacyCollectedDataTypes"], [])
        self.assertEqual(
            manifest["NSPrivacyAccessedAPITypes"],
            [
                {
                    "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                    "NSPrivacyAccessedAPITypeReasons": ["CA92.1", "1C8F.1"],
                }
            ],
        )
        self.assertEqual(
            project.count("platforms/ios/SharedResources/PrivacyInfo.xcprivacy"),
            2,
        )

    def test_host_and_keyboard_share_the_input_scheme_through_an_app_group(self):
        project = (IOS_ROOT / "project.yml").read_text()
        shared_preference = (IOS_ROOT / "SharedUI/InputSchemePreference.swift").read_text()
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()
        group_identifier = "group.com.houko.metasequoiaime.ios"

        for relative_path in (
            "App/Resources/MetasequoiaImeIOS.entitlements",
            "KeyboardExtension/Resources/MetasequoiaKeyboard.entitlements",
        ):
            with (IOS_ROOT / relative_path).open("rb") as entitlement_file:
                entitlements = plistlib.load(entitlement_file)
            self.assertEqual(entitlements["com.apple.security.application-groups"], [group_identifier])
            self.assertIn(relative_path, project)

        self.assertIn(f'static let appGroupIdentifier = "{group_identifier}"', shared_preference)
        self.assertIn('private static let key = "inputSchemeUsesShuangpin"', shared_preference)
        self.assertIn("UserDefaults(suiteName: appGroupIdentifier)", shared_preference)
        self.assertIn("UserDefaults.standard.object(forKey: key)", shared_preference)
        self.assertIn("InputSchemePreference.usesShuangpin", controller)
        self.assertNotIn("schemePreferenceKey", controller)

    def test_english_capitalization_policy(self):
        policy = IOS_ROOT / "KeyboardExtension/Sources/EnglishCapitalizationPolicy.swift"
        tests = IOS_ROOT / "tests/EnglishCapitalizationPolicyTests.swift"

        with tempfile.TemporaryDirectory() as temporary_directory:
            executable = Path(temporary_directory) / "EnglishCapitalizationPolicyTests"
            subprocess.run(
                ["swiftc", str(policy), str(tests), "-o", str(executable)],
                check=True,
            )
            subprocess.run([str(executable)], check=True)

    def test_chinese_output_conversion(self):
        conversion = IOS_ROOT / "SharedUI/ChineseTextConversion.swift"
        tests = IOS_ROOT / "tests/ChineseTextConversionTests.swift"

        with tempfile.TemporaryDirectory() as temporary_directory:
            executable = Path(temporary_directory) / "ChineseTextConversionTests"
            subprocess.run(
                ["swiftc", str(conversion), str(tests), "-o", str(executable)],
                check=True,
            )
            subprocess.run([str(executable)], check=True)

    def test_host_and_keyboard_share_the_chinese_output_script(self):
        preference = (IOS_ROOT / "SharedUI/ChineseOutputPreference.swift").read_text()
        onboarding = (IOS_ROOT / "App/Sources/OnboardingView.swift").read_text()
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn('private static let key = "chineseOutputUsesTraditional"', preference)
        self.assertIn("UserDefaults(suiteName: InputSchemePreference.appGroupIdentifier)", preference)

        self.assertIn(
            "@State private var usesTraditionalOutput = ChineseOutputPreference.usesTraditional",
            onboarding,
        )
        self.assertIn('Picker("输出字形", selection: $usesTraditionalOutput)', onboarding)
        self.assertIn('Text("简体").tag(false)', onboarding)
        self.assertIn('Text("繁体").tag(true)', onboarding)
        self.assertIn('.accessibilityIdentifier("chineseOutputPicker")', onboarding)
        self.assertIn("ChineseOutputPreference.usesTraditional = newValue", onboarding)

        self.assertIn("usesTraditionalOutput = ChineseOutputPreference.usesTraditional", controller)
        self.assertIn("synchronizeChineseOutputPreference()", controller)

    def test_only_visible_candidates_and_commits_change_script(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        # The engine and the packaged dictionary stay simplified, so conversion belongs at the
        # render and commit boundary only. Converting the preedit would rewrite pinyin, and
        # converting before selection would break the engine index the candidate chips carry.
        self.assertIn("textDocumentProxy.insertText(chineseOutput(commitText))", controller)
        self.assertIn("let display = chineseOutput(candidate)", controller)
        self.assertIn('configuration.title = "\\(number)  \\(display)"', controller)
        self.assertIn("self.render(self.session.selectCandidate(at: UInt(number - 1)))", controller)

        strip = controller.split("private func renderCandidateStrip", 1)[1].split("\n  }", 1)[0]
        self.assertIn("visiblePreedit", strip)
        self.assertNotIn("chineseOutput(visiblePreedit)", strip)

    def test_backspace_repeats_only_while_the_delete_key_is_held(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("private var backspaceRepeatTimer: Timer?", controller)
        self.assertIn("#selector(beginBackspacePress)", controller)
        self.assertIn("for: .touchDown", controller)
        self.assertIn("#selector(finishBackspacePress)", controller)
        self.assertIn("for: .touchUpInside", controller)
        self.assertIn("#selector(cancelBackspacePress)", controller)
        self.assertIn("RunLoop.main.add(timer, forMode: .common)", controller)
        self.assertIn("timer.fireDate = Date(timeIntervalSinceNow: 0.4)", controller)
        self.assertIn("override func viewWillDisappear", controller)

    def test_keyboard_uses_system_input_click_feedback(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("UIInputViewAudioFeedback", controller)
        self.assertIn("var enableInputClicksWhenVisible: Bool { true }", controller)
        self.assertIn("UIDevice.current.playInputClick()", controller)
        self.assertIn("private func playInputClick()", controller)
        self.assertGreaterEqual(controller.count("playInputClick()"), 9)

    def test_every_target_resolves_a_product_name(self):
        # Xcode 26 stopped defaulting PRODUCT_NAME to the target name. Without the project-level
        # fallback the bridge library links as a bare `-l` that swallows the next linker flag, and
        # the UI-test target builds `.xctest` inside `-Runner.app`, which collide in the products
        # directory. Both failures only appear at link and test time, so pin the setting here.
        project = (IOS_ROOT / "project.yml").read_text()

        self.assertIn("PRODUCT_NAME: $(TARGET_NAME)", project)
        self.assertLess(
            project.index("PRODUCT_NAME: $(TARGET_NAME)"),
            project.index("targets:"),
        )

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

    def test_host_app_exposes_the_shared_input_scheme_setting(self):
        onboarding = (IOS_ROOT / "App/Sources/OnboardingView.swift").read_text()
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn(
            "@State private var usesShuangpin = InputSchemePreference.usesShuangpin",
            onboarding,
        )
        self.assertIn('Picker("输入方案", selection: $usesShuangpin)', onboarding)
        self.assertIn('Text("全拼").tag(false)', onboarding)
        self.assertIn('Text("小鹤双拼").tag(true)', onboarding)
        self.assertIn('.accessibilityIdentifier("inputSchemePicker")', onboarding)
        self.assertIn("InputSchemePreference.usesShuangpin = newValue", onboarding)
        self.assertIn("private var hasComposition = false", controller)
        self.assertIn("override func viewWillAppear", controller)
        self.assertIn("synchronizeInputSchemePreference()", controller)
        self.assertIn("guard !hasComposition else { return }", controller)
        self.assertIn("hasComposition = !snapshot.preedit.isEmpty", controller)

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
        self.assertIn('configuration.title = "\\(number)  \\(display)"', controller)
        self.assertIn("configuration.background.cornerRadius", controller)
        self.assertIn('button.accessibilityLabel = "候选词 \\(number)：\\(display)"', controller)

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

    def test_return_key_reflects_the_host_input_trait(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("private weak var enterButton: UIButton?", controller)
        self.assertIn("override func textDidChange", controller)
        self.assertIn("switch textDocumentProxy.returnKeyType ?? .default", controller)
        self.assertIn("case .go:", controller)
        self.assertIn("case .google, .search, .yahoo:", controller)
        self.assertIn("case .send:", controller)
        self.assertIn("case .done:", controller)
        self.assertIn("enterButton?.accessibilityLabel = title", controller)

        self.assertIn("switch textDocumentProxy.autocapitalizationType ?? .sentences", controller)

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
        self.assertIn('derived_data_path="${2:-build/ios-derived}"', runner)
        self.assertIn('xcrun simctl shutdown "${test_device_id}"', runner)
        self.assertIn('xcrun simctl boot "${test_device_id}"', runner)
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

    def test_keyboard_respects_the_height_assigned_by_the_system(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        self.assertIn("root.bottomAnchor.constraint(equalTo: view.bottomAnchor", controller)
        self.assertNotIn("view.heightAnchor.constraint", controller)

    def test_keyboard_exposes_a_persisted_full_and_double_pinyin_switch(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()
        bridge_header = (IOS_ROOT.parents[1] / "shared/apple-bridge/MetasequoiaInputSessionBridge.h").read_text()
        adapter_header = (IOS_ROOT.parents[1] / "shared/apple-bridge/InputSessionAdapter.h").read_text()

        self.assertIn("schemeButton", controller)
        self.assertIn("toggleScheme", controller)
        self.assertIn("usesShuangpin = InputSchemePreference.usesShuangpin", controller)
        self.assertIn("InputSchemePreference.usesShuangpin = usesShuangpin", controller)
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

    def test_bridge_compiles_every_engine_source_directory(self):
        # macOS pulls the engine in with add_subdirectory, so it tracks new engine directories on its own. This target enumerates them by hand, so a directory added upstream silently drops out of the static library and only surfaces as undefined symbols at link time — which is how local_modes broke the keyboard extension.
        engine_root = IOS_ROOT.parents[1] / "vendor/MetasequoiaImeEngine"
        if not (engine_root / "core").is_dir():
            self.skipTest("engine submodule is not checked out")

        project = (IOS_ROOT / "project.yml").read_text()
        not_built = {"tests"}
        missing = []
        for directory in sorted(engine_root.iterdir()):
            if not directory.is_dir() or directory.name.startswith("."):
                continue
            if directory.name in not_built:
                continue
            if not any(directory.glob("*.cpp")):
                continue
            if f"vendor/MetasequoiaImeEngine/{directory.name}" not in project:
                missing.append(directory.name)

        self.assertEqual(missing, [], f"engine directories missing from the bridge target: {missing}")


    def test_chinese_mode_never_sends_uppercase_to_the_session(self):
        controller = (IOS_ROOT / "KeyboardExtension/Sources/KeyboardViewController.swift").read_text()

        # The engine consumes A-Z during a composition as helpcode input. The bridge rejects uppercase,
        # but this keyboard is the other half of that contract: in Chinese mode the shift key is hidden,
        # shift handling returns early, and key titles stay lowercase, so an uppercase letter never
        # reaches handleCharacter in the first place. Losing any one of the three would send capitals
        # into the session and swallow them instead of inserting them.
        self.assertIn("button.isHidden = isChineseMode", controller)
        shift_handler = controller.split("private func toggleLetterCase", 1)[1].split("\n  }", 1)[0]
        self.assertIn("guard !isChineseMode else { return }", shift_handler)
        self.assertIn("let usesUppercase = !isChineseMode && letterCaseState != .lowercase", controller)
        character_handler = controller.split("private func handleCharacter", 1)[1].split("\n  }", 1)[0]
        self.assertIn("render(session.handleCharacter(character))", character_handler)
        self.assertNotIn("uppercased()", character_handler.split("} else {", 1)[0])


if __name__ == "__main__":
    unittest.main()
