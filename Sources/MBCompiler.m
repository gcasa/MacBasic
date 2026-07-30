#import "MBCompiler.h"
#include <sys/stat.h>

static NSString *const MBCompilerErrorDomain=@"MacBasic.Compiler";
static const char MBSourceMarker[]="\n__MACBASIC_EMBEDDED_SOURCE_V1__\n";

static NSString *MBExecutablePath(void) {
    NSString *path=[[NSBundle mainBundle]executablePath];
    if(path.length)return path;
    NSArray *arguments=[[NSProcessInfo processInfo]arguments];
    if(!arguments.count)return nil;
    return [[arguments objectAtIndex:0]stringByStandardizingPath];
}

static NSRange MBPayloadRange(NSData *data) {
    const unsigned char *bytes=[data bytes];
    NSUInteger length=[data length],markerLength=sizeof(MBSourceMarker)-1,footerLength=markerLength+16;
    if(length<footerLength)return NSMakeRange(NSNotFound,0);
    NSUInteger markerOffset=length-footerLength;
    if(memcmp(bytes+markerOffset,MBSourceMarker,markerLength)!=0)return NSMakeRange(NSNotFound,0);
    char sizeText[17]={0};
    memcpy(sizeText,bytes+markerOffset+markerLength,16);
    char *end=NULL;
    unsigned long long sourceLength=strtoull(sizeText,&end,16);
    if(end!=sizeText+16||sourceLength>markerOffset)return NSMakeRange(NSNotFound,0);
    return NSMakeRange(markerOffset-(NSUInteger)sourceLength,(NSUInteger)sourceLength+footerLength);
}

BOOL MBCompileSource(NSString *source,NSString *outputPath,NSError **error) {
    NSString *runtimePath=MBExecutablePath();
    NSData *runtime=runtimePath?[NSData dataWithContentsOfFile:runtimePath]:nil;
    NSData *program=[source dataUsingEncoding:NSUTF8StringEncoding];
    if(!runtime||!program){
        if(error)*error=[NSError errorWithDomain:MBCompilerErrorDomain code:1
            userInfo:@{NSLocalizedDescriptionKey:@"The MacBasic runtime or source could not be read."}];
        return NO;
    }
    NSRange oldPayload=MBPayloadRange(runtime);
    if(oldPayload.location!=NSNotFound)
        runtime=[runtime subdataWithRange:NSMakeRange(0,oldPayload.location)];
    NSMutableData *compiled=[NSMutableData dataWithData:runtime];
    [compiled appendData:program];
    [compiled appendBytes:MBSourceMarker length:sizeof(MBSourceMarker)-1];
    char sizeText[17]={0};
    snprintf(sizeText,sizeof(sizeText),"%016llx",(unsigned long long)program.length);
    [compiled appendBytes:sizeText length:16];
    if(![compiled writeToFile:outputPath options:NSDataWritingAtomic error:error])return NO;
    if(chmod([outputPath fileSystemRepresentation],0755)!=0){
        if(error)*error=[NSError errorWithDomain:MBCompilerErrorDomain code:2
            userInfo:@{NSLocalizedDescriptionKey:@"The output was written but could not be made executable."}];
        return NO;
    }
    return YES;
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
    if(!MBCompileSource(source,executable,error))return NO;

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
    NSData *runtime=[NSData dataWithContentsOfFile:MBExecutablePath()];
    NSRange payload=MBPayloadRange(runtime);
    if(payload.location==NSNotFound)return nil;
    NSUInteger footerLength=(sizeof(MBSourceMarker)-1)+16;
    NSRange sourceRange=NSMakeRange(payload.location,payload.length-footerLength);
    NSString *source=[[NSString alloc]initWithData:[runtime subdataWithRange:sourceRange]
        encoding:NSUTF8StringEncoding];
    if(!source&&error)*error=[NSError errorWithDomain:MBCompilerErrorDomain code:3
        userInfo:@{NSLocalizedDescriptionKey:@"The embedded BASIC program is not valid UTF-8."}];
    return source;
}
