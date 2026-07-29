#import "MBAppDelegate.h"

@implementation MBAppDelegate
- (void)installMenus {
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"ApplicationName"];
    if (!appName.length) appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    if (!appName.length) appName = [[NSProcessInfo processInfo] processName];

    NSMenu *bar=[[NSMenu alloc]initWithTitle:appName];
#if !defined(GNUSTEP)
    NSMenuItem *appItem=[[NSMenuItem alloc]initWithTitle:appName action:NULL keyEquivalent:@""];
#else
    NSMenuItem *appItem=[[NSMenuItem alloc]initWithTitle:@"Info" action:NULL keyEquivalent:@""];
#endif
    NSMenuItem *fileItem=[[NSMenuItem alloc]initWithTitle:@"File" action:NULL keyEquivalent:@""];
    NSMenuItem *editItem=[[NSMenuItem alloc]initWithTitle:@"Edit" action:NULL keyEquivalent:@""];
    [bar addItem:appItem];[bar addItem:fileItem];[bar addItem:editItem];NSApp.mainMenu=bar;

    NSMenu *app=[[NSMenu alloc]initWithTitle:appItem.title];
    [app addItemWithTitle:[NSString stringWithFormat:@"About %@", appName] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
#if !defined(GNUSTEP)
    [app addItem:[NSMenuItem separatorItem]];
    [app addItemWithTitle:[NSString stringWithFormat:@"Quit %@", appName] action:@selector(terminate:) keyEquivalent:@"q"];
#endif
    appItem.submenu=app;

    NSMenu *file=[[NSMenu alloc]initWithTitle:@"File"];
    [file addItemWithTitle:@"New" action:@selector(newDocument:) keyEquivalent:@"n"];
    [file addItemWithTitle:@"Open…" action:@selector(openDocument:) keyEquivalent:@"o"];
    [file addItem:[NSMenuItem separatorItem]];
    [file addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
    [file addItemWithTitle:@"Save" action:@selector(saveDocument:) keyEquivalent:@"s"];
    [file addItemWithTitle:@"Save As…" action:@selector(saveDocumentAs:) keyEquivalent:@"S"];
    fileItem.submenu=file;

    NSMenu *edit=[[NSMenu alloc]initWithTitle:@"Edit"];
    [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [edit addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [edit addItem:[NSMenuItem separatorItem]];
    [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItem:[NSMenuItem separatorItem]];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu=edit;

#if defined(GNUSTEP)
    [bar addItem:[NSMenuItem separatorItem]];
    [bar addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
#endif
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self installMenus];
    if ([[[NSDocumentController sharedDocumentController]documents]count] == 0) {
        [[NSDocumentController sharedDocumentController]
            openUntitledDocumentAndDisplay:YES error:NULL];
    }
#if !defined(GNUSTEP)
    [NSApp activateIgnoringOtherApps:YES];
#endif
}
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender { return YES; }
@end
