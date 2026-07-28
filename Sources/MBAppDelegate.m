#import "MBAppDelegate.h"

@implementation MBAppDelegate
- (void)installMenus {
    NSMenu *bar=[[NSMenu alloc]initWithTitle:@""];
    NSMenuItem *appItem=[[NSMenuItem alloc]initWithTitle:@"MacBasic" action:NULL keyEquivalent:@""];
    NSMenuItem *fileItem=[[NSMenuItem alloc]initWithTitle:@"File" action:NULL keyEquivalent:@""];
    NSMenuItem *editItem=[[NSMenuItem alloc]initWithTitle:@"Edit" action:NULL keyEquivalent:@""];
    [bar addItem:appItem];[bar addItem:fileItem];[bar addItem:editItem];NSApp.mainMenu=bar;

    NSMenu *app=[[NSMenu alloc]initWithTitle:@"MacBasic"];
    [app addItemWithTitle:@"About MacBasic" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [app addItem:[NSMenuItem separatorItem]];
    [app addItemWithTitle:@"Quit MacBasic" action:@selector(terminate:) keyEquivalent:@"q"];
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
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self installMenus];
    if ([NSDocumentController sharedDocumentController].documents.count == 0) {
        [[NSDocumentController sharedDocumentController]
            openUntitledDocumentAndDisplay:YES error:nil];
    }
#if !defined(GNUSTEP)
    [NSApp activateIgnoringOtherApps:YES];
#endif
}
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender { return YES; }
@end
