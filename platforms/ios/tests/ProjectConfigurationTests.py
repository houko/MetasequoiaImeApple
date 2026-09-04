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
        self.assertIn("advanceToNextInputMode()", controller)
        self.assertNotIn("URLSession", controller)

    def test_onboarding_exposes_a_regular_text_field_for_keyboard_tryout(self):
        onboarding = (IOS_ROOT / "App/Sources/OnboardingView.swift").read_text()

        self.assertIn('TextField("在这里试试水杉键盘"', onboarding)
        self.assertIn('.accessibilityIdentifier("keyboardTryoutField")', onboarding)


if __name__ == "__main__":
    unittest.main()
