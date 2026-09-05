#pragma once

#import <AppKit/AppKit.h>

inline NSMenuItem *CreateInputModeItem(NSString *title, SEL action, id target, BOOL selected)
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target = target;
    item.enabled = YES;
    item.state = selected ? NSControlStateValueOn : NSControlStateValueOff;
    return item;
}

inline NSMenu *CreateMetasequoiaInputMenu(id target, BOOL englishMode, BOOL traditionalOutput)
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"水杉输入法"];
    menu.autoenablesItems = NO;

    [menu addItem:CreateInputModeItem(@"中文输入", @selector(selectChineseMode:), target, !englishMode)];
    [menu addItem:CreateInputModeItem(@"英文输入", @selector(selectEnglishMode:), target, englishMode)];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:CreateInputModeItem(@"简体输出", @selector(selectSimplifiedOutput:), target,
                                     !traditionalOutput)];
    [menu addItem:CreateInputModeItem(@"繁体输出", @selector(selectTraditionalOutput:), target,
                                     traditionalOutput)];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *updateItem = [[NSMenuItem alloc] initWithTitle:@"检查更新…"
                                                        action:@selector(checkForUpdates:)
                                                 keyEquivalent:@""];
    updateItem.target = target;
    updateItem.enabled = YES;
    [menu addItem:updateItem];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"水杉输入法设置…"
                                                          action:@selector(showPreferences:)
                                                   keyEquivalent:@""];
    settingsItem.target = target;
    settingsItem.enabled = YES;
    [menu addItem:settingsItem];
    return menu;
}
