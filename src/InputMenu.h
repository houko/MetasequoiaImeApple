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

inline NSMenu *CreateMetasequoiaInputMenu(id target, BOOL englishMode, NSString *availableVersion)
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"水杉输入法"];
    menu.autoenablesItems = NO;

    [menu addItem:CreateInputModeItem(@"中文输入", @selector(selectChineseMode:), target, !englishMode)];
    [menu addItem:CreateInputModeItem(@"英文输入", @selector(selectEnglishMode:), target, englishMode)];
    [menu addItem:[NSMenuItem separatorItem]];

    NSString *settingsTitle = availableVersion.length == 0
                                  ? @"水杉输入法设置…"
                                  : [NSString stringWithFormat:@"水杉输入法设置（新版本 v%@）…", availableVersion];
    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:settingsTitle
                                                          action:@selector(showPreferences:)
                                                   keyEquivalent:@""];
    settingsItem.target = target;
    settingsItem.enabled = YES;
    [menu addItem:settingsItem];
    return menu;
}
