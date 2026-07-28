#import <AppKit/AppKit.h>
#import "MBAppDelegate.h"
#import "MBInterpreter.h"

@interface MBConsolePlatform : NSObject <MBPlatform> @end
@implementation MBConsolePlatform
- (void)writeText:(NSString *)text { fprintf(stdout, "%s", text.UTF8String); fflush(stdout); }
- (void)clearText {}
- (NSString *)readInput:(NSString *)prompt {
    [self writeText:prompt]; char buffer[4096] = {0};
    return fgets(buffer, sizeof buffer, stdin) ? [NSString stringWithUTF8String:buffer] : @"";
}
- (void)openWindowWithTitle:(NSString *)t width:(CGFloat)w height:(CGFloat)h x:(CGFloat)x y:(CGFloat)y {
    fprintf(stderr, "MacBasic: WINDOW OPEN ignored in console mode (%s)\n", t.UTF8String);
}
- (void)closeWindowWithTitle:(NSString *)t {}
- (void)addViewNamed:(NSString *)name toWindow:(NSString *)window x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
    fprintf(stderr, "MacBasic: VIEW ADD ignored in console mode (%s)\n", name.UTF8String);
}
- (void)drawCommand:(NSString *)command onView:(NSString *)view arguments:(NSArray *)arguments {}
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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
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
