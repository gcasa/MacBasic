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
