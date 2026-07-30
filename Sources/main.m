#import <AppKit/AppKit.h>
#import "MBAppDelegate.h"
#import "MBCompiler.h"
#import "MBDocument.h"
#import "MBInterpreter.h"

@interface MBConsolePlatform : NSObject <MBPlatform> @end
@implementation MBConsolePlatform
- (void)writeText:(NSString *)text { fprintf(stdout, "%s", text.UTF8String); fflush(stdout); }
- (void)clearText {}
- (NSString *)readInput:(NSString *)prompt {
    [self writeText:prompt]; char buffer[4096] = {0};
    return fgets(buffer, sizeof buffer, stdin) ? [NSString stringWithUTF8String:buffer] : @"";
}
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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if(argc==4&&strcmp(argv[1],"--compile")==0){
            NSError *error=nil;
            NSString *source=[NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]
                encoding:NSUTF8StringEncoding error:&error];
            if(!source||!MBCompileSource(source,[NSString stringWithUTF8String:argv[3]],&error)){
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
        NSApplication *app = [NSApplication sharedApplication];
        MBAppDelegate *delegate = [MBAppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
