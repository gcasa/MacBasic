#import "MBDocument.h"
#import "MBCompiler.h"

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

static NSString * const MBRunToolbarItem=@"org.macbasic.toolbar.run";
static NSString * const MBTraceToolbarItem=@"org.macbasic.toolbar.trace";
static NSString * const MBStopToolbarItem=@"org.macbasic.toolbar.stop";
static NSString * const MBStepToolbarItem=@"org.macbasic.toolbar.step";
static NSString * const MBCompileToolbarItem=@"org.macbasic.toolbar.compile";

static NSColor *MBColor(id value) {
    NSString *s=[[value description] lowercaseString];
    NSDictionary *named=@{@"black":[NSColor blackColor],@"white":[NSColor whiteColor],
        @"red":[NSColor redColor],@"green":[NSColor greenColor],@"blue":[NSColor blueColor],
        @"cyan":[NSColor cyanColor],@"yellow":[NSColor yellowColor],@"gray":[NSColor grayColor],
        @"magenta":[NSColor magentaColor],@"orange":[NSColor orangeColor]};
    if(MB_GET(named,s))return MB_GET(named,s);
    if([s hasPrefix:@"#"]&&s.length==7){unsigned int rgb=0;[[NSScanner scannerWithString:[s substringFromIndex:1]]scanHexInt:&rgb];
        return [NSColor colorWithCalibratedRed:((rgb>>16)&255)/255.0 green:((rgb>>8)&255)/255.0 blue:(rgb&255)/255.0 alpha:1];}
    return [NSColor blackColor];
}

@interface MBCanvasView : NSView {
    NSMutableArray *_commands;
    NSString *_lastKey;
    NSPoint _mousePosition;
    BOOL _mousePressed;
}
@property (retain) NSMutableArray<NSDictionary *> *commands;
@property (copy) NSString *lastKey;
@property NSPoint mousePosition;
@property BOOL mousePressed;
- (void)addDrawingCommand:(NSDictionary *)command;
@end
@implementation MBCanvasView
@synthesize commands=_commands, lastKey=_lastKey, mousePosition=_mousePosition, mousePressed=_mousePressed;
- (instancetype)initWithFrame:(NSRect)frame {if((self=[super initWithFrame:frame]))_commands=[[NSMutableArray alloc]init];return self;}
- (BOOL)isFlipped {return YES;}
- (BOOL)acceptsFirstResponder {return YES;}
- (void)keyDown:(NSEvent *)event {self.lastKey=event.characters?:@"";}
- (void)mouseDown:(NSEvent *)event {self.mousePressed=YES;self.mousePosition=[self convertPoint:event.locationInWindow fromView:nil];}
- (void)mouseUp:(NSEvent *)event {self.mousePressed=NO;self.mousePosition=[self convertPoint:event.locationInWindow fromView:nil];}
- (void)mouseMoved:(NSEvent *)event {self.mousePosition=[self convertPoint:event.locationInWindow fromView:nil];}
- (void)mouseDragged:(NSEvent *)event {[self mouseMoved:event];}
- (void)addDrawingCommand:(NSDictionary *)command {
    if([MB_GET(command,@"type")isEqual:@"CLEAR"])[self.commands removeAllObjects];
    if([MB_GET(command,@"type")isEqual:@"PAINT"]){
        NSArray *paint=MB_GET(command,@"args");NSPoint point=NSMakePoint([MB_GET(paint,0)doubleValue],[MB_GET(paint,1)doubleValue]);
        for(NSInteger i=(NSInteger)self.commands.count-1;i>=0;i--){NSDictionary *old=MB_GET(self.commands,i);NSArray *a=MB_GET(old,@"args");NSRect r=NSZeroRect;
            if(([@[@"RECT",@"OVAL"]containsObject:MB_GET(old,@"type")])&&a.count>=4)r=NSMakeRect([MB_GET(a,0)doubleValue],[MB_GET(a,1)doubleValue],[MB_GET(a,2)doubleValue],[MB_GET(a,3)doubleValue]);
            if(NSPointInRect(point,r)){NSMutableArray *args=[a mutableCopy];while(args.count<6)[args addObject:@0];MB_SET(args,4,paint.count>2?MB_GET(paint,2):@"black");MB_SET(args,5,@1);
                MB_SET(self.commands,i,(@{@"type":MB_GET(old,@"type"),@"args":args}));[self setNeedsDisplay:YES];return;}}
    }
    [self.commands addObject:command];[self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor whiteColor]setFill];NSRectFill(self.bounds);
    for(NSDictionary *c in self.commands){NSString *type=MB_GET(c,@"type");NSArray *a=MB_GET(c,@"args");
        if([type isEqual:@"CLEAR"]){[(a.count?MBColor(MB_GET(a,0)):[NSColor whiteColor])setFill];NSRectFill(self.bounds);continue;}
        if([type isEqual:@"LINE"]&&a.count>=4){[(a.count>=5?MBColor(MB_GET(a,4)):[NSColor blackColor])setStroke];
            NSBezierPath *p=[NSBezierPath bezierPath];[p moveToPoint:NSMakePoint([MB_GET(a,0)doubleValue],[MB_GET(a,1)doubleValue])];
            [p lineToPoint:NSMakePoint([MB_GET(a,2)doubleValue],[MB_GET(a,3)doubleValue])];[p stroke];continue;}
        if(([type isEqual:@"RECT"]||[type isEqual:@"OVAL"])&&a.count>=4){
            NSRect r=NSMakeRect([MB_GET(a,0)doubleValue],[MB_GET(a,1)doubleValue],[MB_GET(a,2)doubleValue],[MB_GET(a,3)doubleValue]);
            NSBezierPath *p=[type isEqual:@"OVAL"]?[NSBezierPath bezierPathWithOvalInRect:r]:[NSBezierPath bezierPathWithRect:r];
            NSColor *color=a.count>=5?MBColor(MB_GET(a,4)):[NSColor blackColor];
            if(a.count>=6&&[MB_GET(a,5)boolValue]){[color setFill];[p fill];}else{[color setStroke];[p stroke];}continue;
        }
        if([type isEqual:@"TEXT"]&&a.count>=3){NSColor *color=a.count>=4?MBColor(MB_GET(a,3)):[NSColor blackColor];
            NSDictionary *attrs=@{NSForegroundColorAttributeName:color,NSFontAttributeName:[NSFont systemFontOfSize:14]};
            [[MB_GET(a,0)description]drawAtPoint:NSMakePoint([MB_GET(a,1)doubleValue],[MB_GET(a,2)doubleValue])withAttributes:attrs];}
        if([type isEqual:@"POLYGON"]&&a.count>=7){NSBezierPath *p=[NSBezierPath bezierPath];
            [p moveToPoint:NSMakePoint([MB_GET(a,0)doubleValue],[MB_GET(a,1)doubleValue])];
            for(NSUInteger i=2;i+1<a.count-1;i+=2)[p lineToPoint:NSMakePoint([MB_GET(a,i)doubleValue],[MB_GET(a,i+1)doubleValue])];
            [p closePath];[MBColor(a.lastObject)setFill];[p fill];}
    }
}
@end

@interface MBDocument ()
@property (retain) NSTextView *editor;
@property (retain) NSTextView *output;
@property (retain) MBInterpreter *interpreter;
@property (retain) NSMutableDictionary<NSNumber *, NSWindow *> *basicWindows;
@property (retain) NSMutableDictionary<NSNumber *, MBCanvasView *> *canvasViews;
@property NSInteger activeCanvasID;
@property (retain) NSMutableArray<NSSound *> *playingSounds;
@property NSInteger lastMenu;
@property NSInteger lastMenuItem;
@property (copy) NSString *sourceBeforeWindow;
@property BOOL programRunning;
@property BOOL tracePaused;
@property NSUInteger pendingTraceSteps;
@property (retain) NSCondition *traceCondition;
@property BOOL closingDocument;
@end

@implementation MBDocument
@synthesize editor=_editor, output=_output, interpreter=_interpreter, basicWindows=_basicWindows;
@synthesize canvasViews=_canvasViews, activeCanvasID=_activeCanvasID, playingSounds=_playingSounds;
@synthesize lastMenu=_lastMenu, lastMenuItem=_lastMenuItem, sourceBeforeWindow=_sourceBeforeWindow;
@synthesize programRunning=_programRunning, tracePaused=_tracePaused, pendingTraceSteps=_pendingTraceSteps;
@synthesize traceCondition=_traceCondition, closingDocument=_closingDocument;
- (instancetype)init {
    if ((self=[super init])) {
        _basicWindows=[[NSMutableDictionary alloc]init];
        _canvasViews=[[NSMutableDictionary alloc]init];
        _playingSounds=[[NSMutableArray alloc]init];
        _traceCondition=[[NSCondition alloc]init];
        _sourceBeforeWindow=@"' Welcome to MacBasic\n"
            "' String literals use the straight ASCII U+0022 delimiter only.\n"
            "SUB Greet(name$)\n"
            "  PRINT \"Hello, \" + name$\n"
            "END SUB\n\n"
            "FUNCTION Square(n)\n"
            "  RETURN n * n\n"
            "END FUNCTION\n\n"
            "Greet(\"Mac\")\n"
            "FOR i = 1 TO 5\n"
            "  PRINT i, Square(i)\n"
            "NEXT i\n\n"
            "' Create window 1 and draw into view 10\n"
            "WINDOW OPEN 1, \"MacBasic Drawing\", 640, 420, 160, 140\n"
            "VIEW ADD 10, 1, 20, 20, 600, 360\n"
            "CLEAR 10, \"#F5F3FF\"\n"
            "DRAW RECT 10, 30, 30, 540, 300, \"#4F46E5\", 0\n"
            "DRAW OVAL 10, 70, 80, 160, 160, \"#06B6D4\", 1\n"
            "DRAW OVAL 10, 370, 80, 160, 160, \"#EC4899\", 1\n"
            "DRAW LINE 10, 230, 160, 370, 160, \"#111827\"\n"
            "DRAW TEXT 10, \"MacBasic Graphics\", 205, 280, \"#312E81\"\n";
    }
    return self;
}
- (NSImage *)toolbarIconWithSymbol:(NSString *)symbol fallback:(NSString *)fallback {
#if !defined(GNUSTEP)
    if(@available(macOS 11.0,*)){
        NSImage *image=[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
        if(image)return image;
    }
#endif
    return [NSImage imageNamed:fallback];
}
- (NSToolbarItem *)toolbarItem:(NSString *)identifier label:(NSString *)label
                        symbol:(NSString *)symbol fallback:(NSString *)fallback
                       toolTip:(NSString *)toolTip action:(SEL)action {
    NSToolbarItem *item=[[NSToolbarItem alloc]initWithItemIdentifier:identifier];
    item.label=label;item.paletteLabel=label;item.toolTip=toolTip;
    item.image=[self toolbarIconWithSymbol:symbol fallback:fallback];
    item.target=self;item.action=action;
    return item;
}
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[MBRunToolbarItem,MBTraceToolbarItem,MBStopToolbarItem,MBStepToolbarItem,MBCompileToolbarItem,
             NSToolbarFlexibleSpaceItemIdentifier,NSToolbarSpaceItemIdentifier];
}
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[MBRunToolbarItem,MBTraceToolbarItem,MBStopToolbarItem,MBStepToolbarItem,
             NSToolbarFlexibleSpaceItemIdentifier,MBCompileToolbarItem];
}
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)identifier
 willBeInsertedIntoToolbar:(BOOL)flag {
    if([identifier isEqual:MBRunToolbarItem])
        return [self toolbarItem:identifier label:@"Run" symbol:@"play.fill"
                       fallback:@"NSRightFacingTriangleTemplate"
                        toolTip:@"Run the program at full speed" action:@selector(run:)];
    if([identifier isEqual:MBTraceToolbarItem])
        return [self toolbarItem:identifier label:@"Trace" symbol:@"point.topleft.down.curvedto.point.bottomright.up"
                       fallback:@"NSQuickLookTemplate"
                        toolTip:@"Run slowly and highlight each executing line" action:@selector(trace:)];
    if([identifier isEqual:MBStopToolbarItem])
        return [self toolbarItem:identifier label:@"Stop" symbol:@"stop.fill"
                       fallback:@"NSStopProgressTemplate"
                        toolTip:@"Pause a trace, or stop the running program" action:@selector(stop:)];
    if([identifier isEqual:MBStepToolbarItem])
        return [self toolbarItem:identifier label:@"Step" symbol:@"forward.frame.fill"
                       fallback:@"NSGoRightTemplate"
                        toolTip:@"Execute the next line of a paused trace" action:@selector(step:)];
    if([identifier isEqual:MBCompileToolbarItem])
        return [self toolbarItem:identifier label:@"Compile" symbol:@"hammer.fill"
                       fallback:@"NSActionTemplate"
                        toolTip:@"Compile the program as an application or command-line tool"
                         action:@selector(compileDocument:)];
    return nil;
}
- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
    if([item.itemIdentifier isEqual:MBStepToolbarItem])
        return self.programRunning&&self.tracePaused;
    if([item.itemIdentifier isEqual:MBStopToolbarItem])
        return self.programRunning;
    return YES;
}
- (NSScrollView *)scrollWithText:(NSTextView **)text frame:(NSRect)frame editable:(BOOL)editable {
    NSScrollView *s=[[NSScrollView alloc]initWithFrame:frame];s.hasVerticalScroller=YES;s.hasHorizontalScroller=YES;
    NSTextView *v=[[NSTextView alloc]initWithFrame:s.contentView.bounds];v.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    v.editable=editable;v.richText=NO;v.font=[NSFont userFixedPitchFontOfSize:13];v.delegate=editable?(id)self:nil;
    v.drawsBackground=YES;
    if(editable){
        v.backgroundColor=[NSColor colorWithCalibratedRed:0.95 green:0.93 blue:0.86 alpha:1.0];
        v.textColor=[NSColor blackColor];
#if !defined(GNUSTEP)
        v.automaticQuoteSubstitutionEnabled=NO;
#endif
    }else{
        v.backgroundColor=[NSColor whiteColor];v.textColor=[NSColor blackColor];
    }
    s.documentView=v;*text=v;return s;
}
- (void)makeWindowControllers {
    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(100,100,900,650)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    [window setReleasedWhenClosed:NO];
#if !defined(GNUSTEP)
    window.animationBehavior=NSWindowAnimationBehaviorNone;
#endif
    window.minSize=NSMakeSize(600,420);
    NSTextView *editorText=nil,*outputText=nil;
    NSScrollView *editor=[self scrollWithText:&editorText frame:NSMakeRect(10,205,880,435) editable:YES];
    NSScrollView *output=[self scrollWithText:&outputText frame:NSMakeRect(10,10,880,185) editable:NO];
    self.editor=editorText;self.output=outputText;
    editor.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    output.autoresizingMask=NSViewWidthSizable|NSViewMaxYMargin;
    NSView *content=window.contentView;[content addSubview:editor];[content addSubview:output];
    NSToolbar *toolbar=[[NSToolbar alloc]initWithIdentifier:@"org.macbasic.document.toolbar"];
    toolbar.delegate=self;toolbar.displayMode=NSToolbarDisplayModeIconAndLabel;
    toolbar.allowsUserCustomization=YES;toolbar.autosavesConfiguration=NO;
    window.toolbar=toolbar;
    self.editor.string=self.sourceBeforeWindow?:@"";self.output.string=@"Ready.\n";
    [self highlightSyntax];
    [self addWindowController:[[NSWindowController alloc]initWithWindow:window]];
}
- (NSString *)windowNibName { return nil; }
- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSString *source=self.editor?self.editor.string:self.sourceBeforeWindow;
    return [source dataUsingEncoding:NSUTF8StringEncoding];
}
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSString *source=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    if(!source){
        if(outError)*outError=[NSError errorWithDomain:@"MacBasic" code:2 userInfo:@{NSLocalizedDescriptionKey:@"The file is not valid UTF-8 text."}];
        return NO;
    }
    self.sourceBeforeWindow=source;if(self.editor)self.editor.string=source;return YES;
}
- (void)textDidChange:(NSNotification *)notification {
    [self updateChangeCount:NSChangeDone];
    [self highlightSyntax];
}
- (void)colorPattern:(NSString *)pattern color:(NSColor *)color options:(NSRegularExpressionOptions)options {
    NSError *error=nil;NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:pattern options:options error:&error];
    if(error)return;NSRange all=NSMakeRange(0,self.editor.string.length);
    for(NSTextCheckingResult *match in [regex matchesInString:self.editor.string options:0 range:all])
        [self.editor.textStorage addAttribute:NSForegroundColorAttributeName value:color range:match.range];
}
- (void)highlightSyntax {
    if(!self.editor)return;
    NSTextStorage *storage=self.editor.textStorage;NSRange all=NSMakeRange(0,storage.length);
    [storage beginEditing];
    [storage setAttributes:@{NSForegroundColorAttributeName:[NSColor blackColor],
        NSFontAttributeName:[NSFont userFixedPitchFontOfSize:13]} range:all];
    NSRegularExpressionOptions ci=NSRegularExpressionCaseInsensitive;
    [self colorPattern:@"\\b(SUB|END\\s+SUB|FUNCTION|END\\s+FUNCTION|RETURN|IF|THEN|ELSE|ELSEIF|END\\s+IF|ENDIF|FOR|TO|STEP|NEXT|WHILE|WEND|AND|OR|XOR|EQV|IMP|MOD|NOT|PRINT|USING|INPUT|WINDOW|OPEN|CLOSE|VIEW|ADD|DRAW|LINE|RECT|OVAL|CIRCLE|PSET|PRESET|AREA|AREAFILL|PAINT|COLOR|TEXT|CLEAR|PROCESS|RUN|SLEEP|DATA|READ|RESTORE|SOUND|WAVE|SAY|PLAY|STOP|BEEP|DIM|ERASE|OPTION|BASE|GOTO|GOSUB|ON|ERROR|RESUME|MENU|MOUSE|TIMER|FIELD|GET|PUT|WRITE|LSET|RSET|RANDOMIZE|POKE|POKEW|POKEL|POINTER|PROTOTYPE|INTERFACE|METHOD|DATABASE|THREADED|THREAD|WAIT|SWAP|KILL|NAME|CHDIR|FILES|CHAIN|LIST|CLS|REM)\\b"
                 color:[NSColor colorWithCalibratedRed:0.16 green:0.25 blue:0.67 alpha:1] options:ci];
    [self colorPattern:@"\\b\\d+(?:\\.\\d+)?\\b"
                 color:[NSColor colorWithCalibratedRed:0.55 green:0.20 blue:0.65 alpha:1] options:0];
    [self colorPattern:@"(?m)^[ \\t]*[A-Za-z_][A-Za-z0-9_$]*:"
                 color:[NSColor colorWithCalibratedRed:0.65 green:0.32 blue:0.05 alpha:1] options:0];
    [self colorPattern:@"\\b[A-Za-z_][A-Za-z0-9_$]*(?=\\s*\\()"
                 color:[NSColor colorWithCalibratedRed:0.05 green:0.46 blue:0.40 alpha:1] options:0];
    [self colorPattern:@"\"(?:\"\"|[^\"\\r\\n])*\""
                 color:[NSColor colorWithCalibratedRed:0.70 green:0.12 blue:0.18 alpha:1] options:0];
    [self colorPattern:@"(?im)(?:'[^\r\n]*|\\bREM\\b[^\r\n]*)"
                 color:[NSColor colorWithCalibratedRed:0.35 green:0.45 blue:0.35 alpha:1] options:0];
    [storage endEditing];
}
- (void)run:(id)sender {
    [self startProgramTracing:NO];
}
- (void)trace:(id)sender {
    [self startProgramTracing:YES];
}
- (void)startProgramTracing:(BOOL)tracing {
    if(self.programRunning){
        if(self.tracePaused){
            self.interpreter.tracing=tracing;
            [self.traceCondition lock];
            self.tracePaused=NO;self.pendingTraceSteps=0;
            [self.traceCondition broadcast];
            [self.traceCondition unlock];
            [self writeText:tracing?@"Trace resumed.\n":@"Program resumed at full speed.\n"];
        }else [self writeText:@"A program is already running.\n"];
        return;
    }
    self.programRunning=YES;
    self.tracePaused=NO;self.pendingTraceSteps=0;
    self.output.string=@"";self.interpreter=[[MBInterpreter alloc]initWithPlatform:self];
    self.interpreter.tracing=tracing;
    self.editor.editable=NO;
    NSString *source=[self.editor.string copy];
    [NSThread detachNewThreadSelector:@selector(runSourceInBackground:) toTarget:self withObject:source];
}
- (void)runSourceInBackground:(NSString *)source {
    @autoreleasepool {
        NSError *error=nil;BOOL ok=[self.interpreter runSource:source error:&error];
        if(!ok&&error)[self writeText:[NSString stringWithFormat:@"Error: %@\n",error.localizedDescription]];
        else if(!self.interpreter.stopped)[self writeText:@"Program finished.\n"];
        [self performSelectorOnMainThread:@selector(programDidFinish) withObject:nil waitUntilDone:NO];
    }
}
- (void)programDidFinish {
    [self.traceCondition lock];
    self.tracePaused=NO;self.pendingTraceSteps=0;
    [self.traceCondition broadcast];
    [self.traceCondition unlock];
    self.programRunning=NO;
    self.editor.editable=YES;
    [self clearTraceHighlight];
}
- (void)stop:(id)sender {
    if(!self.programRunning)return;
    if(self.interpreter.tracing&&!self.tracePaused){
        [self.traceCondition lock];
        self.tracePaused=YES;self.pendingTraceSteps=0;
        [self.traceCondition unlock];
        [self writeText:@"Trace paused. Use Step to execute one line, or Stop again to end the program.\n"];
        return;
    }
    self.interpreter.stopped=YES;
    [self.traceCondition lock];[self.traceCondition broadcast];[self.traceCondition unlock];
    [self writeText:@"Program stopped.\n"];
}
- (void)step:(id)sender {
    if(!self.programRunning||!self.tracePaused)return;
    [self.traceCondition lock];
    self.pendingTraceSteps++;
    [self.traceCondition signal];
    [self.traceCondition unlock];
}
- (void)showTracedLine:(NSNumber *)lineNumber {
    NSString *source=self.editor.string;
    NSUInteger target=lineNumber.unsignedIntegerValue,start=0;
    for(NSUInteger line=0;line<target&&start<source.length;line++)
        start=NSMaxRange([source lineRangeForRange:NSMakeRange(start,0)]);
    if(start>source.length)return;
    NSRange range=[source lineRangeForRange:NSMakeRange(start,0)];
    [self.editor.textStorage removeAttribute:NSBackgroundColorAttributeName
                                      range:NSMakeRange(0,self.editor.textStorage.length)];
    if(range.length){
        [self.editor.textStorage addAttribute:NSBackgroundColorAttributeName
                                        value:[NSColor colorWithCalibratedRed:1.0 green:0.90 blue:0.35 alpha:1.0]
                                        range:range];
        [self.editor scrollRangeToVisible:range];
    }
}
- (void)clearTraceHighlight {
    [self.editor.textStorage removeAttribute:NSBackgroundColorAttributeName
                                      range:NSMakeRange(0,self.editor.textStorage.length)];
}
- (void)traceLine:(NSUInteger)line {
    [self.traceCondition lock];
    while(self.tracePaused&&self.pendingTraceSteps==0&&!self.interpreter.stopped)
        [self.traceCondition wait];
    if(self.pendingTraceSteps>0)self.pendingTraceSteps--;
    BOOL stopped=self.interpreter.stopped;
    [self.traceCondition unlock];
    if(stopped)return;
    [self performSelectorOnMainThread:@selector(showTracedLine:) withObject:@(line) waitUntilDone:YES];
    [NSThread sleepForTimeInterval:0.08];
}
- (void)runCompiledSource:(NSString *)source {
    self.sourceBeforeWindow=source;
    [self makeWindowControllers];
    [self showWindows];
    [self performSelector:@selector(run:) withObject:nil afterDelay:0];
}
- (void)compileDocument:(id)sender {
    NSAlert *kindAlert=[NSAlert new];
    kindAlert.messageText=@"Choose a Build Type";
    kindAlert.informativeText=@"An application opens with the MacBasic window environment. A tool runs from a terminal.";
    [kindAlert addButtonWithTitle:@"Build Application"];
    [kindAlert addButtonWithTitle:@"Build Tool"];
    [kindAlert addButtonWithTitle:@"Cancel"];
    NSInteger kind=[kindAlert runModal];
    if(kind==NSAlertThirdButtonReturn)return;
    BOOL buildApplication=kind==NSAlertFirstButtonReturn;
    NSString *iconPath=nil;
    if(buildApplication){
        NSAlert *iconAlert=[NSAlert new];
        iconAlert.messageText=@"Application Icon";
        iconAlert.informativeText=@"Choose an icon file, or let MacBasic include its generic application icon.";
        [iconAlert addButtonWithTitle:@"Choose Icon…"];
        [iconAlert addButtonWithTitle:@"Use Generic Icon"];
        [iconAlert addButtonWithTitle:@"Cancel"];
        NSInteger iconChoice=[iconAlert runModal];
        if(iconChoice==NSAlertThirdButtonReturn)return;
        if(iconChoice==NSAlertFirstButtonReturn){
            NSOpenPanel *iconPanel=[NSOpenPanel openPanel];
#if defined(GNUSTEP)
            NSArray *types=@[@"png",@"tiff",@"icns"];
#else
            NSArray *types=@[@"icns"];
#endif
            if([iconPanel respondsToSelector:@selector(setAllowedFileTypes:)])
                [iconPanel performSelector:@selector(setAllowedFileTypes:) withObject:types];
#if defined(GNUSTEP)
            if([iconPanel runModal]!=NSOKButton)return;
#else
            if([iconPanel runModal]!=NSModalResponseOK)return;
#endif
            iconPath=iconPanel.URL.path;
        }
    }
    NSSavePanel *panel=[NSSavePanel savePanel];
    NSString *base=self.displayName.length?[self.displayName stringByDeletingPathExtension]:@"MacBasicProgram";
    NSString *name=buildApplication?[base stringByAppendingPathExtension:@"app"]:[base stringByAppendingString:@"-compiled"];
    if([panel respondsToSelector:@selector(setNameFieldStringValue:)])
        [panel performSelector:@selector(setNameFieldStringValue:) withObject:name];
#if defined(GNUSTEP)
    if([panel runModal]!=NSOKButton)return;
#else
    if([panel runModal]!=NSModalResponseOK)return;
#endif
    NSError *error=nil;
    NSString *source=self.editor?self.editor.string:self.sourceBeforeWindow;
    NSString *outputPath=panel.URL.path;
    if(buildApplication&&[[outputPath pathExtension]caseInsensitiveCompare:@"app"]!=NSOrderedSame)
        outputPath=[outputPath stringByAppendingPathExtension:@"app"];
    BOOL ok=buildApplication?MBCompileApplication(source,outputPath,iconPath,&error)
                            :MBCompileSource(source,outputPath,&error);
    if(ok)
        [self writeText:[NSString stringWithFormat:@"Compiled %@: %@\n",
            buildApplication?@"application":@"tool",outputPath]];
    else
        [self writeText:[NSString stringWithFormat:@"Compile error: %@\n",error.localizedDescription]];
}
- (void)appendOutput:(NSString *)text {
    [self.output.textStorage appendAttributedString:[[NSAttributedString alloc]initWithString:text
        attributes:@{NSForegroundColorAttributeName:[NSColor blackColor],
                     NSFontAttributeName:[NSFont userFixedPitchFontOfSize:13]}]];
    [self.output scrollRangeToVisible:NSMakeRange(self.output.string.length,0)];
}
- (void)writeText:(NSString *)text {
    [self performSelectorOnMainThread:@selector(appendOutput:) withObject:text waitUntilDone:NO];
}
- (void)clearText {[self performSelectorOnMainThread:@selector(clearOutput) withObject:nil waitUntilDone:NO];}
- (void)clearOutput {self.output.string=@"";}
- (void)collectInput:(NSMutableDictionary *)request {
    NSAlert *alert=[NSAlert new];alert.messageText=MB_GET(request,@"prompt")?:@"Input";
    NSTextField *field=[[NSTextField alloc]initWithFrame:NSMakeRect(0,0,320,24)];
    if([alert respondsToSelector:@selector(setAccessoryView:)])
        [alert performSelector:@selector(setAccessoryView:) withObject:field];
    [alert addButtonWithTitle:@"OK"];[alert addButtonWithTitle:@"Cancel"];
    MB_SET(request,@"value",[alert runModal]==NSAlertFirstButtonReturn?field.stringValue:@"");
}
- (NSString *)readInput:(NSString *)prompt {
    NSMutableDictionary *request=[@{@"prompt":prompt?:@"Input"}mutableCopy];
    [self performSelectorOnMainThread:@selector(collectInput:) withObject:request waitUntilDone:YES];
    return MB_GET(request,@"value")?:@"";
}
- (void)createBasicWindow:(NSDictionary *)spec {
    if(self.closingDocument)return;
    CGFloat width=[MB_GET(spec,@"width")doubleValue],height=[MB_GET(spec,@"height")doubleValue];
    NSWindow *existing=MB_GET(self.basicWindows,MB_GET(spec,@"id"));
    if(existing){for(NSNumber *viewID in [self.canvasViews.allKeys copy])if([(MBCanvasView *)MB_GET(self.canvasViews,viewID) window]==existing)[self.canvasViews removeObjectForKey:viewID];[existing orderOut:nil];[existing close];}
    NSRect frame=NSMakeRect(160,160,width,height);
    if([MB_GET(spec,@"positioned")boolValue])frame.origin=NSMakePoint([MB_GET(spec,@"x")doubleValue],[MB_GET(spec,@"y")doubleValue]);
    NSWindow *w=[[NSWindow alloc]initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    [w setReleasedWhenClosed:NO];
#if !defined(GNUSTEP)
    w.animationBehavior=NSWindowAnimationBehaviorNone;
#endif
    w.title=MB_GET(spec,@"title");NSTextField *label=[[NSTextField alloc]initWithFrame:NSMakeRect(20,height/2-15,width-40,30)];
    label.stringValue=w.title;label.alignment=NSTextAlignmentCenter;label.editable=NO;label.bezeled=NO;label.drawsBackground=NO;
    [w.contentView addSubview:label];MB_SET(self.basicWindows,MB_GET(spec,@"id"),w);[w makeKeyAndOrderFront:nil];
}
- (void)openWindowWithID:(NSInteger)windowID title:(NSString *)title width:(CGFloat)width height:(CGFloat)height x:(CGFloat)x y:(CGFloat)y {
    NSDictionary *spec=@{@"id":@(windowID),@"title":title,@"width":@(width),@"height":@(height),
        @"x":@(isnan(x)?0:x),@"y":@(isnan(y)?0:y),@"positioned":@(!isnan(x)&&!isnan(y))};
    [self performSelectorOnMainThread:@selector(createBasicWindow:) withObject:spec waitUntilDone:YES];
}
- (void)closeBasicWindow:(NSNumber *)windowID {
    NSWindow *window=MB_GET(self.basicWindows,windowID);if(window){
        for(NSNumber *viewID in [self.canvasViews.allKeys copy])if([(MBCanvasView *)MB_GET(self.canvasViews,viewID) window]==window)[self.canvasViews removeObjectForKey:viewID];
        [window orderOut:nil];[window close];[self.basicWindows removeObjectForKey:windowID];}
}
- (void)closeWindowWithID:(NSInteger)windowID {
    [self performSelectorOnMainThread:@selector(closeBasicWindow:) withObject:@(windowID) waitUntilDone:NO];
}
- (void)createCanvas:(NSDictionary *)spec {
    if(self.closingDocument)return;
    NSWindow *target=MB_GET(self.basicWindows,MB_GET(spec,@"windowID"));
    if(!target){[self appendOutput:[NSString stringWithFormat:@"Drawing error: window ID %@ not found.\n",MB_GET(spec,@"windowID")]];return;}
    MBCanvasView *canvas=[[MBCanvasView alloc]initWithFrame:NSMakeRect([MB_GET(spec,@"x")doubleValue],[MB_GET(spec,@"y")doubleValue],
        [MB_GET(spec,@"width")doubleValue],[MB_GET(spec,@"height")doubleValue])];
    [MB_GET(self.canvasViews,MB_GET(spec,@"viewID"))removeFromSuperview];
    canvas.autoresizingMask=NSViewMaxXMargin|NSViewMaxYMargin;
    [target.contentView addSubview:canvas];MB_SET(self.canvasViews,MB_GET(spec,@"viewID"),canvas);
    self.activeCanvasID=[MB_GET(spec,@"viewID")integerValue];
    target.acceptsMouseMovedEvents=YES;[target makeFirstResponder:canvas];
}
- (void)addViewWithID:(NSInteger)viewID toWindowID:(NSInteger)windowID x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
    NSDictionary *spec=@{@"viewID":@(viewID),@"windowID":@(windowID),@"x":@(x),@"y":@(y),@"width":@(width),@"height":@(height)};
    [self performSelectorOnMainThread:@selector(createCanvas:) withObject:spec waitUntilDone:YES];
}
- (void)applyDrawingCommand:(NSDictionary *)command {
    NSNumber *viewID=[MB_GET(command,@"viewID")integerValue]>=0?MB_GET(command,@"viewID"):@(self.activeCanvasID);
    MBCanvasView *canvas=MB_GET(self.canvasViews,viewID);
    if(!canvas){[self appendOutput:[NSString stringWithFormat:@"Drawing error: view ID %@ not found.\n",viewID]];return;}
    [canvas addDrawingCommand:command];
}
- (void)drawCommand:(NSString *)command onViewID:(NSInteger)viewID arguments:(NSArray *)arguments {
    if(self.closingDocument)return;
    NSDictionary *spec=@{@"type":command,@"viewID":@(viewID),@"args":arguments};
    [self performSelectorOnMainThread:@selector(applyDrawingCommand:) withObject:spec waitUntilDone:YES];
}
- (void)close {
    self.closingDocument=YES;
    self.interpreter.stopped=YES;
    [self.traceCondition lock];[self.traceCondition broadcast];[self.traceCondition unlock];
    for(NSWindow *window in self.basicWindows.allValues){[window orderOut:nil];[window close];}
    [self.canvasViews removeAllObjects];[self.basicWindows removeAllObjects];
    [super close];
}
- (void)playSoundOnMainThread:(NSString *)name {
    NSSound *sound=nil;
    if([[NSFileManager defaultManager]fileExistsAtPath:name])
        sound=[[NSSound alloc]initWithContentsOfFile:name byReference:YES];
    if(!sound)sound=[NSSound soundNamed:name];
    if(!sound){[self appendOutput:[NSString stringWithFormat:@"Sound error: '%@' was not found.\n",name]];return;}
    [self.playingSounds addObject:sound];[sound play];
}
- (void)playSound:(NSString *)name {
    [self performSelectorOnMainThread:@selector(playSoundOnMainThread:) withObject:name waitUntilDone:NO];
}
- (NSData *)toneDataAtFrequency:(double)frequency duration:(double)duration volume:(double)volume waveform:(NSInteger)waveform {
    uint32_t rate=22050,count=(uint32_t)MAX(1,duration*rate);uint32_t dataSize=count*2,fileSize=36+dataSize;
    NSMutableData *data=[NSMutableData dataWithLength:44+dataSize];uint8_t *b=data.mutableBytes;
#define W16(o,v) do{uint16_t q=(uint16_t)(v);b[o]=q&255;b[o+1]=(q>>8)&255;}while(0)
#define W32(o,v) do{uint32_t q=(uint32_t)(v);b[o]=q&255;b[o+1]=(q>>8)&255;b[o+2]=(q>>16)&255;b[o+3]=(q>>24)&255;}while(0)
    memcpy(b,"RIFF",4);W32(4,fileSize);memcpy(b+8,"WAVEfmt ",8);W32(16,16);W16(20,1);W16(22,1);W32(24,rate);W32(28,rate*2);W16(32,2);W16(34,16);memcpy(b+36,"data",4);W32(40,dataSize);
    int16_t *samples=(int16_t *)(b+44);double amp=MIN(1,MAX(0,volume))*30000;
    for(uint32_t i=0;i<count;i++){double phase=fmod(i*frequency/rate,1.0),sample;
        if(waveform==1)sample=phase<.5?1:-1;else if(waveform==2)sample=2*phase-1;else sample=sin(phase*2*M_PI);
        samples[i]=(int16_t)(sample*amp);}
    return data;
#undef W16
#undef W32
}
- (void)playToneSpec:(NSDictionary *)spec {
    NSSound *sound=[[NSSound alloc]initWithData:[self toneDataAtFrequency:[MB_GET(spec,@"frequency")doubleValue] duration:[MB_GET(spec,@"duration")doubleValue]
        volume:[MB_GET(spec,@"volume")doubleValue] waveform:[MB_GET(spec,@"waveform")integerValue]]];
    if(sound){[self.playingSounds addObject:sound];[sound play];}
}
- (void)playTone:(double)frequency duration:(double)duration volume:(double)volume voice:(NSInteger)voice waveform:(NSInteger)waveform {
    NSDictionary *spec=@{@"frequency":@(frequency),@"duration":@(duration),@"volume":@(volume),@"waveform":@(waveform)};
    [self performSelectorOnMainThread:@selector(playToneSpec:) withObject:spec waitUntilDone:NO];
}
- (void)speakOnMainThread:(NSString *)text {
#if !defined(GNUSTEP)
    NSTask *task=[NSTask new];task.launchPath=@"/usr/bin/say";task.arguments=@[text];@try{[task launch];}@catch(NSException *e){}
#else
    NSTask *task=[NSTask new];task.launchPath=@"/usr/bin/espeak";task.arguments=@[text];@try{[task launch];}@catch(NSException *e){}
#endif
}
- (void)speakText:(NSString *)text {[self performSelectorOnMainThread:@selector(speakOnMainThread:) withObject:text waitUntilDone:NO];}
- (void)stopSoundsOnMainThread {
    for(NSSound *sound in self.playingSounds)[sound stop];[self.playingSounds removeAllObjects];
}
- (void)stopSounds {
    [self performSelectorOnMainThread:@selector(stopSoundsOnMainThread) withObject:nil waitUntilDone:NO];
}
- (void)beep {
    [self performSelectorOnMainThread:@selector(performBeep) withObject:nil waitUntilDone:NO];
}
- (void)performBeep {NSBeep();}
- (id)inputValue:(NSString *)name argument:(NSInteger)argument {
    id value=@0;MBCanvasView *canvas=MB_GET(self.canvasViews,@(self.activeCanvasID));
    if([[name uppercaseString]isEqual:@"INKEY$"]){value=canvas.lastKey?:@"";canvas.lastKey=@"";}
    else if([[name uppercaseString]isEqual:@"MOUSE"]){if(argument==0)value=@(canvas.mousePressed?-1:0);else if(argument==1)value=@(canvas.mousePosition.x);else value=@(canvas.mousePosition.y);}
    return value;
}
- (void)basicMenuChosen:(NSMenuItem *)sender {
    self.lastMenu=sender.tag/100;self.lastMenuItem=sender.tag%100;
}
- (void)applyMenuSpec:(NSDictionary *)spec {
    NSInteger menu=[MB_GET(spec,@"menu")integerValue],item=[MB_GET(spec,@"item")integerValue],state=[MB_GET(spec,@"state")integerValue];NSString *title=MB_GET(spec,@"title");
    NSMenuItem *top=nil;for(NSMenuItem *candidate in NSApp.mainMenu.itemArray)if(candidate.tag==5000+menu){top=candidate;break;}
    if(!top){top=[[NSMenuItem alloc]initWithTitle:(item==0&&title.length?title:[NSString stringWithFormat:@"Menu %ld",(long)menu]) action:NULL keyEquivalent:@""];
        top.tag=5000+menu;top.submenu=[[NSMenu alloc]initWithTitle:top.title];[NSApp.mainMenu addItem:top];}
    if(item==0){if(title.length)top.title=title;top.enabled=state!=0;return;}
    NSMenuItem *entry=(NSMenuItem *)[top.submenu itemWithTag:menu*100+item];
    if(!entry){entry=[[NSMenuItem alloc]initWithTitle:(title.length?title:[NSString stringWithFormat:@"Item %ld",(long)item])
        action:@selector(basicMenuChosen:) keyEquivalent:@""];entry.target=self;entry.tag=menu*100+item;[top.submenu addItem:entry];}
    if(title.length)entry.title=title;entry.enabled=state!=0;entry.state=state==2?NSControlStateValueOn:NSControlStateValueOff;
}
- (void)setMenu:(NSInteger)menu item:(NSInteger)item state:(NSInteger)state title:(NSString *)title {
    NSDictionary *spec=@{@"menu":@(menu),@"item":@(item),@"state":@(state),@"title":title?:@""};
    [self performSelectorOnMainThread:@selector(applyMenuSpec:) withObject:spec waitUntilDone:YES];
}
- (NSInteger)menuValue:(NSInteger)which reset:(BOOL)reset {
    NSInteger value=which==0?self.lastMenu:self.lastMenuItem;if(reset&&which==0){self.lastMenu=0;self.lastMenuItem=0;}return value;
}
- (void)runProcess:(NSString *)path arguments:(NSArray<NSString *> *)arguments {
    NSTask *task=[NSTask new];task.launchPath=path;task.arguments=arguments;
    @try{[task launch];}@catch(NSException *e){[self writeText:[NSString stringWithFormat:@"Process error: %@\n",e.reason]];}
}
@end
