#import "MBCompiler.h"
#import "MBInterpreter.h"
#include <sys/stat.h>

static NSString *const MBCompilerErrorDomain=@"MacBasic.Compiler";

static NSString *MBExecutablePath(void) {
    NSString *path=[[NSBundle mainBundle]executablePath];
    if(path.length)return path;
    NSArray *arguments=[[NSProcessInfo processInfo]arguments];
    if(!arguments.count)return nil;
    return [[arguments objectAtIndex:0]stringByStandardizingPath];
}

static NSString *MBRuntimeLibraryPath(void) {
    NSString *executable=MBExecutablePath();
    NSArray *candidates=@[
        [[[NSBundle mainBundle]resourcePath]?:@"" stringByAppendingPathComponent:@"libMacBasicRuntime.a"],
        [[executable stringByDeletingLastPathComponent]stringByAppendingPathComponent:@"libMacBasicRuntime.a"],
        [@"build" stringByAppendingPathComponent:@"libMacBasicRuntime.a"]
    ];
    for(NSString *path in candidates)
        if(path.length&&[[NSFileManager defaultManager]fileExistsAtPath:path])return [path stringByStandardizingPath];
    return nil;
}

static NSString *MBCStringData(NSString *source) {
    NSData *data=[source dataUsingEncoding:NSUTF8StringEncoding];
    const unsigned char *bytes=data.bytes;
    NSMutableString *result=[NSMutableString stringWithString:@"{"];
    for(NSUInteger i=0;i<data.length;i++){
        if(i)[result appendString:@","];
        [result appendFormat:@"%u",(unsigned)bytes[i]];
    }
    [result appendString:@",0}"];
    return result;
}

static NSString *MBGeneratedMain(NSString *source,BOOL application) {
    NSString *bytes=MBCStringData(source);
    NSString *console=
          @"@interface C:NSObject<MBPlatform>@end\n@implementation C\n"
          "-(void)writeText:(NSString*)s{fputs(s.UTF8String,stdout);fflush(stdout);}"
          "-(void)clearText{}-(NSString*)readInput:(NSString*)p{[self writeText:p];char b[4096]={0};return fgets(b,sizeof b,stdin)?[NSString stringWithUTF8String:b]:@\"\";}"
          "-(NSString*)openPanelWithTitle:(NSString*)t directory:(NSString*)d allowedTypes:(NSString*)y{return @\"\";}"
          "-(NSString*)savePanelWithTitle:(NSString*)t directory:(NSString*)d defaultName:(NSString*)n allowedTypes:(NSString*)y{return @\"\";}"
          "-(void)openWindowWithID:(NSInteger)i title:(NSString*)t width:(CGFloat)w height:(CGFloat)h x:(CGFloat)x y:(CGFloat)y{}"
          "-(void)closeWindowWithID:(NSInteger)i{}-(void)addViewWithID:(NSInteger)v toWindowID:(NSInteger)i x:(CGFloat)x y:(CGFloat)y width:(CGFloat)w height:(CGFloat)h{}"
          "-(void)drawCommand:(NSString*)c onViewID:(NSInteger)v arguments:(NSArray*)a{}-(void)playSound:(NSString*)n{}"
          "-(void)playTone:(double)f duration:(double)d volume:(double)v voice:(NSInteger)i waveform:(NSInteger)w{}-(void)speakText:(NSString*)t{}-(void)stopSounds{}"
          "-(void)beep{fputc('\\a',stderr);}-(id)inputValue:(NSString*)n argument:(NSInteger)a{return[n hasSuffix:@\"$\"]?@\"\":@0;}"
          "-(void)setMenu:(NSInteger)m item:(NSInteger)i state:(NSInteger)s title:(NSString*)t{}-(NSInteger)menuValue:(NSInteger)w reset:(BOOL)r{return 0;}"
          "-(void)runProcess:(NSString*)p arguments:(NSArray*)a{NSTask*t=[NSTask new];t.launchPath=p;t.arguments=a;[t launch];}@end\n";
    NSString *run=@"static int R(void){@autoreleasepool{NSError*e=nil;MBInterpreter*b=[[MBInterpreter alloc]initWithPlatform:[C new]];"
          "if(![b runSource:P() error:&e]){fprintf(stderr,\"%s\\n\",e.localizedDescription.UTF8String);return 1;}}return 0;}\n";
    NSString *platform=application
        ?[console stringByAppendingString:[run stringByAppendingString:
          @"@interface MBDocument:NSDocument\n-(void)runCompiledSource:(NSString*)s;\n@end\n"
          "BOOL MBCompileSource(NSString*s,NSString*p,NSError**e){return NO;}"
          "BOOL MBCompileApplication(NSString*s,NSString*p,NSString*i,NSError**e){return NO;}\n"
          "@interface D:NSObject<NSApplicationDelegate>{MBDocument*_d;}@end\n"
          "@implementation D\n-(void)applicationDidFinishLaunching:(NSNotification*)n{_d=[MBDocument new];[_d runCompiledSource:P()];\n"
          "#if !defined(GNUSTEP)\n[NSApp activateIgnoringOtherApps:YES];\n#endif\n}"
          "-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)s{return YES;}@end\n"
          "int main(int c,const char**v){if(c>1&&strcmp(v[1],\"--console\")==0)return R();\n"
          "#if defined(GNUSTEP)\nconst char*dsp=getenv(\"DISPLAY\");if(!dsp||!*dsp){fprintf(stderr,\"MacBasic: cannot start the GUI because DISPLAY is not set. Run with --console for headless execution, or start an X server and launch the app from that session.\\n\");return 1;}\n#endif\n"
          "@autoreleasepool{NSApplication*a=[NSApplication sharedApplication];D*d=[D new];a.delegate=d;[a run];}return 0;}\n"]]
        :[console stringByAppendingString:[run stringByAppendingString:@"int main(){return R();}\n"]];
    return [NSString stringWithFormat:
        @"#import <AppKit/AppKit.h>\n#import \"MBInterpreter.h\"\n#include <stdlib.h>\n"
         "static const unsigned char S[]=%@;\nstatic NSString*P(void){return [[NSString alloc]initWithUTF8String:(const char*)S];}\n%@",
        bytes,platform];
}

#if defined(GNUSTEP)
static NSArray *MBCommandOutput(NSString *path,NSArray *arguments) {
    NSTask *task=[NSTask new];NSPipe *pipe=[NSPipe pipe];task.launchPath=path;task.arguments=arguments;task.standardOutput=pipe;
    @try{[task launch];[task waitUntilExit];}@catch(NSException *exception){return @[];}
    NSData *data=[[pipe fileHandleForReading]readDataToEndOfFile];
    NSString *text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]?:@"";
    return [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSArray *MBGNUstepConfigOutput(NSString *option) {
    NSArray *output=MBCommandOutput(@"/usr/bin/env",@[@"gnustep-config",option]);
    return output.count>1?output:MBCommandOutput(@"/usr/bin/gnustep-config",@[option]);
}
#endif

static BOOL MBRunClang(NSString *source,NSString *outputPath,BOOL application,NSError **error) {
    MBInterpreter *validator=[[MBInterpreter alloc]initWithPlatform:nil];
    if(![validator validateSource:source error:error])return NO;
    NSString *library=MBRuntimeLibraryPath();
    if(!library){
        if(error)*error=[NSError errorWithDomain:MBCompilerErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:
            @"The MacBasic native support library could not be found. Rebuild MacBasic before compiling programs."}];
        return NO;
    }
    NSString *temporary=[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID]UUIDString]];
    NSString *main=[temporary stringByAppendingPathExtension:@"m"];
    if(![[MBGeneratedMain(source,application) dataUsingEncoding:NSUTF8StringEncoding]
        writeToFile:main options:NSDataWritingAtomic error:error])return NO;
    NSMutableArray *arguments=[NSMutableArray array];
#if defined(GNUSTEP)
    for(NSString *item in MBGNUstepConfigOutput(@"--objc-flags"))if(item.length)[arguments addObject:item];
    NSArray *gccInclude=MBCommandOutput(@"/usr/bin/env",@[@"gcc",@"-print-file-name=include"]);
    for(NSString *item in gccInclude)if(item.length){
        [arguments addObject:@"-I"];
        [arguments addObject:item];
        break;
    }
#else
    [arguments addObjectsFromArray:@[@"-fobjc-arc",@"-fmodules"]];
#endif
    NSString *header=[[[NSBundle mainBundle]resourcePath]?:@"Sources" stringByAppendingPathComponent:@"MBInterpreter.h"];
    if(![[NSFileManager defaultManager]fileExistsAtPath:header])header=@"Sources/MBInterpreter.h";
    [arguments addObjectsFromArray:@[@"-I",[header stringByDeletingLastPathComponent],@"-o",outputPath,main,library]];
#if defined(GNUSTEP)
    for(NSString *item in MBGNUstepConfigOutput(@"--gui-libs"))if(item.length)[arguments addObject:item];
    [arguments addObject:@"-lsqlite3"];
#else
    [arguments addObjectsFromArray:@[@"-framework",@"Cocoa",@"-lsqlite3"]];
#endif
    NSTask *task=[NSTask new];NSPipe *diagnostics=[NSPipe pipe];task.launchPath=@"/usr/bin/clang";task.arguments=arguments;
    task.standardError=diagnostics;
    @try{[task launch];[task waitUntilExit];}@catch(NSException *exception){
        if(error)*error=[NSError errorWithDomain:MBCompilerErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey:exception.reason}];
        [[NSFileManager defaultManager]removeItemAtPath:main error:NULL];return NO;
    }
    NSData *diagnosticData=[[diagnostics fileHandleForReading]readDataToEndOfFile];
    [[NSFileManager defaultManager]removeItemAtPath:main error:NULL];
    if(task.terminationStatus!=0){
        NSString *message=[[NSString alloc]initWithData:diagnosticData encoding:NSUTF8StringEncoding];
        if(error)*error=[NSError errorWithDomain:MBCompilerErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey:
            message.length?message:@"Clang could not build the native program."}];
        return NO;
    }
    return chmod(outputPath.fileSystemRepresentation,0755)==0;
}

BOOL MBCompileSource(NSString *source,NSString *outputPath,NSError **error) {
    return MBRunClang(source,outputPath,NO,error);
}

static NSString *MBGenericIconPath(void) {
#if defined(GNUSTEP)
    NSString *name=@"MacBasicIcon.png";
#else
    NSString *name=@"MacBasic.icns";
#endif
    NSString *bundled=[[NSBundle mainBundle]pathForResource:[name stringByDeletingPathExtension]
        ofType:[name pathExtension]];
    if(bundled.length)return bundled;
    NSString *local=[[@"Resources" stringByAppendingPathComponent:name]stringByStandardizingPath];
    return [[NSFileManager defaultManager]fileExistsAtPath:local]?local:nil;
}

static NSString *MBExecutableName(NSString *outputPath) {
    NSString *name=[[outputPath lastPathComponent]stringByDeletingPathExtension];
    return name.length?name:@"MacBasicProgram";
}

#if !defined(GNUSTEP)
static NSString *MBIdentifierPart(NSString *name) {
    NSMutableString *part=[NSMutableString string];
    NSCharacterSet *allowed=[NSCharacterSet alphanumericCharacterSet];
    for(NSUInteger i=0;i<name.length;i++){
        unichar c=[name characterAtIndex:i];
        [part appendFormat:@"%C",(unichar)([allowed characterIsMember:c]?c:'-')];
    }
    return part.length?[part lowercaseString]:@"program";
}
#endif

BOOL MBCompileApplication(NSString *source,NSString *outputPath,NSString *iconPath,NSError **error) {
    NSFileManager *files=[NSFileManager defaultManager];
    NSString *wrapper=[outputPath pathExtension].length?outputPath:[outputPath stringByAppendingPathExtension:@"app"];
    if([[wrapper pathExtension]caseInsensitiveCompare:@"app"]!=NSOrderedSame)
        wrapper=[wrapper stringByAppendingPathExtension:@"app"];
    if([files fileExistsAtPath:wrapper]&&![files removeItemAtPath:wrapper error:error])return NO;

    NSString *name=MBExecutableName(wrapper);
#if defined(GNUSTEP)
    NSString *resources=[wrapper stringByAppendingPathComponent:@"Resources"];
    NSString *executable=[wrapper stringByAppendingPathComponent:name];
#else
    NSString *contents=[wrapper stringByAppendingPathComponent:@"Contents"];
    NSString *resources=[contents stringByAppendingPathComponent:@"Resources"];
    NSString *executable=[[contents stringByAppendingPathComponent:@"MacOS"]stringByAppendingPathComponent:name];
#endif
    if(![files createDirectoryAtPath:[executable stringByDeletingLastPathComponent]
        withIntermediateDirectories:YES attributes:nil error:error])return NO;
    if(![files createDirectoryAtPath:resources withIntermediateDirectories:YES attributes:nil error:error])return NO;
    if(!MBRunClang(source,executable,YES,error))return NO;

    NSString *chosenIcon=iconPath.length?iconPath:MBGenericIconPath();
    NSString *iconName=nil;
    if(!chosenIcon.length||![files fileExistsAtPath:chosenIcon]){
        if(error){
            NSString *message=iconPath.length
                ?[NSString stringWithFormat:@"The icon could not be found at %@.",iconPath]
                :@"The generic MacBasic application icon could not be found.";
            *error=[NSError errorWithDomain:@"MacBasicCompiler" code:4
                userInfo:@{NSLocalizedDescriptionKey:message}];
        }
        return NO;
    }
    iconName=[chosenIcon lastPathComponent];
    NSString *destination=[resources stringByAppendingPathComponent:iconName];
    if(![files copyItemAtPath:chosenIcon toPath:destination error:error])return NO;

#if defined(GNUSTEP)
    NSString *info=[NSString stringWithFormat:
        @"{\n ApplicationName = \"%@\";\n ApplicationDescription = \"Compiled MacBasic program\";\n"
         " NSExecutable = \"%@\";\n NSPrincipalClass = NSApplication;\n%@}\n",
        name,name,iconName?[NSString stringWithFormat:@" ApplicationIcon = \"%@\";\n",iconName]:@""];
    NSString *infoPath=[resources stringByAppendingPathComponent:@"Info-gnustep.plist"];
    return [info writeToFile:infoPath atomically:YES encoding:NSUTF8StringEncoding error:error];
#else
    NSMutableDictionary *info=[@{@"CFBundleExecutable":name,@"CFBundleIdentifier":
        [@"org.macbasic.compiled." stringByAppendingString:MBIdentifierPart(name)],
        @"CFBundleName":name,@"CFBundlePackageType":@"APPL",@"CFBundleVersion":@"1",
        @"CFBundleShortVersionString":@"1.0",@"NSPrincipalClass":@"NSApplication"}mutableCopy];
    if(iconName)[info setObject:iconName forKey:@"CFBundleIconFile"];
    NSData *plist=[NSPropertyListSerialization dataWithPropertyList:info
        format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    if(!plist)return NO;
    NSString *infoPath=[[wrapper stringByAppendingPathComponent:@"Contents"]stringByAppendingPathComponent:@"Info.plist"];
    return [plist writeToFile:infoPath options:NSDataWritingAtomic error:error];
#endif
}

NSString *MBEmbeddedSource(NSError **error) {
    return nil;
}
