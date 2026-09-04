cmake_minimum_required(VERSION 3.25)

set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum supported macOS version")
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "macOS target architectures")

project(MetasequoiaImeMac VERSION 0.23.2 LANGUAGES CXX OBJCXX) # x-release-please-version

include(CTest)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(METASEQUOIA_SPARKLE_VERSION "2.9.6")
set(METASEQUOIA_SPARKLE_SHA256 "52bf9e88cdd972fc0c81501377a880e90d47031bd8ca5462488f843e2609e192")
set(METASEQUOIA_SPARKLE_URL
    "https://github.com/sparkle-project/Sparkle/releases/download/${METASEQUOIA_SPARKLE_VERSION}/Sparkle-${METASEQUOIA_SPARKLE_VERSION}.tar.xz")

add_subdirectory(vendor/MetasequoiaImeEngine engine)

add_library(MetasequoiaImeMacCore STATIC src/InputSession.cpp)
target_include_directories(MetasequoiaImeMacCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(MetasequoiaImeMacCore PUBLIC MetasequoiaIme::Engine)
target_compile_options(MetasequoiaImeMacCore PRIVATE -Wall -Wextra -Wpedantic -Werror)

if(BUILD_TESTING)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    find_library(APPKIT_FRAMEWORK AppKit REQUIRED)
    find_library(INPUT_METHOD_KIT_FRAMEWORK InputMethodKit REQUIRED)
    add_executable(MetasequoiaImeMacTests tests/InputSessionTests.cpp)
    target_link_libraries(MetasequoiaImeMacTests PRIVATE MetasequoiaImeMacCore)
    target_compile_options(MetasequoiaImeMacTests PRIVATE -Wall -Wextra -Wpedantic -Werror)
    add_test(NAME input_session COMMAND MetasequoiaImeMacTests)
    add_executable(MetasequoiaInputControllerKeyRoutingTests tests/InputControllerKeyRoutingTests.mm)
    target_compile_options(MetasequoiaInputControllerKeyRoutingTests PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
    target_link_libraries(MetasequoiaInputControllerKeyRoutingTests PRIVATE ${APPKIT_FRAMEWORK} ${INPUT_METHOD_KIT_FRAMEWORK})
    add_test(NAME input_controller_key_routing COMMAND MetasequoiaInputControllerKeyRoutingTests)
    add_executable(MetasequoiaInputMenuTests tests/InputMenuTests.mm)
    target_compile_options(MetasequoiaInputMenuTests PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
    target_link_libraries(MetasequoiaInputMenuTests PRIVATE ${APPKIT_FRAMEWORK})
    add_test(NAME input_menu COMMAND MetasequoiaInputMenuTests)
    add_executable(MetasequoiaStringConversionTests tests/StringConversionTests.mm src/StringConversion.mm)
    target_compile_options(MetasequoiaStringConversionTests PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
    target_link_libraries(MetasequoiaStringConversionTests PRIVATE ${APPKIT_FRAMEWORK})
    add_test(NAME string_conversion COMMAND MetasequoiaStringConversionTests)
    add_test(NAME release_automation COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/ReleaseAutomationTests.py)
    add_test(NAME release_configuration COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/ReleaseConfigurationTests.py)
    add_test(NAME uninstall_workflow COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/UninstallTests.py)
endif()

option(METASEQUOIA_IME_BUILD_INPUT_METHOD "Build the InputMethodKit bundle" ON)
set(METASEQUOIA_IME_DICTIONARY "${CMAKE_CURRENT_SOURCE_DIR}/vendor/MetasequoiaImeDict/out/msime.db" CACHE FILEPATH "Path to the generated msime.db dictionary")

if(METASEQUOIA_IME_BUILD_INPUT_METHOD)
    if(NOT APPLE)
        message(FATAL_ERROR "The InputMethodKit bundle can only be built on macOS.")
    endif()
    if(NOT EXISTS "${METASEQUOIA_IME_DICTIONARY}")
        message(FATAL_ERROR "Dictionary not found at ${METASEQUOIA_IME_DICTIONARY}. Run scripts/build_dictionary.py first.")
    endif()

    file(SHA256 "${METASEQUOIA_IME_DICTIONARY}" METASEQUOIA_IME_DICTIONARY_SHA256)
    find_library(APPKIT_FRAMEWORK AppKit REQUIRED)
    find_library(CARBON_FRAMEWORK Carbon REQUIRED)
    find_library(INPUT_METHOD_KIT_FRAMEWORK InputMethodKit REQUIRED)

    set(METASEQUOIA_SPARKLE_DOWNLOAD_DIRECTORY "${CMAKE_BINARY_DIR}/_deps")
    set(METASEQUOIA_SPARKLE_ARCHIVE
        "${METASEQUOIA_SPARKLE_DOWNLOAD_DIRECTORY}/Sparkle-${METASEQUOIA_SPARKLE_VERSION}.tar.xz")
    set(METASEQUOIA_SPARKLE_ROOT
        "${METASEQUOIA_SPARKLE_DOWNLOAD_DIRECTORY}/Sparkle-${METASEQUOIA_SPARKLE_VERSION}")
    set(METASEQUOIA_SPARKLE_FRAMEWORK "${METASEQUOIA_SPARKLE_ROOT}/Sparkle.framework")
    file(MAKE_DIRECTORY "${METASEQUOIA_SPARKLE_DOWNLOAD_DIRECTORY}")
    set(METASEQUOIA_SPARKLE_DOWNLOAD_REQUIRED TRUE)
    if(EXISTS "${METASEQUOIA_SPARKLE_ARCHIVE}")
        file(SHA256 "${METASEQUOIA_SPARKLE_ARCHIVE}" METASEQUOIA_SPARKLE_EXISTING_SHA256)
        if(METASEQUOIA_SPARKLE_EXISTING_SHA256 STREQUAL METASEQUOIA_SPARKLE_SHA256)
            set(METASEQUOIA_SPARKLE_DOWNLOAD_REQUIRED FALSE)
        endif()
    endif()
    if(METASEQUOIA_SPARKLE_DOWNLOAD_REQUIRED)
        file(DOWNLOAD "${METASEQUOIA_SPARKLE_URL}" "${METASEQUOIA_SPARKLE_ARCHIVE}"
            EXPECTED_HASH "SHA256=${METASEQUOIA_SPARKLE_SHA256}"
            TLS_VERIFY ON
            SHOW_PROGRESS)
    endif()
    if(NOT EXISTS "${METASEQUOIA_SPARKLE_FRAMEWORK}/Versions/B/Sparkle")
        file(MAKE_DIRECTORY "${METASEQUOIA_SPARKLE_ROOT}")
        file(ARCHIVE_EXTRACT INPUT "${METASEQUOIA_SPARKLE_ARCHIVE}"
            DESTINATION "${METASEQUOIA_SPARKLE_ROOT}")
    endif()
    if(NOT EXISTS "${METASEQUOIA_SPARKLE_FRAMEWORK}/Versions/B/Sparkle")
        message(FATAL_ERROR "Pinned Sparkle framework was not extracted successfully.")
    endif()
    add_library(MetasequoiaSparkle SHARED IMPORTED)
    set_target_properties(MetasequoiaSparkle PROPERTIES
        IMPORTED_LOCATION "${METASEQUOIA_SPARKLE_FRAMEWORK}/Versions/B/Sparkle"
        INTERFACE_COMPILE_OPTIONS "-F${METASEQUOIA_SPARKLE_ROOT}"
        INTERFACE_LINK_OPTIONS "-F${METASEQUOIA_SPARKLE_ROOT}")

    configure_file(resources/Info.plist ${CMAKE_CURRENT_BINARY_DIR}/MetasequoiaIME-Info.plist @ONLY)

    set(METASEQUOIA_IME_LEGAL_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/Legal)
    file(MAKE_DIRECTORY ${METASEQUOIA_IME_LEGAL_DIRECTORY})
    configure_file(LICENSE ${METASEQUOIA_IME_LEGAL_DIRECTORY}/GPL-3.0.txt COPYONLY)
    configure_file(THIRD_PARTY_NOTICES.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/THIRD_PARTY_NOTICES.txt COPYONLY)
    configure_file(vendor/MetasequoiaImeEngine/googlepinyinime-rev/LICENSE
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/Apache-2.0-googlepinyinime.txt COPYONLY)
    configure_file(vendor/MetasequoiaImeEngine/utfcpp/LICENSE
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/Boost-1.0.txt COPYONLY)
    configure_file(licenses/fmt-LICENSE ${METASEQUOIA_IME_LEGAL_DIRECTORY}/MIT-fmt.txt COPYONLY)
    configure_file(licenses/spdlog-LICENSE ${METASEQUOIA_IME_LEGAL_DIRECTORY}/MIT-spdlog.txt COPYONLY)
    configure_file(${METASEQUOIA_SPARKLE_ROOT}/LICENSE
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/Sparkle-LICENSE.txt COPYONLY)
    set(METASEQUOIA_IME_UNINSTALLER ${CMAKE_CURRENT_BINARY_DIR}/Uninstall.command)
    configure_file(scripts/uninstall.sh ${METASEQUOIA_IME_UNINSTALLER} COPYONLY)

    set(METASEQUOIA_IME_ICONS resources/MetasequoiaIME.icns resources/MetasequoiaIMEMenuIcon.tiff)
    set(METASEQUOIA_IME_LOCALIZATIONS resources/en.lproj/InfoPlist.strings resources/zh-Hans.lproj/InfoPlist.strings)
    set(METASEQUOIA_IME_LEGAL_RESOURCES
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/GPL-3.0.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/THIRD_PARTY_NOTICES.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/Apache-2.0-googlepinyinime.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/Boost-1.0.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/MIT-fmt.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/MIT-spdlog.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/Sparkle-LICENSE.txt)
    add_executable(MetasequoiaIME MACOSX_BUNDLE src/main.mm src/DictionaryInstaller.mm src/InputSourceRegistration.mm src/MetasequoiaInputController.mm src/PreferencesWindowController.mm src/StringConversion.mm src/UpdateController.mm ${METASEQUOIA_IME_DICTIONARY} ${METASEQUOIA_IME_ICONS} ${METASEQUOIA_IME_LOCALIZATIONS} ${METASEQUOIA_IME_LEGAL_RESOURCES} ${METASEQUOIA_IME_UNINSTALLER})
    set_source_files_properties(${METASEQUOIA_IME_DICTIONARY} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    set_source_files_properties(${METASEQUOIA_IME_ICONS} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    set_source_files_properties(resources/en.lproj/InfoPlist.strings PROPERTIES MACOSX_PACKAGE_LOCATION Resources/en.lproj)
    set_source_files_properties(resources/zh-Hans.lproj/InfoPlist.strings PROPERTIES MACOSX_PACKAGE_LOCATION Resources/zh-Hans.lproj)
    set_source_files_properties(${METASEQUOIA_IME_LEGAL_RESOURCES}
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources/Licenses)
    set_source_files_properties(${METASEQUOIA_IME_UNINSTALLER}
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources HEADER_FILE_ONLY TRUE)
    set_target_properties(MetasequoiaIME PROPERTIES MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_BINARY_DIR}/MetasequoiaIME-Info.plist MACOSX_BUNDLE_BUNDLE_NAME "Metasequoia IME" MACOSX_BUNDLE_GUI_IDENTIFIER "com.houko.inputmethod.MetasequoiaIME" MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION} MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION} OUTPUT_NAME MetasequoiaIME BUILD_WITH_INSTALL_RPATH TRUE INSTALL_RPATH "@executable_path/../Frameworks")
    target_compile_options(MetasequoiaIME PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
    target_link_libraries(MetasequoiaIME PRIVATE MetasequoiaImeMacCore MetasequoiaSparkle ${APPKIT_FRAMEWORK} ${CARBON_FRAMEWORK} ${INPUT_METHOD_KIT_FRAMEWORK})
    add_custom_command(TARGET MetasequoiaIME POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:MetasequoiaIME>/Contents/Frameworks"
        COMMAND /usr/bin/ditto "${METASEQUOIA_SPARKLE_FRAMEWORK}"
            "$<TARGET_BUNDLE_DIR:MetasequoiaIME>/Contents/Frameworks/Sparkle.framework"
        VERBATIM)
    add_custom_target(MetasequoiaIMESign ALL COMMAND /usr/bin/codesign --force --deep --sign - "$<TARGET_BUNDLE_DIR:MetasequoiaIME>" DEPENDS MetasequoiaIME VERBATIM)
    if(BUILD_TESTING)
        add_executable(MetasequoiaDictionaryInstallerTests tests/DictionaryInstallerTests.mm src/DictionaryInstaller.mm)
        target_compile_options(MetasequoiaDictionaryInstallerTests PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
        target_link_libraries(MetasequoiaDictionaryInstallerTests PRIVATE MetasequoiaIme::Engine ${APPKIT_FRAMEWORK})
        add_test(NAME dictionary_installer COMMAND MetasequoiaDictionaryInstallerTests)
        add_executable(MetasequoiaInputSourceRegistrationTests tests/InputSourceRegistrationTests.mm src/InputSourceRegistration.mm)
        target_compile_options(MetasequoiaInputSourceRegistrationTests PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
        target_link_libraries(MetasequoiaInputSourceRegistrationTests PRIVATE ${APPKIT_FRAMEWORK} ${CARBON_FRAMEWORK})
        add_test(NAME input_source_registration COMMAND MetasequoiaInputSourceRegistrationTests)
        add_executable(MetasequoiaUpdateControllerTests tests/UpdateControllerTests.mm src/UpdateController.mm)
        target_compile_options(MetasequoiaUpdateControllerTests PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
        target_link_libraries(MetasequoiaUpdateControllerTests PRIVATE MetasequoiaSparkle ${APPKIT_FRAMEWORK})
        set_target_properties(MetasequoiaUpdateControllerTests PROPERTIES BUILD_RPATH "${METASEQUOIA_SPARKLE_ROOT}")
        add_test(NAME update_controller COMMAND MetasequoiaUpdateControllerTests)
        add_executable(MetasequoiaPreferencesWindowTests tests/PreferencesWindowTests.mm src/PreferencesWindowController.mm src/DictionaryInstaller.mm src/UpdateController.mm)
        target_compile_options(MetasequoiaPreferencesWindowTests PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
        target_link_libraries(MetasequoiaPreferencesWindowTests PRIVATE MetasequoiaIme::Engine MetasequoiaSparkle ${APPKIT_FRAMEWORK} ${INPUT_METHOD_KIT_FRAMEWORK})
        set_target_properties(MetasequoiaPreferencesWindowTests PROPERTIES BUILD_RPATH "${METASEQUOIA_SPARKLE_ROOT}")
        add_test(NAME preferences_window COMMAND MetasequoiaPreferencesWindowTests)
        add_test(NAME release_package COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/ReleasePackageTests.py $<TARGET_BUNDLE_DIR:MetasequoiaIME>)
        set_tests_properties(release_package PROPERTIES TIMEOUT 240)
    endif()
endif()
