cmake_minimum_required(VERSION 3.25)

set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0" CACHE STRING "Minimum supported macOS version")
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "macOS target architectures")

project(MetasequoiaImeMac VERSION 0.9.3 LANGUAGES CXX OBJCXX) # x-release-please-version

include(CTest)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

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
    add_test(NAME release_automation COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/ReleaseAutomationTests.py)
    add_test(NAME release_configuration COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/ReleaseConfigurationTests.py)
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

    set(METASEQUOIA_IME_ICON resources/MetasequoiaIME.icns)
    set(METASEQUOIA_IME_LOCALIZATIONS resources/en.lproj/InfoPlist.strings resources/zh-Hans.lproj/InfoPlist.strings)
    set(METASEQUOIA_IME_LEGAL_RESOURCES
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/GPL-3.0.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/THIRD_PARTY_NOTICES.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/Apache-2.0-googlepinyinime.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/Boost-1.0.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/MIT-fmt.txt
        ${METASEQUOIA_IME_LEGAL_DIRECTORY}/MIT-spdlog.txt)
    add_executable(MetasequoiaIME MACOSX_BUNDLE src/main.mm src/DictionaryInstaller.mm src/MetasequoiaInputController.mm src/PreferencesWindowController.mm ${METASEQUOIA_IME_DICTIONARY} ${METASEQUOIA_IME_ICON} ${METASEQUOIA_IME_LOCALIZATIONS} ${METASEQUOIA_IME_LEGAL_RESOURCES})
    set_source_files_properties(${METASEQUOIA_IME_DICTIONARY} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    set_source_files_properties(${METASEQUOIA_IME_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    set_source_files_properties(resources/en.lproj/InfoPlist.strings PROPERTIES MACOSX_PACKAGE_LOCATION Resources/en.lproj)
    set_source_files_properties(resources/zh-Hans.lproj/InfoPlist.strings PROPERTIES MACOSX_PACKAGE_LOCATION Resources/zh-Hans.lproj)
    set_source_files_properties(${METASEQUOIA_IME_LEGAL_RESOURCES}
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources/Licenses)
    set_target_properties(MetasequoiaIME PROPERTIES MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_BINARY_DIR}/MetasequoiaIME-Info.plist MACOSX_BUNDLE_BUNDLE_NAME "Metasequoia IME" MACOSX_BUNDLE_GUI_IDENTIFIER "com.houko.inputmethod.MetasequoiaIME" MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION} MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION} OUTPUT_NAME MetasequoiaIME)
    target_compile_options(MetasequoiaIME PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
    target_link_libraries(MetasequoiaIME PRIVATE MetasequoiaImeMacCore ${APPKIT_FRAMEWORK} ${CARBON_FRAMEWORK} ${INPUT_METHOD_KIT_FRAMEWORK})
    add_custom_target(MetasequoiaIMESign ALL COMMAND /usr/bin/codesign --force --deep --sign - "$<TARGET_BUNDLE_DIR:MetasequoiaIME>" DEPENDS MetasequoiaIME VERBATIM)
    if(BUILD_TESTING)
        add_executable(MetasequoiaDictionaryInstallerTests tests/DictionaryInstallerTests.mm src/DictionaryInstaller.mm)
        target_compile_options(MetasequoiaDictionaryInstallerTests PRIVATE -fobjc-arc -Wall -Wextra -Wpedantic -Werror)
        target_link_libraries(MetasequoiaDictionaryInstallerTests PRIVATE MetasequoiaIme::Engine ${APPKIT_FRAMEWORK})
        add_test(NAME dictionary_installer COMMAND MetasequoiaDictionaryInstallerTests)
        add_test(NAME release_package COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/ReleasePackageTests.py $<TARGET_BUNDLE_DIR:MetasequoiaIME>)
        set_tests_properties(release_package PROPERTIES TIMEOUT 120)
    endif()
endif()
