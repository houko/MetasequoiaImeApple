#pragma once

#import <AppKit/AppKit.h>

inline NSMenu *CreateMetasequoiaInputMenu(id target)
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"水杉输入法"];
    menu.autoenablesItems = NO;

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"水杉输入法设置…"
                                                          action:@selector(showPreferences:)
                                                   keyEquivalent:@""];
    settingsItem.target = target;
    settingsItem.enabled = YES;
    [menu addItem:settingsItem];
    return menu;
}
