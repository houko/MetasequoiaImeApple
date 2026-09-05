// Exercise the real controller with a recording window boundary. A headless
// IMKCandidates cannot render without a registered input-method client.
#include "../src/MetasequoiaInputController.mm"
#include "../../../vendor/MetasequoiaImeEngine/user_dictionary/user_dictionary_journal.h"
#include <sqlite3.h>
#include <filesystem>
#include <stdexcept>

static void Require(bool condition, const char *message)
{
    if (!condition) throw std::runtime_error(message);
}

@interface RecordingCandidatePanel : NSObject
@property(nonatomic, copy) NSArray *data;
@property(nonatomic, copy) NSArray *selectionKeys;
@property(nonatomic) IMKCandidatePanelType panelType;
@property(nonatomic) NSInteger selected;
@property(nonatomic) BOOL visible;
@property(nonatomic) NSRect caretRect;
@property(nonatomic) BOOL hasPreviousPage;
@property(nonatomic) BOOL hasNextPage;
@property(nonatomic) BOOL collapsedIdentifiers;
@property(nonatomic, strong) NSNumber *rejectedEngineIndex;
@end
@implementation RecordingCandidatePanel
- (void)setAttributes:(NSDictionary *)attributes { (void)attributes; }
- (void)setCandidateData:(NSArray *)data { self.data = data; self.selected = 0; }
- (void)show:(IMKCandidatesLocationHint)hint { (void)hint; self.visible = YES; }
- (void)hide { self.visible = NO; }
- (BOOL)isVisible { return self.visible; }
- (NSInteger)candidateIdentifierAtLineNumber:(NSInteger)line
{
    return line >= 0 && (NSUInteger)line < self.data.count ? (self.collapsedIdentifiers ? 0 : 100 + line * 3) : NSNotFound;
}
- (NSInteger)lineNumberForCandidateWithIdentifier:(NSInteger)identifier
{ return self.collapsedIdentifiers ? 0 : (identifier - 100) / 3; }
- (BOOL)selectCandidateWithIdentifier:(NSInteger)identifier
{
    const NSInteger line = self.collapsedIdentifiers ? identifier : [self lineNumberForCandidateWithIdentifier:identifier];
    if (line < 0 || (NSUInteger)line >= self.data.count) return NO;
    if (self.rejectedEngineIndex != nil && MetasequoiaCandidateIndex(self.data[line]) == self.rejectedEngineIndex.unsignedIntegerValue) return NO;
    self.selected = line;
    return YES;
}
- (NSInteger)selectedCandidate { return self.collapsedIdentifiers ? 0 : 100 + self.selected * 3; }
- (NSAttributedString *)selectedCandidateString { return self.data[self.selected]; }
- (NSInteger)candidateStringIdentifier:(NSAttributedString *)value
{
    return self.collapsedIdentifiers ? 0 : 100 + (NSInteger)[self.data indexOfObjectIdenticalTo:value] * 3;
}
@end

@interface RecordingInputClient : NSObject
@property(nonatomic, copy) NSString *committed;
@end
@implementation RecordingInputClient
- (NSDictionary *)attributesForCharacterIndex:(NSUInteger)index lineHeightRectangle:(NSRect *)rect
{ (void)index; *rect = NSMakeRect(100, 400, 1, 20); return @{}; }
- (void)insertText:(id)text replacementRange:(NSRange)range { (void)range; self.committed = text; }
- (void)setMarkedText:(id)text selectionRange:(NSRange)selection replacementRange:(NSRange)replacement
{ (void)text; (void)selection; (void)replacement; }
@end

// The test category is in the controller's translation unit so it can create a
// session without registering an input source or touching the installed dictionary.
@interface MetasequoiaInputController (PaginationTestFixture)
- (void)prepareTestPanel:(RecordingCandidatePanel *)panel;
- (NSUInteger)testCandidateCount;
- (NSString *)testCandidateAtIndex:(NSUInteger)index;
@end
@implementation MetasequoiaInputController (PaginationTestFixture)
- (void)prepareTestPanel:(RecordingCandidatePanel *)panel
{
    _candidatePanel = (MetasequoiaCandidatePanel *)panel;
    _session = std::make_unique<metasequoia::InputSession>();
    [self reloadSessionFromPreferences];
    for (char character : std::string("nihao")) _session->handle_character(character);
    [self updateCandidatePanel];
}
- (NSUInteger)testCandidateCount { return _session->candidates().size(); }
- (NSString *)testCandidateAtIndex:(NSUInteger)index
{ return MetasequoiaStringFromUtf8(_session->candidates()[index].word); }
@end

@interface PaginationTestController : MetasequoiaInputController
@property(nonatomic, strong) RecordingInputClient *testClient;
@end
@implementation PaginationTestController
- (id)client { return self.testClient; }
@end

static void Press(PaginationTestController *controller, unsigned short code, NSString *text)
{
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0
                                  timestamp:0 windowNumber:0 context:nil characters:text
                charactersIgnoringModifiers:text isARepeat:NO keyCode:code];
    Require([controller handleEvent:event client:controller.testClient], "The controller did not handle a paging test key.");
}

static void RunTests()
{
    Require([MetasequoiaInputController conformsToProtocol:@protocol(MetasequoiaFloatingToolbarDelegate)] &&
                [MetasequoiaInputController conformsToProtocol:@protocol(MetasequoiaCandidatePanelDelegate)],
            "The controller does not support both window delegate contracts.");
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    for (NSNumber *style in @[@0, @1]) for (NSNumber *size in @[@5, @7, @9])
    {
        [defaults setVolatileDomain:@{@"MetasequoiaImeCandidatePageSize":size,
            @"MetasequoiaImeCandidatePanelStyle":style,
            @"MetasequoiaImeCandidateLearning":@NO,
            @"MetasequoiaImeHelpcodeEnabled":@NO} forName:NSArgumentDomain];
        RecordingCandidatePanel *panel = [RecordingCandidatePanel new];
        PaginationTestController *controller = [PaginationTestController alloc];
        controller.testClient = [RecordingInputClient new];
        [controller prepareTestPanel:panel];
        const NSUInteger pageSize = size.unsignedIntegerValue;
        Require([controller testCandidateCount] > pageSize, "The fixture needs multiple pages.");
        Require(panel.data.count == pageSize, "The native window received more than the configured candidates per page.");
        Require([[controller candidates:nil] count] == pageSize, "The IMK callback bypassed pagination.");
        Press(controller, kVK_PageDown, @"");
        Require(MetasequoiaCandidateIndex(panel.data[0]) == pageSize, "Page Down did not start at the next engine candidate.");
        Require(panel.data.count <= pageSize, "The second page exceeded the configured page size.");
        NSString *expected = [controller testCandidateAtIndex:pageSize];
        Press(controller, kVK_ANSI_1, @"1");
        Require([controller.testClient.committed isEqualToString:expected], "Digit 1 on page two committed the wrong engine candidate.");

        [controller prepareTestPanel:panel];
        const unsigned short forward = style.intValue == 0 ? kVK_RightArrow : kVK_DownArrow;
        const unsigned short backward = style.intValue == 0 ? kVK_LeftArrow : kVK_UpArrow;
        for (NSUInteger step = 0; step < pageSize; ++step) Press(controller, forward, @"");
        Require(MetasequoiaCandidateIndex(panel.data[0]) == pageSize, "Arrow navigation did not cross the page boundary.");
        Press(controller, backward, @"");
        Require(MetasequoiaCandidateIndex(panel.data[0]) == 0, "Reverse navigation did not return to the first page.");
        expected = [controller testCandidateAtIndex:pageSize - 1];
        Press(controller, kVK_Space, @" ");
        Require([controller.testClient.committed isEqualToString:expected], "Space committed a different candidate from the highlighted one.");

        [controller prepareTestPanel:panel];
        const NSUInteger total = [controller testCandidateCount];
        for (NSUInteger page = 1; page * pageSize < total; ++page) Press(controller, kVK_PageDown, @"");
        const NSUInteger lastPageStart = pageSize == 5 ? 10 : pageSize; // fixture has 12 candidates
        Require(total == 12 && MetasequoiaCandidateIndex(panel.data[0]) == lastPageStart,
                "The last page started at the wrong engine candidate.");
        Require(panel.data.count == total - lastPageStart, "The partial last page lost candidates.");
        NSArray *lastPage = panel.data;
        Press(controller, kVK_PageDown, @"");
        Require([panel.data isEqualToArray:lastPage], "Page Down moved beyond the last page.");
        Press(controller, kVK_PageUp, @"");
        Require(MetasequoiaCandidateIndex(panel.data[0]) == lastPageStart - pageSize, "Page Up skipped a page.");

        for (NSNumber *stripped in @[@NO, @YES])
        {
            [controller prepareTestPanel:panel];
            Press(controller, kVK_PageDown, @"");
            panel.selected = 1;
            expected = [controller testCandidateAtIndex:pageSize + 1];
            NSAttributedString *clicked = panel.data[1];
            if (stripped.boolValue) clicked = [[NSAttributedString alloc] initWithString:clicked.string];
            [controller candidateSelected:clicked];
            Require([controller.testClient.committed isEqualToString:expected], "A page-two mouse callback committed the wrong engine candidate.");
        }

        if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26)
        {
            panel.collapsedIdentifiers = YES;
            [controller prepareTestPanel:panel];
            Press(controller, kVK_PageDown, @"");
            Press(controller, forward, @"");
            Require(panel.selected == 1, "Collapsed native identifiers used a global index instead of a page-local ordinal.");
            expected = [controller testCandidateAtIndex:pageSize + 1];
            Press(controller, kVK_Space, @" ");
            Require([controller.testClient.committed isEqualToString:expected], "Collapsed identifiers lost the global engine selection.");
            [controller prepareTestPanel:panel];
            Press(controller, kVK_PageDown, @"");
            panel.selected = 1;
            expected = [controller testCandidateAtIndex:pageSize + 1];
            [controller candidateSelected:[[NSAttributedString alloc] initWithString:[panel.data[1] string]]];
            Require([controller.testClient.committed isEqualToString:expected], "A stripped mouse callback with collapsed identifiers lost its page offset.");
            panel.collapsedIdentifiers = NO;
        }

        [controller prepareTestPanel:panel];
        Press(controller, forward, @"");
        panel.rejectedEngineIndex = @(pageSize);
        Press(controller, kVK_PageDown, @"");
        Require(MetasequoiaCandidateIndex(panel.data[0]) == 0 && panel.selected == 1,
                "A rejected page selection did not restore the previous page and highlight.");
        expected = [controller testCandidateAtIndex:1];
        Press(controller, kVK_Space, @" ");
        Require([controller.testClient.committed isEqualToString:expected], "Failed page navigation changed the engine selection.");
        panel.rejectedEngineIndex = nil;

        [controller prepareTestPanel:panel];
        Press(controller, kVK_PageDown, @"");
        [controller refreshCandidatePanelPreservingSelection];
        Require(MetasequoiaCandidateIndex(panel.data[0]) == pageSize, "A display refresh reset the current page.");
        Press(controller, kVK_Escape, @"");
        Require(!panel.visible && panel.data.count == 0 && [[controller candidates:nil] count] == 0,
                "Cancelling retained visible candidates.");
    }
}

int main()
{
    @autoreleasepool
    {
        [NSApplication sharedApplication];
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        std::filesystem::create_directories(directory.fileSystemRepresentation);
        setenv("METASEQUOIA_IME_DATA_DIR", directory.fileSystemRepresentation, 1);
        sqlite3 *database = nullptr;
        Require(sqlite3_open([directory stringByAppendingPathComponent:@"msime.db"].fileSystemRepresentation, &database) == SQLITE_OK, "Cannot create fixture.");
        Require(sqlite3_exec(database, "CREATE TABLE tbl_2_n(key TEXT,jp TEXT,value TEXT,weight INTEGER)", nullptr, nullptr, nullptr) == SQLITE_OK, "Cannot create table.");
        for (int index = 0; index < 12; ++index)
        {
            NSString *sql = [NSString stringWithFormat:@"INSERT INTO tbl_2_n VALUES('ni''hao','nh','候选%d',%d)", index, 120-index];
            Require(sqlite3_exec(database, sql.UTF8String, nullptr, nullptr, nullptr) == SQLITE_OK, "Cannot insert fixture.");
        }
        sqlite3_close(database);
        try { RunTests(); }
        catch (const std::exception &error)
        {
            fprintf(stderr, "%s\n", error.what());
            user_dictionary::close_default_user_database();
            std::filesystem::remove_all(directory.fileSystemRepresentation);
            return 1;
        }
        user_dictionary::close_default_user_database();
        std::filesystem::remove_all(directory.fileSystemRepresentation);
    }
}
