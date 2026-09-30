#import "MBInterpreter.h"
@interface TraceProbe : NSObject {
    BOOL _sawLocal;
    BOOL _sawGlobal;
    BOOL _sawNested;
    BOOL _sawShadow;
    NSDictionary *_saved;
}
@property BOOL sawLocal;
@property BOOL sawGlobal;
@property BOOL sawNested;
@property BOOL sawShadow;
@property (copy) NSDictionary *saved;
@end
@implementation TraceProbe
@synthesize sawLocal=_sawLocal, sawGlobal=_sawGlobal, saved=_saved;
@synthesize sawNested=_sawNested, sawShadow=_sawShadow;
- (id)inputValue:(NSString *)name argument:(NSInteger)argument { return @0; }
- (void)debugLine:(NSUInteger)line globals:(NSDictionary *)globals locals:(NSDictionary *)locals breakpoint:(BOOL)breakpoint {
    NSCAssert(![locals objectForKey:@"A"], @"Inherited global array must not appear in locals");
    NSCAssert(![locals objectForKey:@"GLOBALONLY"], @"Inherited global scalar must not appear in locals");
    if([locals objectForKey:@"CHILD"]){
        NSCAssert(locals.count==1, @"Nested procedure must not list caller variables");
        self.sawNested=YES;
    }
    if([locals objectForKey:@"SAME"]){
        NSCAssert([[locals objectForKey:@"SAME"] isEqual:[globals objectForKey:@"SAME"]], @"Equal-valued local assignment missing");
        self.sawShadow=YES;
    }
    if([[locals objectForKey:@"X"] isEqual:@"9"]){
        NSCAssert([[globals objectForKey:@"X"] isEqual:@"1"], @"Local must not replace global");
        NSCAssert([[locals objectForKey:@"LABEL$"] isEqual:@"\"local\""], @"String value missing");
        self.sawLocal=YES;
    }
    if([[globals objectForKey:@"X"] isEqual:@"2"]){
        NSCAssert(!locals.count, @"Locals must clear after returning");
        self.sawGlobal=YES;
    }
    if(!self.saved && [[globals objectForKey:@"A"] containsString:@"(1) = 7"])self.saved=globals;
}
@end
int main(void) { @autoreleasepool {
    TraceProbe *probe=[TraceProbe new];
    MBInterpreter *interpreter=[[MBInterpreter alloc]initWithPlatform:(id<MBPlatform>)probe];
    interpreter.tracing=YES;
    NSError *error=nil;
    BOOL ok=[interpreter runSource:@"SUB Nested(child)\nchild = child\nEND SUB\nSUB Work(x)\nlabel$ = \"local\"\nx = 9\nlabel$ = label$\nNested(x)\nsame = 5\nsame = same\nEND SUB\nx = 1\nglobalOnly = 42\nsame = 5\nDIM a(2)\na(1) = 7\nWork(3)\na(1) = 8\nx = 2\nEND\n" error:&error];
    NSCAssert(ok, @"%@", error);
    NSCAssert(probe.sawLocal && probe.sawGlobal, @"Missing scope snapshots");
    NSCAssert(probe.sawNested && probe.sawShadow, @"Missing nested or shadowed local snapshots");
    NSCAssert([[probe.saved objectForKey:@"A"] containsString:@"(1) = 7"], @"Snapshot mutated");
} return 0; }
