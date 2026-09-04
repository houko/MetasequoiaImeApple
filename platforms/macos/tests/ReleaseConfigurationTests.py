import json
import os
import plistlib
import re
import subprocess
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[3]
MACOS_ROOT = PROJECT_ROOT / "platforms" / "macos"


class ReleaseConfigurationTests(unittest.TestCase):
    def test_ci_cancels_duplicate_runs_for_the_same_source_branch(self):
        workflow = (PROJECT_ROOT / ".github/workflows/ci.yml").read_text()

        self.assertIn(
            "group: ci-${{ github.workflow }}-${{ github.event.pull_request.head.ref || github.ref_name }}",
            workflow,
        )
        self.assertIn("cancel-in-progress: true", workflow)

    def test_current_repository_links_use_the_canonical_apple_repository(self):
        canonical_repository = "https://github.com/metasequoiaime/MSIME-Apple"
        current_metadata = "\n".join(
            path.read_text()
            for path in (
                PROJECT_ROOT / "README.md",
                PROJECT_ROOT / "PRIVACY.md",
                PROJECT_ROOT / "THIRD_PARTY_NOTICES.txt",
                PROJECT_ROOT / "docs/apple-platform-architecture.md",
                MACOS_ROOT / "resources/Info.plist",
                MACOS_ROOT / "tests/ReleaseAutomationTests.py",
            )
        )

        self.assertNotIn("github.com/houko/MetasequoiaImeApple", current_metadata)
        self.assertNotIn("github.com/houko/MetasequoiaImeMac", current_metadata)
        self.assertIn(canonical_repository, current_metadata)
        with (MACOS_ROOT / "resources/Info.plist").open("rb") as info_file:
            info = plistlib.load(info_file)
        self.assertEqual(
            info["SUFeedURL"],
            f"{canonical_repository}/releases/latest/download/appcast.xml",
        )

    def test_input_source_uses_a_dedicated_menu_icon(self):
        with (MACOS_ROOT / "resources/Info.plist").open("rb") as info_file:
            info = plistlib.load(info_file)

        app_icon = "MetasequoiaIME.icns"
        menu_icon = "MetasequoiaIMEMenuIcon.tiff"
        input_mode = info["ComponentInputModeDict"]["tsInputModeListKey"][
            "com.houko.inputmethod.MetasequoiaIME.Hans"
        ]

        self.assertEqual(info["CFBundleIconFile"], app_icon)
        self.assertEqual(info["tsInputMethodIconFileKey"], menu_icon)
        self.assertEqual(input_mode["tsInputModeMenuIconFileKey"], menu_icon)
        self.assertEqual(input_mode["tsInputModePaletteIconFileKey"], menu_icon)
        self.assertTrue((MACOS_ROOT / "resources" / menu_icon).is_file())
        self.assertIn(menu_icon, (PROJECT_ROOT / "CMakeLists.txt").read_text())
        menu_icon_svg = (MACOS_ROOT / "resources" / "MetasequoiaIMEMenuIcon.svg").read_text()
        self.assertIn('<rect width="32" height="36" fill="#fff" />', menu_icon_svg)

        icon_path = MACOS_ROOT / "resources" / menu_icon
        dpi_output = subprocess.check_output(
            ["sips", "-g", "dpiWidth", "-g", "dpiHeight", str(icon_path)],
            text=True,
        )
        self.assertRegex(dpi_output, r"dpiWidth:\s*144(?:\.0+)?")
        self.assertRegex(dpi_output, r"dpiHeight:\s*144(?:\.0+)?")

        alpha_output = subprocess.check_output(
            ["sips", "-g", "hasAlpha", str(icon_path)],
            text=True,
        )
        self.assertRegex(alpha_output, r"hasAlpha:\s*no")

    def test_release_version_matches_cmake_project_version(self):
        manifest = json.loads((PROJECT_ROOT / ".release-please-manifest.json").read_text())
        cmake = (PROJECT_ROOT / "CMakeLists.txt").read_text()
        project_line = next(line for line in cmake.splitlines() if line.startswith("project(MetasequoiaImeApple "))
        match = re.search(r"VERSION ([0-9]+\.[0-9]+\.[0-9]+)", project_line)

        self.assertIsNotNone(match)
        self.assertEqual(manifest["."], match.group(1))
        self.assertEqual((PROJECT_ROOT / "version.txt").read_text().strip(), match.group(1))
        self.assertIn("x-release-please-version", project_line)

    def test_release_automation_bumps_tags_and_uploads_installable_assets(self):
        config = json.loads((PROJECT_ROOT / "release-please-config.json").read_text())
        package = config["packages"]["."]
        workflow = (PROJECT_ROOT / ".github/workflows/release.yml").read_text()
        merge_release_pr = (MACOS_ROOT / "scripts/merge-release-pr.sh").read_text()
        promote_release_branch = (MACOS_ROOT / "scripts/promote-release-branch.sh").read_text()
        create_promoted_release = (MACOS_ROOT / "scripts/create-promoted-release.sh").read_text()
        readme = (PROJECT_ROOT / "README.md").read_text()
        info_plist = (MACOS_ROOT / "resources/Info.plist").read_text()
        cmake = (PROJECT_ROOT / "CMakeLists.txt").read_text()

        self.assertEqual(package["release-type"], "simple")
        self.assertIn({"type": "generic", "path": "CMakeLists.txt"}, package["extra-files"])
        self.assertNotIn("generated", (package["pull-request-header"] + package["pull-request-footer"]).lower())
        self.assertTrue(package["draft"])
        self.assertTrue(package["force-tag-creation"])
        self.assertFalse(package.get("include-component-in-tag", True))
        ci_workflow = (PROJECT_ROOT / ".github/workflows/ci.yml").read_text()
        allowed_actions = {"actions/checkout", "googleapis/release-please-action"}
        used_actions = set()
        for workflow_source in (workflow, ci_workflow):
            uses_lines = [line.strip() for line in workflow_source.splitlines() if line.strip().startswith("uses:")]
            self.assertGreater(len(uses_lines), 0)
            for uses_line in uses_lines:
                action_reference = uses_line.removeprefix("uses:").strip().split()[0]
                action, separator, revision = action_reference.partition("@")
                self.assertEqual(separator, "@")
                self.assertIn(action, allowed_actions)
                self.assertRegex(revision, r"^[0-9a-f]{40}$")
                used_actions.add(action)
        self.assertEqual(used_actions, allowed_actions)
        self.assertIn("steps.release.outputs.release_created", workflow)
        self.assertIn("run: bash platforms/macos/scripts/merge-release-pr.sh", workflow)
        self.assertIn("id: merge_release_pr", workflow)
        self.assertIn("id: promote_release_commit", workflow)
        self.assertIn("id: release_branch_before", workflow)
        self.assertIn("EXPECTED_PREVIOUS_RELEASE_SHA: ${{ steps.release_branch_before.outputs.sha }}", workflow)
        self.assertIn("git/matching-refs/heads/$RELEASE_BRANCH", workflow)
        self.assertNotIn("2>/dev/null || true", workflow)
        self.assertIn("steps.release.outcome == 'failure'", workflow)
        self.assertIn("continue-on-error: true", workflow)
        self.assertIn("run: bash platforms/macos/scripts/promote-release-branch.sh", workflow)
        self.assertIn("steps.promote_release_commit.outputs.promoted == 'true'", workflow)
        self.assertIn("id: finalized_promoted_release", workflow)
        self.assertIn("steps.finalized_promoted_release.outputs.release_created", workflow)
        self.assertIn("target_sha:", workflow)
        self.assertIn("steps.requested_release.outputs.target_sha", workflow)
        self.assertIn("ref: ${{ needs.prepare.outputs.target_sha }}", workflow)
        self.assertIn('gh release view "$TAG_NAME" --json isDraft,targetCommitish', workflow)
        self.assertIn("Draft release target must be an immutable full commit SHA", workflow)
        self.assertIn("name: Revalidate draft release target", workflow)
        self.assertLess(workflow.index("name: Revalidate draft release target"), workflow.index("name: Upload and publish release"))
        self.assertIn("run: bash platforms/macos/scripts/create-promoted-release.sh", workflow)
        self.assertIn("id: finalized_release", workflow)
        self.assertIn("steps.merge_release_pr.outputs.merged == 'true'", workflow)
        self.assertIn("steps.finalized_release.outputs.release_created", workflow)
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("persist-credentials: false", workflow)
        self.assertIn("GH_REPO: ${{ github.repository }}", workflow)
        self.assertIn("gh workflow run ci.yml", merge_release_pr)
        self.assertIn("--field mac_only=true", promote_release_branch)
        self.assertIn("gh run watch", merge_release_pr)
        self.assertIn("--match-head-commit", merge_release_pr)
        self.assertTrue(merge_release_pr.startswith("#!/usr/bin/env bash\n"))
        self.assertIn("git/refs/heads/main", promote_release_branch)
        self.assertIn("force=false", promote_release_branch)
        self.assertIn("gh_api_retry()", promote_release_branch)
        self.assertIn("METASEQUOIA_GH_API_MAX_ATTEMPTS", promote_release_branch)
        self.assertIn("GitHub API request failed", promote_release_branch)
        self.assertTrue(promote_release_branch.startswith("#!/usr/bin/env bash\n"))
        self.assertIn('gh release create "$TAG_NAME"', create_promoted_release)
        self.assertIn('--target "$TARGET_SHA"', create_promoted_release)
        self.assertTrue(create_promoted_release.startswith("#!/usr/bin/env bash\n"))
        self.assertIn("platforms/macos/scripts/package_release.sh", workflow)
        signing_detector = (MACOS_ROOT / "scripts/detect-release-signing.sh").read_text()
        release_publisher = (MACOS_ROOT / "scripts/publish-release.sh").read_text()
        release_packager = (MACOS_ROOT / "scripts/package_release.sh").read_text()
        self.assertIn("macos-universal$ASSET_SUFFIX.pkg", release_publisher)
        self.assertIn("asset_suffix=-unsigned", signing_detector)
        self.assertIn("timeout-minutes: 30", workflow)
        self.assertIn(
            """        include:
          - runner: macos-15
            architecture: arm64
          - runner: macos-15-intel
            architecture: x86_64
""",
            ci_workflow,
        )
        self.assertIn("runs-on: ${{ matrix.runner }}", ci_workflow)
        self.assertIn("gh release upload", release_publisher)
        self.assertIn("gh release edit", release_publisher)
        self.assertIn("METASEQUOIA_REQUIRE_RELEASE_SIGNING", workflow)
        self.assertIn("platforms/macos/scripts/detect-release-signing.sh", workflow)
        self.assertIn("steps.signing.outputs.signing_enabled", workflow)
        self.assertIn("steps.signing.outputs.asset_suffix", workflow)
        self.assertIn("metasequoia-release-mode", release_publisher)
        self.assertIn("ref: ${{ github.event.repository.default_branch }}", workflow)
        self.assertNotIn("ref: ${{ github.sha }}", workflow)
        self.assertIn("$RUNNER_TEMP/detect-release-signing.sh", workflow)
        self.assertIn("$RUNNER_TEMP/package-release.sh", workflow)
        self.assertIn("$RUNNER_TEMP/InstallerDistribution.xml.in", workflow)
        self.assertIn("$RUNNER_TEMP/uninstall.sh", workflow)
        self.assertIn("METASEQUOIA_PROJECT_ROOT", workflow)
        self.assertIn("METASEQUOIA_RELEASE_INSTALL_SCRIPT", workflow)
        self.assertIn("METASEQUOIA_RELEASE_UNINSTALL_SCRIPT", workflow)
        self.assertIn("METASEQUOIA_RELEASE_SETTINGS_SCRIPT", workflow)
        self.assertIn("METASEQUOIA_INSTALLER_DISTRIBUTION", workflow)
        self.assertIn("$RUNNER_TEMP/publish-release.sh", workflow)
        self.assertIn("$RUNNER_TEMP/generate-sparkle-appcast.sh", workflow)
        self.assertIn("SPARKLE_ED_PRIVATE_KEY: ${{ secrets.SPARKLE_ED_PRIVATE_KEY }}", workflow)
        self.assertIn("steps.signing.outputs.signing_enabled == 'true'", workflow)
        self.assertIn("Unsigned releases do not publish a Sparkle appcast", workflow)
        self.assertIn("Unsigned release: skipping Developer ID signature verification before packaging.", workflow)
        self.assertIn("Unsigned release: skipping source bundle Developer ID signature verification.", release_packager)
        self.assertIn("Sparkle-2.9.6.tar.xz", workflow)
        self.assertIn("52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192", workflow)
        self.assertLess(workflow.index("name: Generate signed Sparkle appcast"), workflow.index("name: Upload and publish release"))
        self.assertIn("git merge-base --is-ancestor HEAD refs/remotes/origin/main", workflow)
        self.assertLess(workflow.index("name: Determine release signing mode"), workflow.index("name: Check out release tag"))
        self.assertLess(workflow.index("name: Verify release tag provenance"), workflow.index("name: Import Developer ID signing certificates"))
        self.assertIn("security import", workflow)
        self.assertIn("notarytool store-credentials", workflow)
        self.assertIn("name: Determine release signing mode", workflow)
        self.assertLess(workflow.index("name: Determine release signing mode"), workflow.index("name: Install dependencies"))
        self.assertIn("Developer ID Application", readme)
        self.assertIn("notarized", readme.lower())
        self.assertIn("全拼、小鹤双拼 or 86 五笔", readme)
        self.assertIn("candidate paging", readme)
        self.assertIn("macos-universal-update.zip", readme)
        self.assertIn("`appcast.xml`", readme)
        self.assertIn("fallback unsigned release intentionally omits `appcast.xml`", readme)
        self.assertIn("update payload, not a package to open manually", readme)
        self.assertIn("enable full-pinyin autocorrection", readme)
        self.assertIn("native 水杉输入法设置 panel", readme)
        self.assertIn("current user's copy in `~/Library/Input Methods`", readme)
        self.assertIn("may request administrator authorization", readme)
        self.assertIn("without logging out or administrator privileges", readme)
        self.assertIn("will not log out or restart the Mac automatically", readme)
        self.assertIn("recommended option when 水杉 should be available immediately", readme)
        self.assertNotIn("installs the input method system-wide", readme)
        self.assertIn("InputMethodServerPreferencesWindowControllerClass", info_plist)
        self.assertIn("METASEQUOIA_DEVELOPMENT_BUNDLE=$<TARGET_BUNDLE_DIR:MetasequoiaIME>", cmake)
        self.assertIn("@METASEQUOIA_IME_DICTIONARY_SHA256@", info_plist)
        self.assertIn("<key>SUPublicEDKey</key>", info_plist)
        self.assertIn("rSAufajnup+T+d+I4LTs4EAhe5M8bwHemWDKao3CB/E=", info_plist)
        self.assertIn("<key>SUFeedURL</key>", info_plist)
        self.assertIn("releases/latest/download/appcast.xml", info_plist)
        self.assertIn("<key>SUVerifyUpdateBeforeExtraction</key>", info_plist)
        self.assertIn("<key>SURequireSignedFeed</key>", info_plist)
        self.assertIn("<key>LSMinimumSystemVersion</key>", info_plist)
        self.assertIn("@CMAKE_OSX_DEPLOYMENT_TARGET@", info_plist)
        self.assertIn('file(SHA256 "${METASEQUOIA_IME_DICTIONARY}" METASEQUOIA_IME_DICTIONARY_SHA256)', cmake)
        self.assertIn("PreferencesWindowController.mm", cmake)
        self.assertIn("UpdateController.mm", cmake)
        self.assertIn('set(METASEQUOIA_SPARKLE_VERSION "2.9.6")', cmake)
        self.assertIn("Sparkle-${METASEQUOIA_SPARKLE_VERSION}.tar.xz", cmake)
        self.assertIn("52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192", cmake)
        self.assertIn("Contents/Frameworks", cmake)
        self.assertNotIn("UpdateChecker.mm", cmake)
        self.assertNotIn("UpdateCheckerTests.mm", cmake)
        self.assertIn("<key>SUEnableAutomaticChecks</key>", info_plist)
        self.assertIn("${METASEQUOIA_MACOS_ROOT}/scripts/uninstall.sh", cmake)
        self.assertIn("MACOSX_PACKAGE_LOCATION Resources", cmake)
        preferences_controller = (MACOS_ROOT / "src/PreferencesWindowController.mm").read_text()
        self.assertIn("initWithWindowNibName:(NSNibName)windowNibName owner:(id)owner", preferences_controller)
        self.assertIn("showAndActivate", preferences_controller)
        self.assertIn("showAndActivateForStandaloneLaunch", preferences_controller)
        self.assertIn("MetasequoiaStandalonePreferencesDidCloseNotification", preferences_controller)
        self.assertIn("storedScheme", preferences_controller)
        self.assertIn("setStoredScheme", preferences_controller)
        self.assertIn("小鹤双拼", preferences_controller)
        self.assertIn("storedAutocorrectEnabled", preferences_controller)
        self.assertIn("setAutocorrectEnabled", preferences_controller)
        self.assertIn("启用全拼自动纠错", preferences_controller)
        self.assertIn("storedHelpcodeEnabled", preferences_controller)
        self.assertIn("setHelpcodeEnabled", preferences_controller)
        self.assertIn("启用辅助码", preferences_controller)
        self.assertIn("storedChinesePunctuationEnabled", preferences_controller)
        self.assertIn("setChinesePunctuationEnabled", preferences_controller)
        self.assertIn("使用中文标点", preferences_controller)
        self.assertIn("restoreDefaults:", preferences_controller)
        self.assertIn("恢复默认设置", preferences_controller)
        self.assertIn("CFBundleShortVersionString", preferences_controller)
        self.assertIn('#import "DictionaryInstaller.h"', preferences_controller)
        self.assertIn("refreshDictionaryStatus", preferences_controller)
        self.assertIn("EnsureMetasequoiaDictionary", preferences_controller)
        self.assertIn("constexpr CGFloat kWindowWidth = 980.0", preferences_controller)
        self.assertIn("constexpr CGFloat kWindowHeight = 720.0", preferences_controller)
        self.assertIn("navigationTitles", preferences_controller)
        self.assertIn('@"键盘输入", @"外观", @"词库与数据"', preferences_controller)
        self.assertIn('@[ @"全拼输入", @"双拼输入", @"五笔输入" ]', preferences_controller)
        self.assertIn('addItemWithTitle:@"小鹤双拼"', preferences_controller)
        self.assertIn('addItemWithTitle:@"86 五笔"', preferences_controller)
        self.assertIn('accessibilityLabel = @"五笔功能设置"', preferences_controller)
        self.assertIn("selectPreferencesPage:", preferences_controller)
        self.assertIn('NSURL URLWithString:@"https://msime.app/"', preferences_controller)
        self.assertIn("MetasequoiaBrandColor", preferences_controller)
        self.assertIn('accessibilityLabel = @"水杉输入法导航"', preferences_controller)
        self.assertIn("词库已就绪", preferences_controller)
        self.assertIn("当前输入结束后的下一次按键生效", preferences_controller)
        self.assertIn("词库不可用，请重新安装水杉输入法", preferences_controller)
        input_controller = (MACOS_ROOT / "src/MetasequoiaInputController.mm").read_text()
        self.assertIn("EngineSchemeForStoredPreference", input_controller)
        self.assertIn("reloadSessionFromPreferences", input_controller)
        self.assertIn("prepareSessionIfNeeded", input_controller)
        self.assertIn("kDictionaryRetryDelay", input_controller)
        self.assertIn("- (void)activateServer:(id)sender", input_controller)
        handle_event = input_controller.split("- (BOOL)handleEvent:(NSEvent *)event client:(id)sender", 1)[1].split(
            "- (void)commitLeadingCandidate:(id)sender", 1
        )[0]
        self.assertIn("[self prepareSessionIfNeeded]", handle_event)
        self.assertIn("[self reloadSessionFromPreferences];", handle_event)
        self.assertLess(
            handle_event.index("[self prepareSessionIfNeeded]"),
            handle_event.index("[self reloadSessionFromPreferences];"),
        )
        self.assertLess(
            handle_event.index("[self reloadSessionFromPreferences];"),
            handle_event.index("const NSEventModifierFlags modifiers"),
        )
        reload_session = input_controller.split("- (void)reloadSessionFromPreferences", 1)[1].split(
            "- (BOOL)prepareSessionIfNeeded", 1
        )[0]
        self.assertLess(reload_session.index("_session->has_composition()"), reload_session.index("ReadSessionPreferences()"))
        self.assertIn("_candidateSelection.reset();", reload_session)
        self.assertIn("[_candidatePanel hide];", reload_session)
        controller_initialization = input_controller.split("- (instancetype)initWithServer:", 1)[1].split(
            "- (void)reloadSessionFromPreferences", 1
        )[0]
        self.assertLess(
            controller_initialization.index("_candidatePanel ="),
            controller_initialization.index("prepareSessionIfNeeded"),
        )
        self.assertIn("NSString *characters = event.characters;", input_controller)
        self.assertIn("NSString *charactersIgnoringModifiers = event.charactersIgnoringModifiers;", handle_event)
        self.assertIn("candidatePageShortcutModified", handle_event)
        character_input = handle_event.split("ControllerKeyAction::Character:", 1)[1]
        self.assertNotIn("charactersIgnoringModifiers", character_input)
        commit_composition = input_controller.split("- (void)commitComposition:(id)sender", 1)[1].split(
            "- (void)deactivateServer:(id)sender", 1
        )[0]
        self.assertIn("commitLeadingCandidate", commit_composition)
        self.assertNotIn("Command::CommitRaw", commit_composition)
        self.assertIn("next key event when no composition is active", readme)

        release_installer = (MACOS_ROOT / "scripts/install-release.sh").read_text()
        settings_launcher = (MACOS_ROOT / "scripts/open-settings.sh").read_text()
        self.assertNotIn("xcrun", release_installer)
        self.assertNotIn("xattr", release_installer)
        self.assertIn("spctl --assess --type execute", release_installer)
        self.assertIn("--register-input-source", release_installer)
        self.assertIn("Registered and enabled 水杉输入法 with macOS", release_installer)
        self.assertIn("--show-settings", settings_launcher)
        self.assertIn("Library/Input Methods/MetasequoiaIME.app", settings_launcher)
        self.assertIn("Open Settings.command", readme)
        self.assertIn("The installer always verifies the bundle's code signature", readme)
        self.assertIn("appears in the input menu without logging out", readme)
        self.assertIn("Both paths install the current-user bundle", readme)
        self.assertIn("enables 水杉输入法 automatically for the current user", readme)
        self.assertIn("script registers and enables 水杉输入法 automatically", readme)
        self.assertIn("unsigned builds instead require typing `I UNDERSTAND`", readme)
        self.assertNotIn("verifies both the code signature and Gatekeeper acceptance", readme)
        self.assertIn("./MetasequoiaIME-vX.Y.Z/Uninstall.command", readme)
        self.assertIn("MetasequoiaIME.app/Contents/Resources/Uninstall.command", readme)
        self.assertIn("preserves preferences and learned data by default", readme)
        self.assertNotIn("xattr -dr com.apple.quarantine", readme)
        self.assertNotIn("swift", release_installer.lower())
        install_script = (MACOS_ROOT / "scripts/install.sh").read_text()
        self.assertIn("staging_root=$(mktemp -d", install_script)
        self.assertIn("backup_root=$(mktemp -d", install_script)
        self.assertIn("install_complete=false", install_script)
        self.assertIn("METASEQUOIA_REGISTER_INPUT_SOURCE_COMMAND", install_script)
        self.assertIn("--register-input-source", install_script)
        self.assertNotIn("register_input_source.swift", install_script)
        self.assertIn("TISRegisterInputSource", (MACOS_ROOT / "scripts/register_input_source.swift").read_text())
        package_script = (MACOS_ROOT / "scripts/package_release.sh").read_text()
        self.assertIn("productsign", package_script)
        self.assertIn("notarytool", package_script)
        self.assertIn("Commercial release signing requires", package_script)
        self.assertIn("SUEnableAutomaticChecks false", package_script)
        self.assertIn("feed that cannot provide a trusted update", package_script)
        postinstall_script = MACOS_ROOT / "scripts/pkg-postinstall.sh"
        self.assertTrue(postinstall_script.is_file())
        self.assertIn("launchctl asuser", postinstall_script.read_text())
        self.assertIn("--register-input-source", postinstall_script.read_text())
        self.assertIn('pkgbuild --component', package_script)
        self.assertIn('--scripts "$pkg_scripts"', package_script)
        license_text = (PROJECT_ROOT / "LICENSE").read_text()
        notices = (PROJECT_ROOT / "THIRD_PARTY_NOTICES.txt").read_text()
        self.assertIn("GNU GENERAL PUBLIC LICENSE", license_text)
        self.assertIn("MetasequoiaImeEngine", notices)
        self.assertIn("googlepinyinime-rev", notices)
        self.assertIn("utfcpp", notices)
        self.assertIn("THIRD_PARTY_NOTICES.txt", package_script)
        privacy = (PROJECT_ROOT / "PRIVACY.md").read_text()
        security = (PROJECT_ROOT / "SECURITY.md").read_text()
        self.assertIn("~/Library/Application Support/metasequoiaime/", privacy)
        self.assertIn("does not send typed text", privacy)
        self.assertIn("does not sell or share personal data", privacy)
        self.assertIn("GitHub's public Releases API", privacy)
        self.assertIn("IP address and standard network request metadata", privacy)
        self.assertIn(
            "If learning is disabled while a composition is active, that composition keeps the setting it started "
            "with; after it is committed or cancelled, newly started compositions do not update word frequencies.",
            privacy,
        )
        self.assertIn("SECURITY.md", privacy)
        self.assertIn("latest published version", security)
        self.assertIn("Do not open a public issue", security)
        self.assertIn("MetasequoiaImeApple security report", security)
        self.assertIn("PRIVACY.md", readme)
        self.assertIn("SECURITY.md", readme)

    def test_dependabot_tracks_actions_and_expected_submodule_branches(self):
        dependabot = (PROJECT_ROOT / ".github/dependabot.yml").read_text()
        gitmodules = PROJECT_ROOT / ".gitmodules"

        def submodule_value(name, key):
            result = subprocess.run(
                ["git", "config", "-f", str(gitmodules), "--get", f"submodule.{name}.{key}"],
                check=True,
                capture_output=True,
                text=True,
                # A worktree checkout may expose a placeholder .git file whose
                # linked metadata is unavailable to this isolated config read.
                # Run outside the repository so git only parses .gitmodules.
                cwd=gitmodules.parent.parent,
            )
            return result.stdout.strip()

        self.assertEqual(dependabot.count('package-ecosystem: "github-actions"'), 1)
        self.assertEqual(dependabot.count('package-ecosystem: "gitsubmodule"'), 1)
        self.assertEqual(dependabot.count('interval: "monthly"'), 2)
        self.assertEqual(dependabot.count('prefix: "chore(deps)"'), 2)
        self.assertEqual(submodule_value("vendor/MetasequoiaImeEngine", "path"), "vendor/MetasequoiaImeEngine")
        self.assertEqual(
            submodule_value("vendor/MetasequoiaImeEngine", "url"),
            "https://github.com/metasequoiaime/MSIME-Engine.git",
        )
        self.assertEqual(submodule_value("vendor/MetasequoiaImeEngine", "branch"), "master")
        self.assertEqual(submodule_value("vendor/MetasequoiaImeDict", "path"), "vendor/MetasequoiaImeDict")
        self.assertEqual(
            submodule_value("vendor/MetasequoiaImeDict", "url"),
            "https://github.com/metasequoiaime/MSIME-Dict.git",
        )
        self.assertEqual(
            submodule_value("vendor/MetasequoiaImeHelpCode", "path"),
            "vendor/MetasequoiaImeHelpCode",
        )
        self.assertEqual(
            submodule_value("vendor/MetasequoiaImeHelpCode", "url"),
            "https://github.com/metasequoiaime/MetasequoiaImeHelpCode.git",
        )

    def test_macos_bundle_packages_helpcode_assets(self):
        cmake = (PROJECT_ROOT / "CMakeLists.txt").read_text()
        self.assertIn("vendor/MetasequoiaImeHelpCode/helpcodes", cmake)
        self.assertIn("Resources/helpcodes", cmake)

    def test_release_scripts_have_valid_zsh_syntax(self):
        for relative_path in (
            "scripts/install-release.sh",
            "scripts/package_release.sh",
        ):
            result = subprocess.run(["zsh", "-n", str(MACOS_ROOT / relative_path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run(
            ["bash", "-n", str(MACOS_ROOT / "scripts/merge-release-pr.sh")], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        for relative_path in ("scripts/detect-release-signing.sh", "scripts/publish-release.sh"):
            result = subprocess.run(
                ["bash", "-n", str(MACOS_ROOT / relative_path)], capture_output=True, text=True
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_package_script_refuses_ambiguously_named_unsigned_assets(self):
        environment = os.environ.copy()
        for variable in (
            "METASEQUOIA_REQUIRE_RELEASE_SIGNING",
            "METASEQUOIA_DEVELOPER_ID_APPLICATION",
            "METASEQUOIA_DEVELOPER_ID_INSTALLER",
            "METASEQUOIA_NOTARY_PROFILE",
            "METASEQUOIA_RELEASE_ASSET_SUFFIX",
        ):
            environment.pop(variable, None)

        result = subprocess.run(
            [MACOS_ROOT / "scripts/package_release.sh", "v1.2.3"],
            capture_output=True,
            text=True,
            env=environment,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("require METASEQUOIA_RELEASE_ASSET_SUFFIX=-unsigned", result.stderr)


if __name__ == "__main__":
    unittest.main()
