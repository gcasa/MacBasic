#import "MBInterpreter.h"

#if __has_feature(objc_arc)
#define MB_WEAK __weak
#else
#define MB_WEAK
#endif

#define MB_KEY(value) _Generic((value), \
    char: @((long long)(value)), signed char: @((long long)(value)), unsigned char: @((unsigned long long)(value)), \
    short: @((long long)(value)), unsigned short: @((unsigned long long)(value)), \
    int: @((long long)(value)), unsigned int: @((unsigned long long)(value)), \
    long: @((long long)(value)), unsigned long: @((unsigned long long)(value)), \
    long long: @((long long)(value)), unsigned long long: @((unsigned long long)(value)), \
    default: (value))
static id MBGet(id collection,id key) {
    if([collection isKindOfClass:[NSArray class]])return [collection objectAtIndex:[key unsignedIntegerValue]];
    return [collection objectForKey:key];
}
static void MBSet(id collection,id key,id value) {
    if([collection isKindOfClass:[NSMutableArray class]])[collection replaceObjectAtIndex:[key unsignedIntegerValue] withObject:value];
    else [collection setObject:value forKey:key];
}
#define MB_GET(collection,key) MBGet((collection),MB_KEY(key))
#define MB_SET(collection,key,value) MBSet((collection),MB_KEY(key),(value))

static NSString *MBTrim(NSString *s) {
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
static BOOL MBTruth(id v) {
    if ([v isKindOfClass:[NSNumber class]]) return [v doubleValue] != 0;
    return [v isKindOfClass:[NSString class]] && [v length] != 0;
}
static NSString *MBString(id v) {
    if (!v || v == [NSNull null]) return @"";
    if ([v isKindOfClass:[NSNumber class]]) {
        double n = [v doubleValue];
        if (floor(n) == n) return [NSString stringWithFormat:@"%.0f", n];
    }
    return [v description];
}
static NSString *MBExplicitType(NSString *name) {
    if(!name.length)return nil;
    NSString *last=[name substringFromIndex:name.length-1];
    return [@"$%&!#" containsString:last]?last:nil;
}
static id MBCoerceAs(NSString *type,id value) {
    if([type isEqual:@"$"])return MBString(value);
    if([type isEqual:@"%"]||[type isEqual:@"&"])return @(llround([value doubleValue]));
    if([type isEqual:@"!"]||[type isEqual:@"#"])return @([value doubleValue]);
    return value?:@0;
}
static NSString *MBByteString(const void *bytes,NSUInteger length) {
    return [[NSString alloc]initWithBytes:bytes length:length encoding:NSISOLatin1StringEncoding]?:@"";
}

@interface MBArray : NSObject {
    NSArray *_dimensions;
    NSInteger _lowerBound;
    NSString *_elementType;
    NSMutableDictionary *_values;
}
@property (retain) NSArray<NSNumber *> *dimensions;
@property NSInteger lowerBound;
@property (copy) NSString *elementType;
@property (retain) NSMutableDictionary<NSString *, id> *values;
- (id)valueAt:(NSArray *)indices;
- (void)setValue:(id)value at:(NSArray *)indices;
@end
@implementation MBArray
@synthesize dimensions=_dimensions, lowerBound=_lowerBound, elementType=_elementType, values=_values;
- (instancetype)init {if((self=[super init]))_values=[[NSMutableDictionary alloc]init];return self;}
- (NSString *)key:(NSArray *)indices {
    if(indices.count!=self.dimensions.count)return nil;
    NSMutableArray *parts=[NSMutableArray array];
    for(NSUInteger i=0;i<indices.count;i++){NSInteger n=[MB_GET(indices,i)integerValue];
        if(n<self.lowerBound||n>[MB_GET(self.dimensions,i)integerValue])return nil;
        [parts addObject:[NSString stringWithFormat:@"%ld",(long)n]];}
    return [parts componentsJoinedByString:@","];
}
- (id)valueAt:(NSArray *)indices {NSString *k=[self key:indices];id defaultValue=[self.elementType isEqual:@"$"]?@"":@0;return k?(MB_GET(self.values,k)?:defaultValue):defaultValue;}
- (void)setValue:(id)value at:(NSArray *)indices {NSString *k=[self key:indices];if(k)MB_SET(self.values,k,MBCoerceAs(self.elementType,value));}
@end

@interface MBFile : NSObject {
    NSString *_path;
    NSString *_mode;
    NSMutableArray *_lines;
    NSMutableString *_output;
    NSUInteger _index;
    NSMutableData *_randomData;
    NSUInteger _recordLength;
    NSMutableArray *_fields;
}
@property (copy) NSString *path;
@property (copy) NSString *mode;
@property (retain) NSMutableArray<NSString *> *lines;
@property (retain) NSMutableString *output;
@property NSUInteger index;
@property (retain) NSMutableData *randomData;
@property NSUInteger recordLength;
@property (retain) NSMutableArray<NSDictionary *> *fields;
@end
@implementation MBFile
@synthesize path=_path, mode=_mode, lines=_lines, output=_output, index=_index;
@synthesize randomData=_randomData, recordLength=_recordLength, fields=_fields;
@end

@class MBInterpreter;
@interface MBExpr : NSObject {
    NSArray *_tokens;
    NSUInteger _pos;
    NSMutableDictionary *_vars;
    MB_WEAK MBInterpreter *_owner;
}
@property (retain) NSArray<NSString *> *tokens;
@property NSUInteger pos;
@property (retain) NSMutableDictionary *vars;
#if __has_feature(objc_arc)
@property (weak) MBInterpreter *owner;
#else
@property (assign) MBInterpreter *owner;
#endif
- (id)parse:(NSString *)text;
@end

@interface MBInterpreter ()
@property (retain) id<MBPlatform> platform;
@property (retain) NSArray<NSString *> *lines;
@property (retain) NSMutableDictionary<NSString *, NSDictionary *> *procedures;
@property (retain) NSMutableArray *dataItems;
@property (retain) NSMutableDictionary<NSString *, NSNumber *> *dataLabels;
@property NSUInteger dataIndex;
@property NSInteger optionBase;
@property (retain) NSMutableDictionary<NSNumber *, MBFile *> *files;
@property (retain) NSMutableDictionary<NSString *, NSNumber *> *labelLines;
@property (retain) NSMutableArray<NSNumber *> *areaPoints;
@property (retain) NSMutableDictionary<NSNumber *, NSNumber *> *waveforms;
@property (retain) NSMutableDictionary<NSNumber *, NSNumber *> *memory;
@property (retain) NSNumber *errorHandlerLine;
@property NSUInteger currentLine;
@property NSUInteger faultLine;
@property (retain) NSNumber *resumeTarget;
@property (retain) NSMutableDictionary<NSNumber *, NSMutableDictionary *> *objects;
@property (retain) NSMutableDictionary<NSString *, NSString *> *defaultTypes;
- (id)evaluate:(NSString *)text variables:(NSMutableDictionary *)vars;
- (id)call:(NSString *)name args:(NSArray *)args variables:(NSMutableDictionary *)caller error:(NSError **)error;
- (id)coerceValue:(id)value forName:(NSString *)name;
- (id)defaultValueForName:(NSString *)name;
@end

@implementation MBExpr
@synthesize tokens=_tokens, pos=_pos, vars=_vars, owner=_owner;
- (NSArray *)lex:(NSString *)s {
    NSMutableArray *a = [NSMutableArray array]; NSUInteger i = 0;
    while (i < s.length) {
        unichar c = [s characterAtIndex:i];
        if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:c]) { i++; continue; }
        if (c == '"') {
            NSMutableString *q = [NSMutableString string]; i++;
            while (i < s.length) {
                c = [s characterAtIndex:i++];
                if (c == '"' && i < s.length && [s characterAtIndex:i] == '"') { [q appendString:@"\""]; i++; continue; }
                if (c == '"') break; [q appendFormat:@"%C", c];
            }
            [a addObject:[@"\"" stringByAppendingString:q]]; continue;
        }
        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c] || c == '.') {
            NSUInteger b=i++; while(i<s.length) { c=[s characterAtIndex:i];
                if (![[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] characterIsMember:c]) break; i++; }
            [a addObject:[s substringWithRange:NSMakeRange(b,i-b)]]; continue;
        }
        if ([[NSCharacterSet letterCharacterSet] characterIsMember:c] || c=='_') {
            NSUInteger b=i++; while(i<s.length) { c=[s characterAtIndex:i];
                if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember:c] && c!='_' && c!='.' &&
                    ![[NSCharacterSet characterSetWithCharactersInString:@"$%&!#"]characterIsMember:c]) break;
                i++;
            }
            [a addObject:[s substringWithRange:NSMakeRange(b,i-b)]]; continue;
        }
        NSString *op=[s substringWithRange:NSMakeRange(i,1)]; i++;
        if (i<s.length && [@[@"<=",@">=",@"<>"] containsObject:[op stringByAppendingString:[s substringWithRange:NSMakeRange(i,1)]]]) {
            op=[op stringByAppendingString:[s substringWithRange:NSMakeRange(i++,1)]];
        }
        [a addObject:op];
    }
    return a;
}
- (NSString *)peek { return self.pos < self.tokens.count ? MB_GET(self.tokens,self.pos) : nil; }
- (BOOL)take:(NSString *)s { if ([[self.peek uppercaseString] isEqual:s]) { self.pos++; return YES; } return NO; }
- (id)primary {
    NSString *t=self.peek; if (!t) return @0;
    if ([self take:@"("]) { id v=[self expression]; [self take:@")"]; return v; }
    if ([self take:@"-"]) return @(-[[self primary] doubleValue]);
    if ([self take:@"NOT"]) return @(~[[self primary]integerValue]);
    self.pos++;
    if ([t hasPrefix:@"\""]) return [t substringFromIndex:1];
    if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[t characterAtIndex:0]] || [t isEqual:@"."]) return @([t doubleValue]);
    if ([self take:@"("]) {
        NSMutableArray *args=[NSMutableArray array];
        if (![self take:@")"]) { do { [args addObject:[self expression] ?: [NSNull null]]; } while ([self take:@","]); [self take:@")"]; }
        id candidate=MB_GET(self.vars,[t uppercaseString]);
        if([candidate isKindOfClass:[MBArray class]])return [(MBArray *)candidate valueAt:args];
        return [self.owner call:t args:args variables:self.vars error:NULL] ?: @0;
    }
    if([@[@"DATE$",@"TIME$",@"TIMER",@"RND",@"INKEY$"] containsObject:[t uppercaseString]])
        return [self.owner call:t args:@[] variables:self.vars error:NULL]?:@0;
    return MB_GET(self.vars,[t uppercaseString]) ?: [self.owner defaultValueForName:t];
}
- (id)power {
    id v=[self primary];if([self take:@"^"])v=@(pow([v doubleValue],[[self power]doubleValue]));return v;
}
- (id)mul {
    id v=[self power]; while (YES) {
        if ([self take:@"*"]) v=@([v doubleValue]*[[self power] doubleValue]);
        else if ([self take:@"/"]) v=@([v doubleValue]/[[self power] doubleValue]);
        else if ([self take:@"\\"]) v=@((NSInteger)[v doubleValue]/(NSInteger)[[self power]doubleValue]);
        else if ([self take:@"MOD"]) v=@((NSInteger)llround([v doubleValue])%(NSInteger)llround([[self power]doubleValue]));
        else break;
    } return v;
}
- (id)add {
    id v=[self mul]; while (YES) {
        if ([self take:@"+"]) { id r=[self mul];
            v=([v isKindOfClass:[NSString class]]||[r isKindOfClass:[NSString class]]) ?
              [MBString(v) stringByAppendingString:MBString(r)] : @([v doubleValue]+[r doubleValue]); }
        else if ([self take:@"-"]) v=@([v doubleValue]-[[self mul] doubleValue]); else break;
    } return v;
}
- (id)compare {
    id v=[self add]; NSString *op=self.peek;
    if (![@[@"=",@"<>",@"<",@">",@"<=",@">="] containsObject:op]) return v;
    self.pos++; id r=[self add]; NSComparisonResult c;
    if ([v isKindOfClass:[NSNumber class]] && [r isKindOfClass:[NSNumber class]])
        c=[v compare:r]; else c=[MBString(v) compare:MBString(r)];
    if ([op isEqual:@"="]) return @(c==NSOrderedSame?-1:0);
    if ([op isEqual:@"<>"]) return @(c!=NSOrderedSame?-1:0);
    if ([op isEqual:@"<"]) return @(c==NSOrderedAscending?-1:0);
    if ([op isEqual:@">"]) return @(c==NSOrderedDescending?-1:0);
    if ([op isEqual:@"<="]) return @(c!=NSOrderedDescending?-1:0);
    return @(c!=NSOrderedAscending?-1:0);
}
- (id)expression {
    id v=[self compare]; while (YES) {
        if ([self take:@"AND"]) v=@([v integerValue]&[[self compare]integerValue]);
        else if ([self take:@"OR"]) v=@([v integerValue]|[[self compare]integerValue]);
        else if ([self take:@"XOR"]) v=@([v integerValue]^[[self compare]integerValue]);
        else if ([self take:@"EQV"]) v=@(~([v integerValue]^[[self compare]integerValue]));
        else if ([self take:@"IMP"]) {NSInteger a=[v integerValue],b=[[self compare]integerValue];v=@((~a)|b);}
        else break;
    } return v;
}
- (id)parse:(NSString *)text { self.tokens=[self lex:text]; self.pos=0; return [self expression]; }
@end

@implementation MBInterpreter
@synthesize stopped=_stopped, platform=_platform, lines=_lines, procedures=_procedures;
@synthesize dataItems=_dataItems, dataLabels=_dataLabels, dataIndex=_dataIndex, optionBase=_optionBase;
@synthesize files=_files, labelLines=_labelLines, areaPoints=_areaPoints, waveforms=_waveforms, memory=_memory;
@synthesize errorHandlerLine=_errorHandlerLine, currentLine=_currentLine, faultLine=_faultLine;
@synthesize resumeTarget=_resumeTarget, objects=_objects, defaultTypes=_defaultTypes;
- (instancetype)initWithPlatform:(id<MBPlatform>)platform {
    if ((self=[super init])) { self.platform=platform; _procedures=[[NSMutableDictionary alloc]init]; } return self;
}
- (NSString *)typeForName:(NSString *)name {
    NSString *upper=[name uppercaseString];NSString *explicit=MBExplicitType(upper);if(explicit)return explicit;
    if(!upper.length)return nil;unichar first=[upper characterAtIndex:0];
    if(first>='A'&&first<='Z')return MB_GET(self.defaultTypes,([NSString stringWithFormat:@"%C",first]));
    return nil;
}
- (id)coerceValue:(id)value forName:(NSString *)name {return MBCoerceAs([self typeForName:name],value);}
- (id)defaultValueForName:(NSString *)name {return [[[self typeForName:name] description] isEqual:@"$"] ? @"" : @0;}
- (NSError *)err:(NSString *)message line:(NSUInteger)line {
    return [NSError errorWithDomain:@"MacBasic" code:1 userInfo:@{NSLocalizedDescriptionKey:
        [NSString stringWithFormat:@"Line %lu: %@",(unsigned long)line+1,message]}];
}
- (id)evaluate:(NSString *)text variables:(NSMutableDictionary *)vars {
    MBExpr *e=[MBExpr new]; e.owner=self; e.vars=vars; return [e parse:MBTrim(text)];
}
- (NSArray *)parts:(NSString *)s {
    NSMutableArray *out=[NSMutableArray array]; NSUInteger start=0, depth=0; BOOL quote=NO;
    for(NSUInteger i=0;i<s.length;i++){ unichar c=[s characterAtIndex:i]; if(c=='"')quote=!quote;
        if(!quote){if(c=='(')depth++;else if(c==')'&&depth)depth--;else if(c==','&&depth==0){[out addObject:MBTrim([s substringWithRange:NSMakeRange(start,i-start)])];start=i+1;}}}
    NSString *last=MBTrim([s substringFromIndex:start]); if(last.length||out.count)[out addObject:last]; return out;
}
- (NSString *)printText:(NSString *)tail variables:(NSMutableDictionary *)vars newline:(BOOL *)newline {
    *newline=YES;NSMutableString *out=[NSMutableString string];NSUInteger start=0,depth=0;BOOL quote=NO;
    for(NSUInteger i=0;i<=tail.length;i++){
        unichar c=i<tail.length?[tail characterAtIndex:i]:0;
        if(i<tail.length&&c=='"')quote=!quote;
        if(!quote&&i<tail.length){if(c=='(')depth++;else if(c==')'&&depth)depth--;}
        if(i==tail.length||(!quote&&depth==0&&(c==','||c==';'))){
            NSString *piece=MBTrim([tail substringWithRange:NSMakeRange(start,i-start)]);
            if(piece.length)[out appendString:MBString([self evaluate:piece variables:vars])];
            if(i<tail.length&&c==','){NSUInteger spaces=14-(out.length%14);[out appendString:[@"" stringByPaddingToLength:spaces withString:@" " startingAtIndex:0]];}
            if(i<tail.length){*newline=NO;start=i+1;}else if(start<tail.length)*newline=YES;
        }
    }
    if([tail hasSuffix:@";"]||[tail hasSuffix:@","])*newline=NO;return out;
}
- (NSString *)usingPattern:(NSString *)pattern values:(NSArray *)values {
    NSMutableString *out=[NSMutableString string];NSUInteger valueIndex=0;
    NSRegularExpression *numbers=[NSRegularExpression regularExpressionWithPattern:@"[+#*]*#[#*,]*(?:\\.#+)?[+-]*" options:0 error:NULL];
    NSUInteger cursor=0;for(NSTextCheckingResult *m in [numbers matchesInString:pattern options:0 range:NSMakeRange(0,pattern.length)]){
        [out appendString:[pattern substringWithRange:NSMakeRange(cursor,m.range.location-cursor)]];
        NSString *field=[pattern substringWithRange:m.range];id value=valueIndex<values.count?MB_GET(values,valueIndex++):@0;
        NSRange dot=[field rangeOfString:@"."];NSInteger decimals=dot.location==NSNotFound?0:field.length-dot.location-1;
        [out appendFormat:@"%*.*f",(int)field.length,(int)decimals,[value doubleValue]];cursor=NSMaxRange(m.range);
    }
    [out appendString:[pattern substringFromIndex:cursor]];
    while(valueIndex<values.count)[out appendString:MBString(MB_GET(values,valueIndex++))];return out;
}
- (NSUInteger)findEndFrom:(NSUInteger)pc open:(NSString *)open close:(NSArray *)closes elseAt:(NSUInteger *)elseAt {
    NSUInteger depth=0; if(elseAt)*elseAt=NSNotFound;
    for(NSUInteger i=pc+1;i<self.lines.count;i++){NSString *u=[MBTrim(MB_GET(self.lines,i)) uppercaseString];
        if([u hasPrefix:open])depth++;
        if(depth==0&&elseAt&&(*elseAt==NSNotFound)&&([u isEqual:@"ELSE"]||[u hasPrefix:@"ELSEIF "]))*elseAt=i;
        if([closes containsObject:u]){if(depth==0)return i;depth--;}}
    return self.lines.count;
}
- (BOOL)executeFrom:(NSUInteger)start to:(NSUInteger)end variables:(NSMutableDictionary *)vars
             result:(id *)result returned:(BOOL *)returned error:(NSError **)error {
    NSMutableDictionary *loops=[NSMutableDictionary dictionary];
    NSMutableArray<NSNumber *> *gosubStack=[NSMutableArray array];
    NSTimeInterval timerInterval=0,timerNext=0;NSNumber *timerTarget=nil;BOOL timerEnabled=NO;
    NSNumber *mouseTarget=nil,*keyTarget=nil,*menuTarget=nil,*collisionTarget=nil;BOOL previousMouse=NO,menuEnabled=NO,previousCollision=NO;
    for(NSUInteger pc=start;pc<end&&!self.stopped;pc++){
        self.currentLine=pc;
        for(NSMutableDictionary *object in self.objects.allValues)if([MB_GET(object,@"MOVING")boolValue]){
            MB_SET(object,@"VX",@([MB_GET(object,@"VX")doubleValue]+[MB_GET(object,@"AX")doubleValue]));
            MB_SET(object,@"VY",@([MB_GET(object,@"VY")doubleValue]+[MB_GET(object,@"AY")doubleValue]));
            MB_SET(object,@"X",@([MB_GET(object,@"X")doubleValue]+[MB_GET(object,@"VX")doubleValue]));
            MB_SET(object,@"Y",@([MB_GET(object,@"Y")doubleValue]+[MB_GET(object,@"VY")doubleValue]));
        }
        if(timerEnabled&&timerTarget&&[NSDate timeIntervalSinceReferenceDate]>=timerNext){
            timerNext=[NSDate timeIntervalSinceReferenceDate]+timerInterval;[gosubStack addObject:@(pc-1)];pc=timerTarget.unsignedIntegerValue;
        }
        id mouseValue=[self.platform inputValue:@"MOUSE" argument:0];BOOL mouseNow=[mouseValue integerValue]!=0;
        if(mouseTarget&&mouseNow&&!previousMouse){[gosubStack addObject:@(pc-1)];pc=mouseTarget.unsignedIntegerValue;}previousMouse=mouseNow;
        NSString *keyNow=keyTarget?MBString([self.platform inputValue:@"INKEY$" argument:0]):@"";
        if(keyTarget&&keyNow.length){[gosubStack addObject:@(pc-1)];pc=keyTarget.unsignedIntegerValue;}
        if(menuEnabled&&menuTarget&&[self.platform menuValue:0 reset:NO]!=0){[gosubStack addObject:@(pc-1)];pc=menuTarget.unsignedIntegerValue;}
        BOOL collisionNow=NO;NSArray *objectKeys=self.objects.allKeys;
        for(NSUInteger ai=0;ai<objectKeys.count&&!collisionNow;ai++)for(NSUInteger bi=ai+1;bi<objectKeys.count;bi++){
            NSDictionary *a=MB_GET(self.objects,MB_GET(objectKeys,ai)),*b=MB_GET(self.objects,MB_GET(objectKeys,bi));
            NSRect ar=NSMakeRect([MB_GET(a,@"X")doubleValue],[MB_GET(a,@"Y")doubleValue],MAX(1,[MB_GET(a,@"W")doubleValue]),MAX(1,[MB_GET(a,@"H")doubleValue]));
            NSRect br=NSMakeRect([MB_GET(b,@"X")doubleValue],[MB_GET(b,@"Y")doubleValue],MAX(1,[MB_GET(b,@"W")doubleValue]),MAX(1,[MB_GET(b,@"H")doubleValue]));
            if(NSIntersectsRect(ar,br)){collisionNow=YES;break;}}
        if(collisionTarget&&collisionNow&&!previousCollision){[gosubStack addObject:@(pc-1)];pc=collisionTarget.unsignedIntegerValue;}previousCollision=collisionNow;
        NSString *raw=MBTrim(MB_GET(self.lines,pc)); NSString *u=[raw uppercaseString];
        if(!raw.length||[raw hasPrefix:@"'"]||[u hasPrefix:@"REM "])continue;
        if([raw hasSuffix:@":"])continue;
        if([u hasPrefix:@"DATA"]&& (u.length==4||[u characterAtIndex:4]==' '))continue;
        if([u hasPrefix:@"OPTION BASE "]){
            NSInteger base=[[self evaluate:[raw substringFromIndex:12] variables:vars]integerValue];
            if(base!=0&&base!=1){if(error)*error=[self err:@"OPTION BASE must be 0 or 1" line:pc];return NO;}
            self.optionBase=base;continue;
        }
        if([u hasPrefix:@"DIM "]){
            for(NSString *decl in [self parts:[raw substringFromIndex:4]]){
                NSRange par=[decl rangeOfString:@"("];
                if(par.location==NSNotFound||![decl hasSuffix:@")"]){if(error)*error=[self err:@"Malformed DIM" line:pc];return NO;}
                NSString *name=[[MBTrim([decl substringToIndex:par.location])uppercaseString]copy];
                NSArray *bounds=[self parts:[decl substringWithRange:NSMakeRange(par.location+1,decl.length-par.location-2)]];
                NSMutableArray *dims=[NSMutableArray array];
                for(NSString *b in bounds)[dims addObject:@([[self evaluate:b variables:vars]integerValue])];
                MBArray *array=[MBArray new];array.lowerBound=self.optionBase;array.dimensions=dims;array.elementType=[self typeForName:name];MB_SET(vars,name,array);
            }continue;
        }
        if([u hasPrefix:@"ERASE "]){
            for(NSString *name in [self parts:[raw substringFromIndex:6]])[vars removeObjectForKey:[name uppercaseString]];
            continue;
        }
        if([u hasPrefix:@"READ "]){
            for(NSString *item in [self parts:[raw substringFromIndex:5]]){
                if(self.dataIndex>=self.dataItems.count){if(error)*error=[self err:@"Out of DATA" line:pc];return NO;}
                NSString *name=[item uppercaseString];MB_SET(vars,name,[self coerceValue:MB_GET(self.dataItems,self.dataIndex++) forName:name]);
            }
            continue;
        }
        if([u isEqual:@"RESTORE"]||[u hasPrefix:@"RESTORE "]){
            NSString *label=raw.length>7?[[MBTrim([raw substringFromIndex:7])uppercaseString]copy]:nil;
            if(label.length&&!MB_GET(self.dataLabels,label)){if(error)*error=[self err:[NSString stringWithFormat:@"Unknown DATA label '%@'",label] line:pc];return NO;}
            self.dataIndex=label.length?[MB_GET(self.dataLabels,label)unsignedIntegerValue]:0;continue;
        }
        if([u hasPrefix:@"SUB "]||[u hasPrefix:@"FUNCTION "]){ pc=[self findEndFrom:pc open:@"~" close:@[@"END SUB",@"END FUNCTION"] elseAt:NULL]; continue; }
        if([u isEqual:@"END"]||[u isEqual:@"STOP"])return YES;
        if([u hasPrefix:@"ON ERROR GOTO "]){
            NSString *target=[[MBTrim([raw substringFromIndex:14])uppercaseString]copy];
            self.errorHandlerLine=[target isEqual:@"0"]?nil:MB_GET(self.labelLines,target);
            if(![target isEqual:@"0"]&&!self.errorHandlerLine){if(error)*error=[self err:@"Unknown error-handler label" line:pc];return NO;}continue;
        }
        if([u hasPrefix:@"ERROR "]){
            NSInteger code=[[self evaluate:[raw substringFromIndex:6]variables:vars]integerValue];
            if(error)*error=[NSError errorWithDomain:@"MacBasic" code:code userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Line %lu: BASIC error %ld",(unsigned long)pc+1,(long)code]}];return NO;
        }
        if([u isEqual:@"RESUME"]||[u hasPrefix:@"RESUME "]){
            NSString *target=raw.length>6?[[MBTrim([raw substringFromIndex:6])uppercaseString]copy]:@"";
            if([target isEqual:@"NEXT"])self.resumeTarget=@(self.faultLine+1);
            else if(target.length)self.resumeTarget=MB_GET(self.labelLines,target);
            else self.resumeTarget=@(self.faultLine);
            return YES;
        }
        if([u hasPrefix:@"OPEN "]){
            NSRegularExpression *random=[NSRegularExpression regularExpressionWithPattern:@"(?i)^OPEN\\s+(.+?)\\s+AS\\s+#?([0-9]+)\\s+LEN\\s*=\\s*([0-9]+)$" options:0 error:NULL];
            NSTextCheckingResult *randomMatch=[random firstMatchInString:raw options:0 range:NSMakeRange(0,raw.length)];
            if(randomMatch){NSString *path=MBString([self evaluate:[raw substringWithRange:[randomMatch rangeAtIndex:1]]variables:vars]);
                NSNumber *number=@([[raw substringWithRange:[randomMatch rangeAtIndex:2]]integerValue]);MBFile *file=[MBFile new];file.path=path;file.mode=@"RANDOM";
                file.recordLength=[[raw substringWithRange:[randomMatch rangeAtIndex:3]]integerValue];file.fields=[NSMutableArray array];
                NSData *existing=[NSData dataWithContentsOfFile:path];file.randomData=existing?[existing mutableCopy]:[NSMutableData data];MB_SET(self.files,number,file);continue;}
            NSRegularExpression *r=[NSRegularExpression regularExpressionWithPattern:@"(?i)^OPEN\\s+(.+?)\\s+FOR\\s+(INPUT|OUTPUT|APPEND)\\s+AS\\s+#?([0-9]+)$" options:0 error:NULL];
            NSTextCheckingResult *m=[r firstMatchInString:raw options:0 range:NSMakeRange(0,raw.length)];
            if(!m){if(error)*error=[self err:@"Malformed OPEN" line:pc];return NO;}
            NSString *path=MBString([self evaluate:[raw substringWithRange:[m rangeAtIndex:1]] variables:vars]);
            NSString *mode=[[raw substringWithRange:[m rangeAtIndex:2]]uppercaseString];NSNumber *number=@([[raw substringWithRange:[m rangeAtIndex:3]]integerValue]);
            MBFile *file=[MBFile new];file.path=path;file.mode=mode;file.index=0;file.output=[NSMutableString string];
            if([mode isEqual:@"INPUT"]||[mode isEqual:@"APPEND"]){NSError *readError=nil;NSString *content=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
                if(!content&&[mode isEqual:@"INPUT"]){if(error)*error=[self err:readError.localizedDescription line:pc];return NO;}
                file.lines=[[(content?:@"")componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]mutableCopy];
                if([mode isEqual:@"APPEND"]&&content.length)[file.output appendString:content];
            }MB_SET(self.files,number,file);continue;
        }
        if([u isEqual:@"CLOSE"]||[u hasPrefix:@"CLOSE "]){
            NSArray *targets=[u isEqual:@"CLOSE"]?[self.files.allKeys copy]:[self parts:[raw substringFromIndex:6]];
            for(id target in targets){NSNumber *number=[target isKindOfClass:[NSNumber class]]?target:@([[[target description]stringByReplacingOccurrencesOfString:@"#" withString:@""]integerValue]);
                MBFile *file=MB_GET(self.files,number);if(file&&![file.mode isEqual:@"INPUT"]){NSError *writeError=nil;BOOL wrote;
                    if([file.mode isEqual:@"RANDOM"])wrote=[file.randomData writeToFile:file.path options:NSDataWritingAtomic error:&writeError];
                    else wrote=[file.output writeToFile:file.path atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
                    if(!wrote&&error){*error=[self err:writeError.localizedDescription line:pc];return NO;}}
                [self.files removeObjectForKey:number];}continue;
        }
        if([u hasPrefix:@"FIELD #"]){
            NSRange comma=[raw rangeOfString:@","];NSNumber *number=@([[[raw substringWithRange:NSMakeRange(6,comma.location-6)]stringByReplacingOccurrencesOfString:@"#" withString:@""]integerValue]);
            MBFile *file=MB_GET(self.files,number);if(!file||![file.mode isEqual:@"RANDOM"]){if(error)*error=[self err:@"FIELD requires a random file" line:pc];return NO;}
            [file.fields removeAllObjects];for(NSString *field in [self parts:[raw substringFromIndex:comma.location+1]]){
                NSRegularExpression *fr=[NSRegularExpression regularExpressionWithPattern:@"(?i)^\\s*([0-9]+)\\s+AS\\s+([A-Z][A-Z0-9_$]*)\\s*$" options:0 error:NULL];
                NSTextCheckingResult *fm=[fr firstMatchInString:field options:0 range:NSMakeRange(0,field.length)];
                if(fm)[file.fields addObject:@{@"length":@([[field substringWithRange:[fm rangeAtIndex:1]]integerValue]),@"name":[[field substringWithRange:[fm rangeAtIndex:2]]uppercaseString]}];
            }continue;
        }
        if([u hasPrefix:@"GET #"]||[u hasPrefix:@"PUT #"]){
            BOOL put=[u hasPrefix:@"PUT #"];NSArray *p=[self parts:[raw substringFromIndex:5]];NSNumber *number=@([[[p firstObject]stringByReplacingOccurrencesOfString:@"#" withString:@""]integerValue]);
            MBFile *file=MB_GET(self.files,number);NSUInteger record=p.count>1?MAX(1,[[self evaluate:MB_GET(p,1)variables:vars]integerValue]):file.index+1;NSUInteger offset=(record-1)*file.recordLength;
            if(put){if(file.randomData.length<offset+file.recordLength)[file.randomData setLength:offset+file.recordLength];NSUInteger position=offset;
                for(NSDictionary *field in file.fields){NSUInteger length=[MB_GET(field,@"length")unsignedIntegerValue];NSData *bytes=[MBString(MB_GET(vars,MB_GET(field,@"name")))dataUsingEncoding:NSISOLatin1StringEncoding];
                    NSMutableData *padded=[NSMutableData dataWithLength:length];memcpy(padded.mutableBytes,bytes.bytes,MIN(length,bytes.length));memcpy((uint8_t *)file.randomData.mutableBytes+position,padded.bytes,length);position+=length;}}
            else {NSUInteger position=offset;for(NSDictionary *field in file.fields){NSUInteger length=[MB_GET(field,@"length")unsignedIntegerValue];
                    if(position+length<=file.randomData.length){NSString *name=MB_GET(field,@"name");MB_SET(vars,name,[self coerceValue:MBByteString((uint8_t *)file.randomData.bytes+position,length) forName:name]);}position+=length;}}
            file.index=record;continue;
        }
        if([u hasPrefix:@"PRINT #"]||[u hasPrefix:@"WRITE #"]){
            BOOL write=[u hasPrefix:@"WRITE #"];NSRange comma=[raw rangeOfString:@","];if(comma.location==NSNotFound){if(error)*error=[self err:@"File output needs a channel and values" line:pc];return NO;}
            NSNumber *number=@([[[raw substringWithRange:NSMakeRange(write?7:7,comma.location-7)]stringByReplacingOccurrencesOfString:@"#" withString:@""]integerValue]);
            MBFile *file=MB_GET(self.files,number);if(!file||[file.mode isEqual:@"INPUT"]){if(error)*error=[self err:@"File is not open for output" line:pc];return NO;}
            NSMutableArray *values=[NSMutableArray array];for(NSString *p in [self parts:[raw substringFromIndex:comma.location+1]]){id v=[self evaluate:p variables:vars];
                [values addObject:write&&[v isKindOfClass:[NSString class]]?[NSString stringWithFormat:@"\"%@\"",v]:MBString(v)];}
            [file.output appendFormat:@"%@\n",[values componentsJoinedByString:write?@",":@" "]];continue;
        }
        if([u hasPrefix:@"INPUT #"]||[u hasPrefix:@"LINE INPUT #"]){
            BOOL lineInput=[u hasPrefix:@"LINE INPUT #"];NSUInteger offset=lineInput?11:6;NSRange comma=[raw rangeOfString:@"," options:0 range:NSMakeRange(offset,raw.length-offset)];
            if(comma.location==NSNotFound){if(error)*error=[self err:@"File input needs a channel and variables" line:pc];return NO;}
            NSNumber *number=@([[[raw substringWithRange:NSMakeRange(offset,comma.location-offset)]stringByReplacingOccurrencesOfString:@"#" withString:@""]integerValue]);
            MBFile *file=MB_GET(self.files,number);if(!file||file.index>=file.lines.count){if(error)*error=[self err:@"End of file" line:pc];return NO;}
            NSString *line=MB_GET(file.lines,file.index++);NSArray *values=lineInput?@[line]:[self parts:line];NSArray *names=[self parts:[raw substringFromIndex:comma.location+1]];
            for(NSUInteger i=0;i<names.count;i++){NSString *name=[MB_GET(names,i)uppercaseString],*v=i<values.count?MBTrim(MB_GET(values,i)):@"";
                if([v hasPrefix:@"\""]&&[v hasSuffix:@"\""]&&v.length>=2)v=[v substringWithRange:NSMakeRange(1,v.length-2)];
                id input=[[self typeForName:name]isEqual:@"$"]?v:@([v doubleValue]);MB_SET(vars,name,[self coerceValue:input forName:name]);}continue;
        }
        if([u hasPrefix:@"INPUT "]||[u hasPrefix:@"LINE INPUT "]){
            BOOL lineInput=[u hasPrefix:@"LINE INPUT "];NSString *tail=[raw substringFromIndex:lineInput?11:6];NSString *prompt=@"? ";
            if([tail hasPrefix:@"\""]){NSUInteger quote=1;while(quote<tail.length&&[tail characterAtIndex:quote]!='"')quote++;
                if(quote<tail.length){prompt=[tail substringWithRange:NSMakeRange(1,quote-1)];tail=MBTrim([tail substringFromIndex:quote+1]);
                    if([tail hasPrefix:@";"]||[tail hasPrefix:@","])tail=MBTrim([tail substringFromIndex:1]);}}
            NSString *answer=MBTrim([self.platform readInput:prompt]);NSArray *values=lineInput?@[answer]:[self parts:answer];
            NSArray *names=[self parts:tail];for(NSUInteger i=0;i<names.count;i++){NSString *name=[MB_GET(names,i)uppercaseString];NSString *value=i<values.count?MB_GET(values,i):@"";
                id input=[[self typeForName:name]isEqual:@"$"]?value:@([value doubleValue]);MB_SET(vars,name,[self coerceValue:input forName:name]);}continue;
        }
        if([u hasPrefix:@"PRINT"]){
            NSString *tail=raw.length>5?MBTrim([raw substringFromIndex:5]):@"";BOOL newline=YES;
            NSString *text=nil;
            if([[tail uppercaseString]hasPrefix:@"USING "]){
                NSString *body=MBTrim([tail substringFromIndex:6]);NSRange semi=[body rangeOfString:@";"];
                if(semi.location==NSNotFound){if(error)*error=[self err:@"PRINT USING needs a format and values" line:pc];return NO;}
                NSString *pattern=MBString([self evaluate:[body substringToIndex:semi.location]variables:vars]);NSMutableArray *values=[NSMutableArray array];
                for(NSString *p in [self parts:[body substringFromIndex:semi.location+1]])[values addObject:[self evaluate:p variables:vars]];
                text=[self usingPattern:pattern values:values];newline=YES;
            }else text=[self printText:tail variables:vars newline:&newline];
            [self.platform writeText:newline?[text stringByAppendingString:@"\n"]:text];continue;
        }
        if([u hasPrefix:@"IF "]&&[u hasSuffix:@" THEN"]){
            NSString *cond=[raw substringWithRange:NSMakeRange(3,raw.length-8)]; NSUInteger alt;
            NSUInteger finish=[self findEndFrom:pc open:@"IF " close:@[@"END IF",@"ENDIF"] elseAt:&alt];
            if(!MBTruth([self evaluate:cond variables:vars])){
                if(alt!=NSNotFound&&[[MBTrim(MB_GET(self.lines,alt))uppercaseString]hasPrefix:@"ELSEIF "]){MB_SET(loops,([NSString stringWithFormat:@"I%lu",(unsigned long)alt]),@1);pc=alt-1;}
                else pc=(alt!=NSNotFound?alt:finish);
            }continue;
        }
        if([u hasPrefix:@"IF "]&&[u containsString:@" THEN "]){
            NSRange then=[u rangeOfString:@" THEN "];NSString *condition=[raw substringWithRange:NSMakeRange(3,then.location-3)];
            NSString *actions=[raw substringFromIndex:NSMaxRange(then)];NSRange otherwise=[[actions uppercaseString]rangeOfString:@" ELSE "];
            NSString *chosen=nil;if(MBTruth([self evaluate:condition variables:vars]))chosen=otherwise.location==NSNotFound?actions:[actions substringToIndex:otherwise.location];
            else if(otherwise.location!=NSNotFound)chosen=[actions substringFromIndex:NSMaxRange(otherwise)];
            if(chosen.length){NSString *target=[MBTrim(chosen)uppercaseString];
                if([target hasPrefix:@"GOTO "])target=MBTrim([target substringFromIndex:5]);
                NSNumber *line=MB_GET(self.labelLines,target);if(line){pc=line.unsignedIntegerValue-1;continue;}
                NSArray *saved=self.lines;NSMutableArray *temporary=[self.lines mutableCopy];MB_SET(temporary,pc,chosen);self.lines=temporary;
                BOOL ok=[self executeFrom:pc to:pc+1 variables:vars result:result returned:returned error:error];self.lines=saved;if(!ok)return NO;
            }continue;
        }
        if([u hasPrefix:@"ELSEIF "]&&[u hasSuffix:@" THEN"]){
            NSString *marker=[NSString stringWithFormat:@"I%lu",(unsigned long)pc];
            if(!MB_GET(loops,marker)){pc=[self findEndFrom:pc open:@"~" close:@[@"END IF",@"ENDIF"] elseAt:NULL];continue;}
            [loops removeObjectForKey:marker];NSString *cond=[raw substringWithRange:NSMakeRange(7,raw.length-12)];
            if(!MBTruth([self evaluate:cond variables:vars])){NSUInteger next;
                NSUInteger finish=[self findEndFrom:pc open:@"~" close:@[@"END IF",@"ENDIF"] elseAt:&next];
                if(next!=NSNotFound&&[[MBTrim(MB_GET(self.lines,next))uppercaseString]hasPrefix:@"ELSEIF "]){MB_SET(loops,([NSString stringWithFormat:@"I%lu",(unsigned long)next]),@1);pc=next-1;}
                else pc=next!=NSNotFound?next:finish;}continue;
        }
        if([u isEqual:@"ELSE"]){ pc=[self findEndFrom:pc open:@"~" close:@[@"END IF",@"ENDIF"] elseAt:NULL]; continue; }
        if([u isEqual:@"END IF"]||[u isEqual:@"ENDIF"])continue;
        if([u hasPrefix:@"WHILE "]){
            if(!MBTruth([self evaluate:[raw substringFromIndex:6] variables:vars]))
                pc=[self findEndFrom:pc open:@"WHILE " close:@[@"WEND"] elseAt:NULL];
            else MB_SET(loops,([NSString stringWithFormat:@"W%lu",(unsigned long)[self findEndFrom:pc open:@"WHILE " close:@[@"WEND"] elseAt:NULL]]),@(pc));
            continue;
        }
        if([u isEqual:@"WEND"]){ NSNumber *back=MB_GET(loops,([NSString stringWithFormat:@"W%lu",(unsigned long)pc])); if(back)pc=back.unsignedIntegerValue-1; continue; }
        if([u hasPrefix:@"FOR "]){
            NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"(?i)^FOR\\s+([A-Z_$][A-Z0-9_$]*)\\s*=\\s*(.*?)\\s+TO\\s+(.*?)(?:\\s+STEP\\s+(.*))?$" options:0 error:NULL];
            NSTextCheckingResult *m=[re firstMatchInString:raw options:0 range:NSMakeRange(0,raw.length)];
            if(!m){if(error)*error=[self err:@"Malformed FOR" line:pc];return NO;}
            NSString *name=[[raw substringWithRange:[m rangeAtIndex:1]] uppercaseString];
            if(!MB_GET(loops,@(pc))) MB_SET(vars,name,[self coerceValue:[self evaluate:[raw substringWithRange:[m rangeAtIndex:2]] variables:vars] forName:name]);
            double limit=[[self evaluate:[raw substringWithRange:[m rangeAtIndex:3]] variables:vars] doubleValue];
            double step=[m rangeAtIndex:4].location==NSNotFound?1:[[self evaluate:[raw substringWithRange:[m rangeAtIndex:4]] variables:vars] doubleValue];
            MB_SET(loops,@(pc),(@{@"name":name,@"limit":@(limit),@"step":@(step)})); continue;
        }
        if([u hasPrefix:@"NEXT"]){
            NSUInteger f=pc; while(f>start&&!MB_GET(loops,@(f)))f--; NSDictionary *loop=MB_GET(loops,@(f));
            if(loop){NSString *n=MB_GET(loop,@"name");double val=[MB_GET(vars,n)doubleValue]+[MB_GET(loop,@"step")doubleValue];MB_SET(vars,n,[self coerceValue:@(val) forName:n]);val=[MB_GET(vars,n)doubleValue];
                double step=[MB_GET(loop,@"step")doubleValue],lim=[MB_GET(loop,@"limit")doubleValue];if((step>=0&&val<=lim)||(step<0&&val>=lim))pc=f-1;else[loops removeObjectForKey:@(f)];} continue;
        }
        if([u isEqual:@"EXIT FOR"]){NSUInteger depth=0;for(NSUInteger i=pc+1;i<end;i++){NSString *q=[MBTrim(MB_GET(self.lines,i))uppercaseString];if([q hasPrefix:@"FOR "])depth++;if([q hasPrefix:@"NEXT"]){if(depth==0){pc=i;break;}depth--;}}continue;}
        if([u isEqual:@"EXIT WHILE"]){pc=[self findEndFrom:pc open:@"WHILE " close:@[@"WEND"] elseAt:NULL];continue;}
        if([u hasPrefix:@"ON TIMER("]&&[u containsString:@") GOSUB "]){
            NSRange close=[u rangeOfString:@") GOSUB "];timerInterval=[[self evaluate:[raw substringWithRange:NSMakeRange(9,close.location-9)]variables:vars]doubleValue];
            timerTarget=MB_GET(self.labelLines,[[raw substringFromIndex:NSMaxRange(close)]uppercaseString]);timerNext=[NSDate timeIntervalSinceReferenceDate]+timerInterval;continue;
        }
        if([u isEqual:@"TIMER ON"]){timerEnabled=YES;timerNext=[NSDate timeIntervalSinceReferenceDate]+timerInterval;continue;}
        if([u isEqual:@"TIMER OFF"]||[u isEqual:@"TIMER STOP"]){timerEnabled=NO;continue;}
        if([u hasPrefix:@"ON MOUSE GOSUB "]){mouseTarget=MB_GET(self.labelLines,[[raw substringFromIndex:15]uppercaseString]);continue;}
        if([u hasPrefix:@"ON KEY GOSUB "]){keyTarget=MB_GET(self.labelLines,[[raw substringFromIndex:13]uppercaseString]);continue;}
        if([u hasPrefix:@"ON MENU GOSUB "]){menuTarget=MB_GET(self.labelLines,[[raw substringFromIndex:14]uppercaseString]);continue;}
        if([u hasPrefix:@"ON COLLISION GOSUB "]){collisionTarget=MB_GET(self.labelLines,[[raw substringFromIndex:19]uppercaseString]);continue;}
        if([u isEqual:@"MOUSE OFF"]){mouseTarget=nil;continue;}
        if([u isEqual:@"KEY OFF"]){keyTarget=nil;continue;}
        if([u isEqual:@"MENU ON"]){menuEnabled=YES;continue;}
        if([u isEqual:@"MENU OFF"]||[u isEqual:@"MENU STOP"]){menuEnabled=NO;continue;}
        if([u isEqual:@"MENU RESET"]){menuEnabled=NO;continue;}
        if([u isEqual:@"MOUSE ON"]||[u isEqual:@"KEY ON"]||[u isEqual:@"COLLISION ON"]||[u isEqual:@"COLLISION OFF"]||[u isEqual:@"COLLISION STOP"]||[u isEqual:@"BREAK ON"]||[u isEqual:@"BREAK OFF"]||[u isEqual:@"BREAK STOP"])continue;
        if([u hasPrefix:@"MENU "]&&![u isEqual:@"MENU RESET"]){
            NSArray *p=[self parts:[raw substringFromIndex:5]];
            if(p.count>=3){
                [self.platform setMenu:[[self evaluate:MB_GET(p,0)variables:vars]integerValue]
                    item:[[self evaluate:MB_GET(p,1)variables:vars]integerValue] state:[[self evaluate:MB_GET(p,2)variables:vars]integerValue]
                    title:p.count>3?MBString([self evaluate:MB_GET(p,3)variables:vars]):@""];
            }
            continue;
        }
        if([u hasPrefix:@"ON "]&&([u containsString:@" GOTO "]||[u containsString:@" GOSUB "])){
            NSRange branch=[u rangeOfString:[u containsString:@" GOSUB "]?@" GOSUB ":@" GOTO "];NSInteger choice=[[self evaluate:[raw substringWithRange:NSMakeRange(3,branch.location-3)]variables:vars]integerValue];
            NSArray *targets=[self parts:[raw substringFromIndex:NSMaxRange(branch)]];
            if(choice>=1&&choice<=(NSInteger)targets.count){NSNumber *line=MB_GET(self.labelLines,[MBTrim(MB_GET(targets,choice-1))uppercaseString]);
                if(line){if([u containsString:@" GOSUB "])[gosubStack addObject:@(pc)];pc=line.unsignedIntegerValue-1;}}continue;
        }
        if([u hasPrefix:@"GOTO "]||[u hasPrefix:@"GOSUB "]){
            BOOL sub=[u hasPrefix:@"GOSUB "];NSString *target=[[MBTrim([raw substringFromIndex:sub?6:5])uppercaseString]copy];
            NSNumber *line=MB_GET(self.labelLines,target);if(!line){if(error)*error=[self err:[NSString stringWithFormat:@"Unknown label '%@'",target] line:pc];return NO;}
            if(sub)[gosubStack addObject:@(pc)];pc=line.unsignedIntegerValue-1;continue;
        }
        if([u hasPrefix:@"RETURN"]){
            if(!returned&&gosubStack.count){pc=gosubStack.lastObject.unsignedIntegerValue;[gosubStack removeLastObject];continue;}
            if(result)*result=raw.length>6?[self evaluate:[raw substringFromIndex:6] variables:vars]:@0;if(returned)*returned=YES;return YES;
        }
        if([u hasPrefix:@"WINDOW OPEN "]){
            NSArray *p=[self parts:[raw substringFromIndex:12]];if(p.count<4){if(error)*error=[self err:@"WINDOW OPEN needs id, title, width, height" line:pc];return NO;}
            if(p.count==5){if(error)*error=[self err:@"WINDOW OPEN coordinates require both x and y" line:pc];return NO;}
            if(p.count!=4&&p.count!=6){if(error)*error=[self err:@"WINDOW OPEN accepts id, title, width, height[, x, y]" line:pc];return NO;}
            NSInteger windowID=[[self evaluate:MB_GET(p,0) variables:vars]integerValue];
            if(windowID<=0){if(error)*error=[self err:@"WINDOW ID must be a positive integer" line:pc];return NO;}
            CGFloat x=p.count==6?[[self evaluate:MB_GET(p,4) variables:vars]doubleValue]:NAN;
            CGFloat y=p.count==6?[[self evaluate:MB_GET(p,5) variables:vars]doubleValue]:NAN;
            [self.platform openWindowWithID:windowID title:MBString([self evaluate:MB_GET(p,1) variables:vars])
                                     width:[[self evaluate:MB_GET(p,2) variables:vars]doubleValue]
                                    height:[[self evaluate:MB_GET(p,3) variables:vars]doubleValue] x:x y:y];continue;
        }
        if([u hasPrefix:@"WINDOW CLOSE "]){
            NSInteger windowID=[[self evaluate:[raw substringFromIndex:13] variables:vars]integerValue];
            if(windowID<=0){if(error)*error=[self err:@"WINDOW ID must be a positive integer" line:pc];return NO;}
            [self.platform closeWindowWithID:windowID];continue;
        }
        if([u hasPrefix:@"VIEW ADD "]){
            NSArray *p=[self parts:[raw substringFromIndex:9]];
            if(p.count!=6){if(error)*error=[self err:@"VIEW ADD needs view id, window id, x, y, width, height" line:pc];return NO;}
            NSInteger viewID=[[self evaluate:MB_GET(p,0)variables:vars]integerValue],windowID=[[self evaluate:MB_GET(p,1)variables:vars]integerValue];
            if(viewID<=0||windowID<=0){if(error)*error=[self err:@"VIEW and WINDOW IDs must be positive integers" line:pc];return NO;}
            [self.platform addViewWithID:viewID toWindowID:windowID
                                      x:[[self evaluate:MB_GET(p,2) variables:vars]doubleValue]
                                      y:[[self evaluate:MB_GET(p,3) variables:vars]doubleValue]
                                  width:[[self evaluate:MB_GET(p,4) variables:vars]doubleValue]
                                 height:[[self evaluate:MB_GET(p,5) variables:vars]doubleValue]];continue;
        }
        if([u hasPrefix:@"COLOR "]){
            MB_SET(vars,@"__COLOR",MBString([self evaluate:[raw substringFromIndex:6] variables:vars]));continue;
        }
        if([u hasPrefix:@"PSET "]||[u hasPrefix:@"PRESET "]){
            BOOL preset=[u hasPrefix:@"PRESET "];NSString *tail=[raw substringFromIndex:preset?7:5];
            tail=[[tail stringByReplacingOccurrencesOfString:@"(" withString:@""]stringByReplacingOccurrencesOfString:@")" withString:@""];
            NSArray *p=[self parts:tail];if(p.count<2){if(error)*error=[self err:@"PSET needs x and y" line:pc];return NO;}
            NSString *color=p.count>2?MBString([self evaluate:MB_GET(p,2) variables:vars]):(preset?@"white":(MB_GET(vars,@"__COLOR")?:@"black"));
            [self.platform drawCommand:@"RECT" onViewID:-1 arguments:@[[self evaluate:MB_GET(p,0) variables:vars],[self evaluate:MB_GET(p,1) variables:vars],@1,@1,color,@1]];continue;
        }
        if([u hasPrefix:@"CIRCLE "]){
            NSString *tail=[[[raw substringFromIndex:7]stringByReplacingOccurrencesOfString:@"(" withString:@""]stringByReplacingOccurrencesOfString:@")" withString:@""];
            NSArray *p=[self parts:tail];if(p.count<3){if(error)*error=[self err:@"CIRCLE needs x, y, radius" line:pc];return NO;}
            double x=[[self evaluate:MB_GET(p,0) variables:vars]doubleValue],y=[[self evaluate:MB_GET(p,1) variables:vars]doubleValue],r=[[self evaluate:MB_GET(p,2) variables:vars]doubleValue];
            NSString *color=p.count>3?MBString([self evaluate:MB_GET(p,3) variables:vars]):(MB_GET(vars,@"__COLOR")?:@"black");
            [self.platform drawCommand:@"OVAL" onViewID:-1 arguments:@[@(x-r),@(y-r),@(r*2),@(r*2),color,@0]];continue;
        }
        if([u hasPrefix:@"LINE "]&&[raw containsString:@"-"]){
            NSRegularExpression *r=[NSRegularExpression regularExpressionWithPattern:@"(?i)^LINE\\s*\\((.*?),(.*?)\\)\\s*-\\s*\\((.*?),(.*?)\\)(?:\\s*,\\s*([^,]+))?(?:\\s*,\\s*(B|BF))?$" options:0 error:NULL];
            NSTextCheckingResult *m=[r firstMatchInString:raw options:0 range:NSMakeRange(0,raw.length)];
            if(!m){if(error)*error=[self err:@"Malformed LINE" line:pc];return NO;}NSMutableArray *a=[NSMutableArray array];
            for(NSUInteger i=1;i<=4;i++)[a addObject:[self evaluate:[raw substringWithRange:[m rangeAtIndex:i]] variables:vars]];
            NSString *color=[m rangeAtIndex:5].location==NSNotFound?(MB_GET(vars,@"__COLOR")?:@"black"):MBString([self evaluate:[raw substringWithRange:[m rangeAtIndex:5]] variables:vars]);
            NSString *mode=[m rangeAtIndex:6].location==NSNotFound?@"":[[raw substringWithRange:[m rangeAtIndex:6]]uppercaseString];
            if(mode.length){double x1=[MB_GET(a,0)doubleValue],y1=[MB_GET(a,1)doubleValue],x2=[MB_GET(a,2)doubleValue],y2=[MB_GET(a,3)doubleValue];
                [self.platform drawCommand:@"RECT" onViewID:-1 arguments:@[@(MIN(x1,x2)),@(MIN(y1,y2)),@(fabs(x2-x1)),@(fabs(y2-y1)),color,@([mode isEqual:@"BF"])]];}
            else {[a addObject:color];[self.platform drawCommand:@"LINE" onViewID:-1 arguments:a];}continue;
        }
        if([u hasPrefix:@"AREA "]){
            NSString *tail=[[[raw substringFromIndex:5]stringByReplacingOccurrencesOfString:@"(" withString:@""]stringByReplacingOccurrencesOfString:@")" withString:@""];
            NSArray *p=[self parts:tail];if(p.count>=2){[self.areaPoints addObject:[self evaluate:MB_GET(p,0) variables:vars]];[self.areaPoints addObject:[self evaluate:MB_GET(p,1) variables:vars]];}continue;
        }
        if([u hasPrefix:@"AREAFILL"]){
            NSString *color=raw.length>8?MBString([self evaluate:[raw substringFromIndex:8] variables:vars]):(MB_GET(vars,@"__COLOR")?:@"black");
            NSMutableArray *a=[self.areaPoints mutableCopy];[a addObject:color];[self.platform drawCommand:@"POLYGON" onViewID:-1 arguments:a];[self.areaPoints removeAllObjects];continue;
        }
        if([u hasPrefix:@"PAINT "]){
            NSString *tail=[[[raw substringFromIndex:6]stringByReplacingOccurrencesOfString:@"(" withString:@""]stringByReplacingOccurrencesOfString:@")" withString:@""];
            NSArray *p=[self parts:tail];if(p.count>=2){NSString *color=p.count>2?MBString([self evaluate:MB_GET(p,2)variables:vars]):(MB_GET(vars,@"__COLOR")?:@"black");
                [self.platform drawCommand:@"PAINT" onViewID:-1 arguments:@[[self evaluate:MB_GET(p,0)variables:vars],[self evaluate:MB_GET(p,1)variables:vars],color]];}continue;
        }
        if([u hasPrefix:@"PALETTE "]||[u hasPrefix:@"PATTERN "]||[u hasPrefix:@"WIDTH "]||[u hasPrefix:@"SCROLL "])continue;
        if([u hasPrefix:@"SCREEN "]){
            NSArray *p=[self parts:[raw substringFromIndex:7]];if(p.count>=3){NSInteger screenID=[[self evaluate:MB_GET(p,0)variables:vars]integerValue];NSString *title=[NSString stringWithFormat:@"Screen %ld",(long)screenID];
                if(screenID<=0){if(error)*error=[self err:@"SCREEN ID must be a positive integer" line:pc];return NO;}
                CGFloat width=[[self evaluate:MB_GET(p,1)variables:vars]doubleValue],height=[[self evaluate:MB_GET(p,2)variables:vars]doubleValue];
                [self.platform openWindowWithID:screenID title:title width:width height:height x:NAN y:NAN];
                [self.platform addViewWithID:screenID toWindowID:screenID x:0 y:0 width:width height:height];}continue;
        }
        if([u hasPrefix:@"DRAW "]||[u hasPrefix:@"CLEAR "]){
            BOOL clear=[u hasPrefix:@"CLEAR "];NSString *tail=[raw substringFromIndex:clear?6:5];
            NSRange space=[tail rangeOfString:@" "];NSString *command=clear?@"CLEAR":[[space.location==NSNotFound?tail:[tail substringToIndex:space.location] uppercaseString] copy];
            NSString *argText=clear?tail:(space.location==NSNotFound?@"":[tail substringFromIndex:space.location+1]);
            NSArray *p=[self parts:argText];if(!p.count){if(error)*error=[self err:@"Drawing command needs a view ID" line:pc];return NO;}
            NSInteger viewID=[[self evaluate:MB_GET(p,0) variables:vars]integerValue];if(viewID<=0){if(error)*error=[self err:@"View ID must be a positive integer" line:pc];return NO;}
            NSMutableArray *args=[NSMutableArray array];
            for(NSUInteger i=1;i<p.count;i++)[args addObject:[self evaluate:MB_GET(p,i) variables:vars]?:@0];
            [self.platform drawCommand:command onViewID:viewID arguments:args];continue;
        }
        if([u isEqual:@"BEEP"]){[self.platform beep];continue;}
        if([u hasPrefix:@"RANDOMIZE"]){srandom((unsigned)(raw.length>9?[[self evaluate:[raw substringFromIndex:9] variables:vars]integerValue]:time(NULL)));continue;}
        if([u isEqual:@"SOUND STOP"]){[self.platform stopSounds];continue;}
        if([u hasPrefix:@"SOUND PLAY "]){
            [self.platform playSound:MBString([self evaluate:[raw substringFromIndex:11] variables:vars])];continue;
        }
        if([u hasPrefix:@"WAVE "]){
            NSArray *p=[self parts:[raw substringFromIndex:5]];if(p.count>=2)MB_SET(self.waveforms,@([[self evaluate:MB_GET(p,0)variables:vars]integerValue]),@([[self evaluate:MB_GET(p,1)variables:vars]integerValue]));continue;
        }
        if([u hasPrefix:@"SOUND "]){
            NSArray *p=[self parts:[raw substringFromIndex:6]];if(p.count<2){if(error)*error=[self err:@"SOUND needs frequency and duration" line:pc];return NO;}
            NSInteger voice=p.count>3?[[self evaluate:MB_GET(p,3)variables:vars]integerValue]:0;double volume=p.count>2?[[self evaluate:MB_GET(p,2)variables:vars]doubleValue]:1;
            if(volume>1)volume/=255.0;[self.platform playTone:[[self evaluate:MB_GET(p,0)variables:vars]doubleValue] duration:[[self evaluate:MB_GET(p,1)variables:vars]doubleValue]
                volume:volume voice:voice waveform:[MB_GET(self.waveforms,@(voice))integerValue]];continue;
        }
        if([u hasPrefix:@"SAY "]){[self.platform speakText:MBString([self evaluate:[raw substringFromIndex:4] variables:vars])];continue;}
        if([u hasPrefix:@"PROCESS RUN "]){
            NSArray *p=[self parts:[raw substringFromIndex:12]]; if(!p.count)continue; NSMutableArray *args=[NSMutableArray array];
            for(NSUInteger i=1;i<p.count;i++)[args addObject:MBString([self evaluate:MB_GET(p,i) variables:vars])];
            [self.platform runProcess:MBString([self evaluate:MB_GET(p,0) variables:vars]) arguments:args];continue;
        }
        if([u hasPrefix:@"SLEEP "]){ [NSThread sleepForTimeInterval:[[self evaluate:[raw substringFromIndex:6] variables:vars]doubleValue]];continue; }
        if([u isEqual:@"CLS"]){[self.platform clearText];continue;}
        if([u isEqual:@"LIST"]||[u isEqual:@"LLIST"]){
            [self.platform writeText:[[self.lines componentsJoinedByString:@"\n"]stringByAppendingString:@"\n"]];continue;
        }
        if([u hasPrefix:@"FILES"]){
            NSString *path=raw.length>5?MBString([self evaluate:[raw substringFromIndex:5]variables:vars]):@".";
            NSArray *files=[[NSFileManager defaultManager]contentsOfDirectoryAtPath:path error:NULL]?:@[];
            [self.platform writeText:[[[files sortedArrayUsingSelector:@selector(compare:)]componentsJoinedByString:@"\n"]stringByAppendingString:@"\n"]];continue;
        }
        if([u hasPrefix:@"SAVE "]){
            NSString *path=MBString([self evaluate:[raw substringFromIndex:5]variables:vars]);NSError *e=nil;
            if(![[self.lines componentsJoinedByString:@"\n"]writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&e]&&error){*error=[self err:e.localizedDescription line:pc];return NO;}continue;
        }
        if([u hasPrefix:@"CHAIN "]||[u hasPrefix:@"RUN "]){
            NSUInteger offset=[u hasPrefix:@"CHAIN "]?6:4;NSString *path=MBString([self evaluate:[raw substringFromIndex:offset]variables:vars]);NSError *e=nil;
            NSString *program=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&e];
            if(!program){if(error)*error=[self err:e.localizedDescription line:pc];return NO;}return [self runSource:program error:error];
        }
        if([u isEqual:@"SYSTEM"]||[u isEqual:@"NEW"])return YES;
        if([u isEqual:@"CLEAR"]){[vars removeAllObjects];continue;}
        if([u hasPrefix:@"DEFINT "]||[u hasPrefix:@"DEFLNG "]||[u hasPrefix:@"DEFSNG "]||[u hasPrefix:@"DEFDBL "]||[u hasPrefix:@"DEFSTR "]){
            NSString *type=[u hasPrefix:@"DEFINT "]?@"%":([u hasPrefix:@"DEFLNG "]?@"&":([u hasPrefix:@"DEFSNG "]?@"!":([u hasPrefix:@"DEFDBL "]?@"#":@"$")));
            NSRange firstSpace=[raw rangeOfString:@" "];NSString *ranges=MBTrim([raw substringFromIndex:NSMaxRange(firstSpace)]);
            for(NSString *item in [self parts:ranges]){
                NSString *range=[[MBTrim(item)uppercaseString]copy];NSArray *ends=[range componentsSeparatedByString:@"-"];
                if((ends.count!=1&&ends.count!=2)||[MB_GET(ends,0)length]!=1||(ends.count==2&&[MB_GET(ends,1)length]!=1)){
                    if(error)*error=[self err:@"DEF type ranges must use letters such as A-Z or Q" line:pc];return NO;
                }
                unichar first=[MB_GET(ends,0)characterAtIndex:0],last=ends.count==2?[MB_GET(ends,1)characterAtIndex:0]:first;
                if(first<'A'||first>'Z'||last<'A'||last>'Z'||first>last){
                    if(error)*error=[self err:@"Invalid DEF type letter range" line:pc];return NO;
                }
                for(unichar letter=first;letter<=last;letter++)MB_SET(self.defaultTypes,([NSString stringWithFormat:@"%C",letter]),type);
            }
            continue;
        }
        if([u hasPrefix:@"CHDIR "]){
            NSString *path=MBString([self evaluate:[raw substringFromIndex:6]variables:vars]);
            if(![[NSFileManager defaultManager]changeCurrentDirectoryPath:path]&&error){*error=[self err:@"Unable to change directory" line:pc];return NO;}continue;
        }
        if([u hasPrefix:@"KILL "]){
            NSError *e=nil;NSString *path=MBString([self evaluate:[raw substringFromIndex:5]variables:vars]);
            if(![[NSFileManager defaultManager]removeItemAtPath:path error:&e]&&error){*error=[self err:e.localizedDescription line:pc];return NO;}continue;
        }
        if([u hasPrefix:@"NAME "]&&[u containsString:@" AS "]){
            NSRange as=[u rangeOfString:@" AS "];NSString *old=MBString([self evaluate:[raw substringWithRange:NSMakeRange(5,as.location-5)]variables:vars]);
            NSString *new=MBString([self evaluate:[raw substringFromIndex:NSMaxRange(as)]variables:vars]);NSError *e=nil;
            if(![[NSFileManager defaultManager]moveItemAtPath:old toPath:new error:&e]&&error){*error=[self err:e.localizedDescription line:pc];return NO;}continue;
        }
        if([u hasPrefix:@"POKE "]||[u hasPrefix:@"POKEW "]||[u hasPrefix:@"POKEL "]){
            NSUInteger offset=[u hasPrefix:@"POKEW "]?6:([u hasPrefix:@"POKEL "]?6:5);NSArray *p=[self parts:[raw substringFromIndex:offset]];
            if(p.count>=2)MB_SET(self.memory,@([[self evaluate:MB_GET(p,0)variables:vars]integerValue]),@([[self evaluate:MB_GET(p,1)variables:vars]integerValue]));continue;
        }
        if([u hasPrefix:@"SWAP "]){
            NSArray *p=[self parts:[raw substringFromIndex:5]];if(p.count==2){NSString *a=[MB_GET(p,0)uppercaseString],*b=[MB_GET(p,1)uppercaseString];id temp=MB_GET(vars,a)?:@0;MB_SET(vars,a,MB_GET(vars,b)?:@0);MB_SET(vars,b,temp);}continue;
        }
        if([u hasPrefix:@"WAIT "]){
            NSArray *p=[self parts:[raw substringFromIndex:5]];NSInteger address=[[self evaluate:MB_GET(p,0)variables:vars]integerValue],mask=p.count>1?[[self evaluate:MB_GET(p,1)variables:vars]integerValue]:-1;
            while(!self.stopped&&([MB_GET(self.memory,@(address))integerValue]&mask)==0)[NSThread sleepForTimeInterval:.001];continue;
        }
        if([u hasPrefix:@"LIBRARY "]||[u hasPrefix:@"DECLARE "]||[u hasPrefix:@"COMMON "]||[u hasPrefix:@"SHARED "]||[u hasPrefix:@"STATIC "])continue;
        if([u hasPrefix:@"OBJECT."]){
            NSRegularExpression *set=[NSRegularExpression regularExpressionWithPattern:@"(?i)^OBJECT\\.([A-Z]+)\\s*\\((.*?)\\)\\s*=\\s*(.*)$" options:0 error:NULL];
            NSTextCheckingResult *m=[set firstMatchInString:raw options:0 range:NSMakeRange(0,raw.length)];
            if(m){NSString *property=[[raw substringWithRange:[m rangeAtIndex:1]]uppercaseString];NSNumber *number=@([[self evaluate:[raw substringWithRange:[m rangeAtIndex:2]]variables:vars]integerValue]);
                NSMutableDictionary *object=MB_GET(self.objects,number)?:[NSMutableDictionary dictionary];MB_SET(object,property,[self evaluate:[raw substringWithRange:[m rangeAtIndex:3]]variables:vars]);MB_SET(self.objects,number,object);continue;}
            NSRegularExpression *action=[NSRegularExpression regularExpressionWithPattern:@"(?i)^OBJECT\\.(ON|OFF|START|STOP|CLOSE)\\s*\\(?\\s*([0-9]+)\\s*\\)?$" options:0 error:NULL];
            m=[action firstMatchInString:raw options:0 range:NSMakeRange(0,raw.length)];
            if(m){NSString *command=[[raw substringWithRange:[m rangeAtIndex:1]]uppercaseString];NSNumber *number=@([[raw substringWithRange:[m rangeAtIndex:2]]integerValue]);
                if([command isEqual:@"CLOSE"])[self.objects removeObjectForKey:number];else{NSMutableDictionary *object=MB_GET(self.objects,number)?:[NSMutableDictionary dictionary];
                    MB_SET(object,@"ON",@([command isEqual:@"ON"]||[command isEqual:@"START"]));MB_SET(object,@"MOVING",@([command isEqual:@"START"]));MB_SET(self.objects,number,object);}continue;}
        }
        NSRange eq=[raw rangeOfString:@"="]; if(eq.location!=NSNotFound){
            NSString *left=MBTrim([raw substringToIndex:eq.location]);if([[left uppercaseString]hasPrefix:@"LET "])left=MBTrim([left substringFromIndex:4]);
            BOOL rightSet=[[left uppercaseString]hasPrefix:@"RSET "];BOOL leftSet=[[left uppercaseString]hasPrefix:@"LSET "];
            if(rightSet||leftSet)left=MBTrim([left substringFromIndex:5]);
            id value=[self evaluate:[raw substringFromIndex:eq.location+1] variables:vars]?:@0;
            NSRange par=[left rangeOfString:@"("];
            if(par.location!=NSNotFound&&[left hasSuffix:@")"]){
                NSString *name=[[MBTrim([left substringToIndex:par.location])uppercaseString]copy];MBArray *array=MB_GET(vars,name);
                if(![array isKindOfClass:[MBArray class]]){if(error)*error=[self err:[NSString stringWithFormat:@"Array '%@' is not dimensioned",name] line:pc];return NO;}
                NSMutableArray *indices=[NSMutableArray array];
                for(NSString *p in [self parts:[left substringWithRange:NSMakeRange(par.location+1,left.length-par.location-2)]])
                    [indices addObject:[self evaluate:p variables:vars]];
                [array setValue:value at:indices];
            }else {NSString *name=[left uppercaseString];
                if(leftSet||rightSet){NSUInteger width=MBString(MB_GET(vars,name)).length;for(MBFile *file in self.files.allValues)for(NSDictionary *field in file.fields)
                        if([MB_GET(field,@"name")isEqual:name])width=[MB_GET(field,@"length")unsignedIntegerValue];
                    NSString *s=MBString(value);if(s.length>width)s=[s substringToIndex:width];
                    NSUInteger pad=width-s.length;NSString *spaces=[@"" stringByPaddingToLength:pad withString:@" " startingAtIndex:0];
                    value=rightSet?[spaces stringByAppendingString:s]:[s stringByAppendingString:spaces];}
                MB_SET(vars,name,[self coerceValue:value forName:name]);}
            continue;
        }
        NSRange par=[raw rangeOfString:@"("]; NSString *name; NSArray *argTexts;
        if(par.location!=NSNotFound&&[raw hasSuffix:@")"]){name=MBTrim([raw substringToIndex:par.location]);argTexts=[self parts:[raw substringWithRange:NSMakeRange(par.location+1,raw.length-par.location-2)]];}
        else {NSArray *bits=[raw componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];name=MB_GET(bits,0);NSString *tail=raw.length>name.length?MBTrim([raw substringFromIndex:name.length]):@"";argTexts=[self parts:tail];}
        NSMutableArray *args=[NSMutableArray array];for(NSString *p in argTexts)[args addObject:[self evaluate:p variables:vars]?:@0];
        if(![self call:name args:args variables:vars error:error]&&error&&*error)return NO;
    } return YES;
}
- (id)call:(NSString *)name args:(NSArray *)args variables:(NSMutableDictionary *)caller error:(NSError **)error {
    NSString *key=[name uppercaseString];
    if([key isEqual:@"LEN"])return @([MBString(args.firstObject) length]);
    if([key isEqual:@"LBOUND"]&&[args.firstObject isKindOfClass:[MBArray class]])return @([(MBArray *)args.firstObject lowerBound]);
    if([key isEqual:@"UBOUND"]&&[args.firstObject isKindOfClass:[MBArray class]]){
        MBArray *a=args.firstObject;NSInteger d=args.count>1?[MB_GET(args,1)integerValue]-1:0;
        return d>=0&&d<(NSInteger)a.dimensions.count?MB_GET(a.dimensions,d):@0;
    }
    if([key isEqual:@"STR$"])return MBString(args.firstObject);
    if([key isEqual:@"VAL"])return @([args.firstObject doubleValue]);
    if([key isEqual:@"RND"])return @((double)random()/RAND_MAX);
    double n=[args.firstObject doubleValue];
    if([key isEqual:@"ABS"])return @(fabs(n));
    if([key isEqual:@"ATN"])return @(atan(n));
    if([key isEqual:@"COS"])return @(cos(n));
    if([key isEqual:@"EXP"])return @(exp(n));
    if([key isEqual:@"FIX"])return @(trunc(n));
    if([key isEqual:@"INT"])return @(floor(n));
    if([key isEqual:@"LOG"])return @(log(n));
    if([key isEqual:@"SGN"])return @(n>0?1:(n<0?-1:0));
    if([key isEqual:@"SIN"])return @(sin(n));
    if([key isEqual:@"SQR"])return @(sqrt(n));
    if([key isEqual:@"TAN"])return @(tan(n));
    if([@[@"CINT",@"CLNG"] containsObject:key])return @(llround(n));
    if([@[@"CSNG",@"CDBL"] containsObject:key])return @(n);
    NSString *s=MBString(args.firstObject);
    if([key isEqual:@"ASC"])return @(s.length?[s characterAtIndex:0]:0);
    if([key isEqual:@"CHR$"])return [NSString stringWithFormat:@"%C",(unichar)[args.firstObject integerValue]];
    if([key isEqual:@"LEFT$"]){NSUInteger count=MIN(s.length,(NSUInteger)MAX(0,[MB_GET(args,1)integerValue]));return [s substringToIndex:count];}
    if([key isEqual:@"RIGHT$"]){NSUInteger count=MIN(s.length,(NSUInteger)MAX(0,[MB_GET(args,1)integerValue]));return [s substringFromIndex:s.length-count];}
    if([key isEqual:@"MID$"]){NSInteger start=MAX(1,[MB_GET(args,1)integerValue]);NSUInteger location=MIN(s.length,(NSUInteger)(start-1));
        NSUInteger count=args.count>2?MIN(s.length-location,(NSUInteger)MAX(0,[MB_GET(args,2)integerValue])):s.length-location;
        return [s substringWithRange:NSMakeRange(location,count)];}
    if([key isEqual:@"SPACE$"])return [@"" stringByPaddingToLength:MAX(0,[args.firstObject integerValue]) withString:@" " startingAtIndex:0];
    if([@[@"SPC",@"TAB",@"PTAB"]containsObject:key])return [@"" stringByPaddingToLength:MAX(0,[args.firstObject integerValue]) withString:@" " startingAtIndex:0];
    if([key isEqual:@"STRING$"]){NSUInteger count=MAX(0,[args.firstObject integerValue]);NSString *ch=args.count>1?MBString(MB_GET(args,1)):@" ";
        if(!ch.length)return @"";return [@"" stringByPaddingToLength:count withString:[ch substringToIndex:1] startingAtIndex:0];}
    if([key isEqual:@"UCASE$"])return [s uppercaseString];
    if([key isEqual:@"LCASE$"])return [s lowercaseString];
    if([key isEqual:@"INSTR"]){NSUInteger start=args.count>2?MAX(1,[MB_GET(args,0)integerValue]):1;NSString *hay=MBString(MB_GET(args,args.count>2?1:0));NSString *needle=MBString(MB_GET(args,args.count>2?2:1));
        if(start>hay.length)return @0;NSRange r=[hay rangeOfString:needle options:0 range:NSMakeRange(start-1,hay.length-start+1)];return @(r.location==NSNotFound?0:r.location+1);}
    if([key isEqual:@"INPUT$"]){NSUInteger count=MAX(0,[args.firstObject integerValue]);NSString *value;
        if(args.count>1){MBFile *file=MB_GET(self.files,@([MB_GET(args,1)integerValue]));value=file.index<file.lines.count?MB_GET(file.lines,file.index++):@"";}
        else value=[self.platform readInput:@""];return [value substringToIndex:MIN(count,value.length)];}
    if([key isEqual:@"TRANSLATE$"])return s;
    if([key isEqual:@"HEX$"])return [NSString stringWithFormat:@"%lX",(long)[args.firstObject integerValue]];
    if([key isEqual:@"OCT$"])return [NSString stringWithFormat:@"%lo",(long)[args.firstObject integerValue]];
    if([key isEqual:@"MKI$"]){int16_t v=(int16_t)[args.firstObject integerValue];return MBByteString(&v,sizeof v);}
    if([key isEqual:@"MKL$"]){int32_t v=(int32_t)[args.firstObject integerValue];return MBByteString(&v,sizeof v);}
    if([key isEqual:@"MKS$"]){float v=[args.firstObject floatValue];return MBByteString(&v,sizeof v);}
    if([key isEqual:@"MKD$"]){double v=[args.firstObject doubleValue];return MBByteString(&v,sizeof v);}
    if([@[@"CVI",@"CVL",@"CVS",@"CVD"]containsObject:key]){NSData *d=[s dataUsingEncoding:NSISOLatin1StringEncoding];const void *bytes=d.bytes;
        if([key isEqual:@"CVI"]&&d.length>=2){int16_t v;memcpy(&v,bytes,2);return @(v);}
        if([key isEqual:@"CVL"]&&d.length>=4){int32_t v;memcpy(&v,bytes,4);return @(v);}
        if([key isEqual:@"CVS"]&&d.length>=4){float v;memcpy(&v,bytes,4);return @(v);}
        if([key isEqual:@"CVD"]&&d.length>=8){double v;memcpy(&v,bytes,8);return @(v);}return @0;}
    if([key isEqual:@"DATE$"]){NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"MM-dd-yyyy";return [f stringFromDate:[NSDate date]];}
    if([key isEqual:@"TIME$"]){NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"HH:mm:ss";return [f stringFromDate:[NSDate date]];}
    if([key isEqual:@"TIMER"])return @([[NSDate date]timeIntervalSince1970]);
    if([@[@"INKEY$",@"MOUSE",@"STICK",@"STRIG"] containsObject:key])
        return [self.platform inputValue:key argument:[args.firstObject integerValue]]?:@0;
    if([key isEqual:@"MENU"]){NSInteger which=[args.firstObject integerValue];return @([self.platform menuValue:which reset:which==0]);}
    if([@[@"EOF",@"LOC",@"LOF"] containsObject:key]){
        MBFile *file=MB_GET(self.files,@([args.firstObject integerValue]));if(!file)return @(-1);
        if([key isEqual:@"EOF"])return @(file.index>=file.lines.count?-1:0);
        if([key isEqual:@"LOC"])return @(file.index);
        NSDictionary *attributes=[[NSFileManager defaultManager]attributesOfItemAtPath:file.path error:NULL];
        return MB_GET(attributes,NSFileSize)?:@(file.output.length);
    }
    if([@[@"PEEK",@"PEEKW",@"PEEKL"]containsObject:key])return MB_GET(self.memory,@([args.firstObject integerValue]))?:@0;
    if([key isEqual:@"FRE"])return @(NSIntegerMax);
    if([@[@"POS",@"LPOS",@"CSRLIN",@"POINT"]containsObject:key])return @0;
    if([key hasPrefix:@"OBJECT."]){NSMutableDictionary *object=MB_GET(self.objects,@([args.firstObject integerValue]));
        return MB_GET(object,[key substringFromIndex:7])?:@0;}
    if([key isEqual:@"COLLISION"]||[key isEqual:@"OBJECT.HIT"]){
        NSDictionary *a=MB_GET(self.objects,@([args.firstObject integerValue])),*b=args.count>1?MB_GET(self.objects,@([MB_GET(args,1)integerValue])):nil;
        if(!a||!b)return @0;NSRect ar=NSMakeRect([MB_GET(a,@"X")doubleValue],[MB_GET(a,@"Y")doubleValue],MAX(1,[MB_GET(a,@"W")doubleValue]),MAX(1,[MB_GET(a,@"H")doubleValue]));
        NSRect br=NSMakeRect([MB_GET(b,@"X")doubleValue],[MB_GET(b,@"Y")doubleValue],MAX(1,[MB_GET(b,@"W")doubleValue]),MAX(1,[MB_GET(b,@"H")doubleValue]));
        return @(NSIntersectsRect(ar,br)?-1:0);
    }
    if([key isEqual:@"VARPTR"]||[key isEqual:@"SADD"])return @((NSUInteger)(__bridge void *)args.firstObject);
    NSDictionary *p=MB_GET(self.procedures,key); if(!p){if(error)*error=[self err:[NSString stringWithFormat:@"Unknown statement or procedure '%@'",name] line:0];return nil;}
    NSMutableDictionary *local=[caller mutableCopy]; NSArray *params=MB_GET(p,@"params");
    for(NSUInteger i=0;i<params.count;i++){NSString *paramName=[MB_GET(params,i) uppercaseString];MB_SET(local,paramName,[self coerceValue:(i<args.count?MB_GET(args,i):@0) forName:paramName]);}
    id value=@0;BOOL returned=NO;
    [self executeFrom:[MB_GET(p,@"start") unsignedIntegerValue] to:[MB_GET(p,@"end") unsignedIntegerValue] variables:local result:&value returned:&returned error:error];
    return [self coerceValue:value forName:key];
}
- (BOOL)runSource:(NSString *)source error:(NSError **)error {
    self.stopped=NO;self.labelLines=[NSMutableDictionary dictionary];NSMutableArray *prepared=[NSMutableArray array];
    for(NSString *original in [source componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]){
        NSString *line=original;NSString *trim=MBTrim(line);
        NSRegularExpression *numbered=[NSRegularExpression regularExpressionWithPattern:@"^([0-9]+)\\s+(.*)$" options:0 error:NULL];
        NSTextCheckingResult *match=[numbered firstMatchInString:trim options:0 range:NSMakeRange(0,trim.length)];
        if(match){MB_SET(self.labelLines,[trim substringWithRange:[match rangeAtIndex:1]],@(prepared.count));
            line=[trim substringWithRange:[match rangeAtIndex:2]];trim=MBTrim(line);}
        if([trim hasSuffix:@":"]){NSString *label=[[MBTrim([trim substringToIndex:trim.length-1])uppercaseString]copy];MB_SET(self.labelLines,label,@(prepared.count));}
        [prepared addObject:line];
    }
    self.lines=prepared;
    [self.procedures removeAllObjects];self.dataItems=[NSMutableArray array];self.dataLabels=[NSMutableDictionary dictionary];self.dataIndex=0;self.optionBase=0;self.defaultTypes=[NSMutableDictionary dictionary];self.files=[NSMutableDictionary dictionary];self.areaPoints=[NSMutableArray array];self.waveforms=[NSMutableDictionary dictionary];self.memory=[NSMutableDictionary dictionary];self.objects=[NSMutableDictionary dictionary];self.errorHandlerLine=nil;self.resumeTarget=nil;
    NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"(?i)^(SUB|FUNCTION)\\s+([A-Z_$][A-Z0-9_$]*)\\s*(?:\\((.*)\\))?$" options:0 error:NULL];
    for(NSUInteger i=0;i<self.lines.count;i++){NSString *s=MBTrim(MB_GET(self.lines,i));NSTextCheckingResult *m=[re firstMatchInString:s options:0 range:NSMakeRange(0,s.length)];if(!m)continue;
        NSString *name=[[s substringWithRange:[m rangeAtIndex:2]]uppercaseString];NSString *params=[m rangeAtIndex:3].location==NSNotFound?@"":[s substringWithRange:[m rangeAtIndex:3]];
        NSUInteger end=[self findEndFrom:i open:@"~" close:@[[[s uppercaseString]hasPrefix:@"SUB"]?@"END SUB":@"END FUNCTION"] elseAt:NULL];
        MB_SET(self.procedures,name,(@{@"params":[self parts:params],@"start":@(i+1),@"end":@(end)}));i=end;
    }
    NSString *pendingLabel=nil;
    for(NSString *line in self.lines){
        NSString *s=MBTrim(line),*u=[s uppercaseString];
        if([s hasSuffix:@":"]){pendingLabel=[[MBTrim([s substringToIndex:s.length-1])uppercaseString]copy];continue;}
        if([u hasPrefix:@"DATA"]&&(u.length==4||[u characterAtIndex:4]==' ')){
            if(pendingLabel){MB_SET(self.dataLabels,pendingLabel,@(self.dataItems.count));pendingLabel=nil;}
            NSString *tail=s.length>4?MBTrim([s substringFromIndex:4]):@"";
            for(NSString *item in [self parts:tail]){
                NSString *v=MBTrim(item);
                if([v hasPrefix:@"\""]&&[v hasSuffix:@"\""]&&v.length>=2)[self.dataItems addObject:[v substringWithRange:NSMakeRange(1,v.length-2)]];
                else [self.dataItems addObject:@([v doubleValue])];
            }
        }
    }
    NSMutableDictionary *globals=[NSMutableDictionary dictionary];BOOL ok=[self executeFrom:0 to:self.lines.count variables:globals result:NULL returned:NULL error:error];
    if(!ok&&self.errorHandlerLine){
        self.faultLine=self.currentLine;NSError *fault=error?*error:nil;MB_SET(globals,@"ERR",@(fault.code));MB_SET(globals,@"ERL",@(self.faultLine+1));
        if(error)*error=nil;self.resumeTarget=nil;
        ok=[self executeFrom:self.errorHandlerLine.unsignedIntegerValue to:self.lines.count variables:globals result:NULL returned:NULL error:error];
        if(ok&&self.resumeTarget)ok=[self executeFrom:self.resumeTarget.unsignedIntegerValue to:self.lines.count variables:globals result:NULL returned:NULL error:error];
    }
    return ok;
}
@end
