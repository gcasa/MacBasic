#import <AppKit/AppKit.h>
#import "MBAppDelegate.h"
#import "MBCompiler.h"
#import "MBDocument.h"
#import "MBInterpreter.h"
#include <stdlib.h>

@interface MBConsolePlatform : NSObject <MBPlatform> @end
@implementation MBConsolePlatform
- (void)writeText:(NSString *)text { fprintf(stdout, "%s", text.UTF8String); fflush(stdout); }
- (void)clearText {}
- (NSString *)readInput:(NSString *)prompt {
    [self writeText:prompt]; char buffer[4096] = {0};
    return fgets(buffer, sizeof buffer, stdin) ? [NSString stringWithUTF8String:buffer] : @"";
}
- (NSString *)openPanelWithTitle:(NSString *)title directory:(NSString *)directory allowedTypes:(NSString *)allowedTypes { return @""; }
- (NSString *)savePanelWithTitle:(NSString *)title directory:(NSString *)directory defaultName:(NSString *)defaultName allowedTypes:(NSString *)allowedTypes { return @""; }
- (void)openWindowWithID:(NSInteger)windowID title:(NSString *)t width:(CGFloat)w height:(CGFloat)h x:(CGFloat)x y:(CGFloat)y {
    fprintf(stderr, "MacBasic: WINDOW OPEN ignored in console mode (ID %ld, %s)\n",(long)windowID,t.UTF8String);
}
- (void)closeWindowWithID:(NSInteger)windowID {}
- (void)addViewWithID:(NSInteger)viewID toWindowID:(NSInteger)windowID x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
    fprintf(stderr, "MacBasic: VIEW ADD ignored in console mode (view ID %ld, window ID %ld)\n",(long)viewID,(long)windowID);
}
- (void)drawCommand:(NSString *)command onViewID:(NSInteger)viewID arguments:(NSArray *)arguments {}
- (void)playSound:(NSString *)name { fprintf(stderr, "MacBasic: SOUND PLAY ignored in console mode (%s)\n", name.UTF8String); }
- (void)playTone:(double)frequency duration:(double)duration volume:(double)volume voice:(NSInteger)voice waveform:(NSInteger)waveform {
    fprintf(stderr, "MacBasic: SOUND tone ignored in console mode\n");
}
- (void)speakText:(NSString *)text { fprintf(stderr, "MacBasic: SAY ignored in console mode (%s)\n", text.UTF8String); }
- (void)stopSounds {}
- (void)beep { fputc('\a', stderr); fflush(stderr); }
- (id)inputValue:(NSString *)name argument:(NSInteger)argument { return [name hasSuffix:@"$"]?@"":@0; }
- (void)setMenu:(NSInteger)menu item:(NSInteger)item state:(NSInteger)state title:(NSString *)title {}
- (NSInteger)menuValue:(NSInteger)which reset:(BOOL)reset { return 0; }
- (void)runProcess:(NSString *)path arguments:(NSArray *)args {
    NSTask *task = [NSTask new]; task.launchPath = path; task.arguments = args;
    @try { [task launch]; } @catch (NSException *e) {
        fprintf(stderr, "MacBasic: process failed: %s\n", e.reason.UTF8String);
    }
}
@end

@interface MBCompiledAppDelegate : NSObject <NSApplicationDelegate> {
    NSString *_source;
    MBDocument *_document;
}
@property (copy) NSString *source;
@property (retain) MBDocument *document;
@end
@implementation MBCompiledAppDelegate
@synthesize source=_source, document=_document;
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.document=[[MBDocument alloc]init];
    [self.document runCompiledSource:self.source];
#if !defined(GNUSTEP)
    [NSApp activateIgnoringOtherApps:YES];
#endif
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {return YES;}
@end

#if defined(GNUSTEP)
static BOOL MBHasDisplay(void) {
    const char *display = getenv("DISPLAY");
    return display && display[0];
}

static void MBPrintDisplayError(BOOL compiled) {
    if (compiled)
        fprintf(stderr, "MacBasic: cannot start the GUI because DISPLAY is not set. Run with --console for headless execution, or start an X server and launch the app from that session.\n");
    else
        fprintf(stderr, "MacBasic: cannot start the IDE because DISPLAY is not set. Pass a .bas file to run in console mode, or start an X server and launch the app from that session.\n");
}
#endif

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        BOOL compileTool=argc==4&&(strcmp(argv[1],"--compile")==0||strcmp(argv[1],"--compile-tool")==0);
        BOOL compileApp=(argc==4||argc==5)&&strcmp(argv[1],"--compile-app")==0;
        if(compileTool||compileApp){
            NSError *error=nil;
            NSString *source=[NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]
                encoding:NSUTF8StringEncoding error:&error];
            NSString *output=[NSString stringWithUTF8String:argv[3]];
            NSString *icon=compileApp&&argc==5?[NSString stringWithUTF8String:argv[4]]:nil;
            BOOL ok=source&&(compileApp?MBCompileApplication(source,output,icon,&error)
                                          :MBCompileSource(source,output,&error));
            if(!ok){
                fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;
            }
            return 0;
        }
        NSError *embeddedError=nil;
        NSString *embeddedSource=MBEmbeddedSource(&embeddedError);
        if(embeddedError){fprintf(stderr,"%s\n",embeddedError.localizedDescription.UTF8String);return 1;}
        if(embeddedSource){
            if(argc>1&&strcmp(argv[1],"--console")==0){
                NSError *error=nil;
                MBInterpreter *basic=[[MBInterpreter alloc]initWithPlatform:[MBConsolePlatform new]];
                if(![basic runSource:embeddedSource error:&error]){
                    fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;
                }
                return 0;
            }
#if defined(GNUSTEP)
            if(!MBHasDisplay()){MBPrintDisplayError(YES);return 1;}
#endif
            NSApplication *app=[NSApplication sharedApplication];
            MBCompiledAppDelegate *delegate=[MBCompiledAppDelegate new];
            delegate.source=embeddedSource;app.delegate=delegate;[app run];return 0;
        }
        if (argc > 1) {
            NSString *path = [NSString stringWithUTF8String:argv[1]];
            NSError *error = nil;
            NSString *source = [NSString stringWithContentsOfFile:path
                                                         encoding:NSUTF8StringEncoding error:&error];
            if (!source) { fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 1; }
            MBInterpreter *basic = [[MBInterpreter alloc] initWithPlatform:[MBConsolePlatform new]];
            if (![basic runSource:source error:&error]) {
                fprintf(stderr, "%s\n", error.localizedDescription.UTF8String); return 1;
            }
            return 0;
        }
#if defined(GNUSTEP)
        if(!MBHasDisplay()){MBPrintDisplayError(NO);return 1;}
#endif
        NSApplication *app = [NSApplication sharedApplication];
        MBAppDelegate *delegate = [MBAppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
