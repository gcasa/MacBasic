#import "MBDocument.h"

static NSColor *MBColor(id value) {
    NSString *s=[[value description] lowercaseString];
    NSDictionary *named=@{@"black":[NSColor blackColor],@"white":[NSColor whiteColor],
        @"red":[NSColor redColor],@"green":[NSColor greenColor],@"blue":[NSColor blueColor],
        @"cyan":[NSColor cyanColor],@"yellow":[NSColor yellowColor],@"gray":[NSColor grayColor],
        @"magenta":[NSColor magentaColor],@"orange":[NSColor orangeColor]};
    if(named[s])return named[s];
    if([s hasPrefix:@"#"]&&s.length==7){unsigned int rgb=0;[[NSScanner scannerWithString:[s substringFromIndex:1]]scanHexInt:&rgb];
        return [NSColor colorWithCalibratedRed:((rgb>>16)&255)/255.0 green:((rgb>>8)&255)/255.0 blue:(rgb&255)/255.0 alpha:1];}
    return [NSColor blackColor];
}

@interface MBCanvasView : NSView
@property NSMutableArray<NSDictionary *> *commands;
@property NSString *lastKey;
@property NSPoint mousePosition;
@property BOOL mousePressed;
- (void)addDrawingCommand:(NSDictionary *)command;
@end
@implementation MBCanvasView
- (instancetype)initWithFrame:(NSRect)frame {if((self=[super initWithFrame:frame]))_commands=[NSMutableArray array];return self;}
- (BOOL)isFlipped {return YES;}
- (BOOL)acceptsFirstResponder {return YES;}
- (void)keyDown:(NSEvent *)event {self.lastKey=event.characters?:@"";}
- (void)mouseDown:(NSEvent *)event {self.mousePressed=YES;self.mousePosition=[self convertPoint:event.locationInWindow fromView:nil];}
- (void)mouseUp:(NSEvent *)event {self.mousePressed=NO;self.mousePosition=[self convertPoint:event.locationInWindow fromView:nil];}
- (void)mouseMoved:(NSEvent *)event {self.mousePosition=[self convertPoint:event.locationInWindow fromView:nil];}
- (void)mouseDragged:(NSEvent *)event {[self mouseMoved:event];}
- (void)addDrawingCommand:(NSDictionary *)command {
    if([command[@"type"]isEqual:@"CLEAR"])[self.commands removeAllObjects];
    if([command[@"type"]isEqual:@"PAINT"]){
        NSArray *paint=command[@"args"];NSPoint point=NSMakePoint([paint[0]doubleValue],[paint[1]doubleValue]);
        for(NSInteger i=(NSInteger)self.commands.count-1;i>=0;i--){NSDictionary *old=self.commands[i];NSArray *a=old[@"args"];NSRect r=NSZeroRect;
            if(([@[@"RECT",@"OVAL"]containsObject:old[@"type"]])&&a.count>=4)r=NSMakeRect([a[0]doubleValue],[a[1]doubleValue],[a[2]doubleValue],[a[3]doubleValue]);
            if(NSPointInRect(point,r)){NSMutableArray *args=[a mutableCopy];while(args.count<6)[args addObject:@0];args[4]=paint.count>2?paint[2]:@"black";args[5]=@1;
                self.commands[i]=@{@"type":old[@"type"],@"args":args};[self setNeedsDisplay:YES];return;}}
    }
    [self.commands addObject:command];[self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor whiteColor]setFill];NSRectFill(self.bounds);
    for(NSDictionary *c in self.commands){NSString *type=c[@"type"];NSArray *a=c[@"args"];
        if([type isEqual:@"CLEAR"]){[(a.count?MBColor(a[0]):[NSColor whiteColor])setFill];NSRectFill(self.bounds);continue;}
        if([type isEqual:@"LINE"]&&a.count>=4){[(a.count>=5?MBColor(a[4]):[NSColor blackColor])setStroke];
            NSBezierPath *p=[NSBezierPath bezierPath];[p moveToPoint:NSMakePoint([a[0]doubleValue],[a[1]doubleValue])];
            [p lineToPoint:NSMakePoint([a[2]doubleValue],[a[3]doubleValue])];[p stroke];continue;}
        if(([type isEqual:@"RECT"]||[type isEqual:@"OVAL"])&&a.count>=4){
            NSRect r=NSMakeRect([a[0]doubleValue],[a[1]doubleValue],[a[2]doubleValue],[a[3]doubleValue]);
            NSBezierPath *p=[type isEqual:@"OVAL"]?[NSBezierPath bezierPathWithOvalInRect:r]:[NSBezierPath bezierPathWithRect:r];
            NSColor *color=a.count>=5?MBColor(a[4]):[NSColor blackColor];
            if(a.count>=6&&[a[5]boolValue]){[color setFill];[p fill];}else{[color setStroke];[p stroke];}continue;
        }
        if([type isEqual:@"TEXT"]&&a.count>=3){NSColor *color=a.count>=4?MBColor(a[3]):[NSColor blackColor];
            NSDictionary *attrs=@{NSForegroundColorAttributeName:color,NSFontAttributeName:[NSFont systemFontOfSize:14]};
            [[a[0]description]drawAtPoint:NSMakePoint([a[1]doubleValue],[a[2]doubleValue])withAttributes:attrs];}
        if([type isEqual:@"POLYGON"]&&a.count>=7){NSBezierPath *p=[NSBezierPath bezierPath];
            [p moveToPoint:NSMakePoint([a[0]doubleValue],[a[1]doubleValue])];
            for(NSUInteger i=2;i+1<a.count-1;i+=2)[p lineToPoint:NSMakePoint([a[i]doubleValue],[a[i+1]doubleValue])];
            [p closePath];[MBColor(a.lastObject)setFill];[p fill];}
    }
}
@end

@interface MBDocument ()
@property NSTextView *editor;
@property NSTextView *output;
@property MBInterpreter *interpreter;
@property NSMutableArray<NSWindow *> *basicWindows;
@property NSMutableDictionary<NSString *, MBCanvasView *> *canvasViews;
@property NSString *activeCanvasName;
@property NSMutableArray<NSSound *> *playingSounds;
@property NSInteger lastMenu;
@property NSInteger lastMenuItem;
@property NSString *sourceBeforeWindow;
@end

@implementation MBDocument
- (instancetype)init {
    if ((self=[super init])) {
        _basicWindows=[NSMutableArray array];
        _canvasViews=[NSMutableDictionary dictionary];
        _playingSounds=[NSMutableArray array];
        _sourceBeforeWindow=@"' Welcome to MacBasic\n"
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
            "' Create a window and draw into a named canvas view\n"
            "WINDOW OPEN \"MacBasic Drawing\", 640, 420, 160, 140\n"
            "VIEW ADD \"canvas\", \"MacBasic Drawing\", 20, 20, 600, 360\n"
            "CLEAR \"canvas\", \"#F5F3FF\"\n"
            "DRAW RECT \"canvas\", 30, 30, 540, 300, \"#4F46E5\", 0\n"
            "DRAW OVAL \"canvas\", 70, 80, 160, 160, \"#06B6D4\", 1\n"
            "DRAW OVAL \"canvas\", 370, 80, 160, 160, \"#EC4899\", 1\n"
            "DRAW LINE \"canvas\", 230, 160, 370, 160, \"#111827\"\n"
            "DRAW TEXT \"canvas\", \"MacBasic Graphics\", 205, 280, \"#312E81\"\n";
    }
    return self;
}
- (NSButton *)button:(NSString *)title action:(SEL)action x:(CGFloat)x {
    NSButton *b=[[NSButton alloc]initWithFrame:NSMakeRect(x,8,78,30)];
    b.title=title;b.target=self;b.action=action;
#if !defined(GNUSTEP)
    b.bezelStyle=NSBezelStyleRounded;
#endif
    return b;
}
- (NSScrollView *)scrollWithText:(NSTextView **)text frame:(NSRect)frame editable:(BOOL)editable {
    NSScrollView *s=[[NSScrollView alloc]initWithFrame:frame];s.hasVerticalScroller=YES;s.hasHorizontalScroller=YES;
    NSTextView *v=[[NSTextView alloc]initWithFrame:s.contentView.bounds];v.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    v.editable=editable;v.richText=NO;v.font=[NSFont userFixedPitchFontOfSize:13];v.delegate=editable?(id)self:nil;
    v.drawsBackground=YES;
    if(editable){
        v.backgroundColor=[NSColor colorWithCalibratedRed:0.95 green:0.93 blue:0.86 alpha:1.0];
        v.textColor=[NSColor blackColor];
    }else{
        v.backgroundColor=[NSColor whiteColor];v.textColor=[NSColor blackColor];
    }
    s.documentView=v;*text=v;return s;
}
- (void)makeWindowControllers {
    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(100,100,900,650)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    window.minSize=NSMakeSize(600,420);
    NSTextView *editorText=nil,*outputText=nil;
    NSScrollView *editor=[self scrollWithText:&editorText frame:NSMakeRect(10,205,880,435) editable:YES];
    NSScrollView *output=[self scrollWithText:&outputText frame:NSMakeRect(10,45,880,150) editable:NO];
    self.editor=editorText;self.output=outputText;
    editor.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    output.autoresizingMask=NSViewWidthSizable|NSViewMaxYMargin;
    NSView *content=window.contentView;[content addSubview:editor];[content addSubview:output];
    [content addSubview:[self button:@"Run" action:@selector(run:) x:10]];
    [content addSubview:[self button:@"Stop" action:@selector(stop:) x:96]];
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
    [self colorPattern:@"\\b(SUB|END\\s+SUB|FUNCTION|END\\s+FUNCTION|RETURN|IF|THEN|ELSE|ELSEIF|END\\s+IF|ENDIF|FOR|TO|STEP|NEXT|WHILE|WEND|AND|OR|XOR|EQV|IMP|MOD|NOT|PRINT|USING|INPUT|WINDOW|OPEN|CLOSE|VIEW|ADD|DRAW|LINE|RECT|OVAL|CIRCLE|PSET|PRESET|AREA|AREAFILL|PAINT|COLOR|TEXT|CLEAR|PROCESS|RUN|SLEEP|DATA|READ|RESTORE|SOUND|WAVE|SAY|PLAY|STOP|BEEP|DIM|ERASE|OPTION|BASE|GOTO|GOSUB|ON|ERROR|RESUME|MENU|MOUSE|TIMER|FIELD|GET|PUT|WRITE|LSET|RSET|RANDOMIZE|POKE|POKEW|POKEL|WAIT|SWAP|KILL|NAME|CHDIR|FILES|CHAIN|LIST|CLS|REM)\\b"
                 color:[NSColor colorWithCalibratedRed:0.16 green:0.25 blue:0.67 alpha:1] options:ci];
    [self colorPattern:@"\\b\\d+(?:\\.\\d+)?\\b"
                 color:[NSColor colorWithCalibratedRed:0.55 green:0.20 blue:0.65 alpha:1] options:0];
    [self colorPattern:@"(?m)^[ \\t]*[A-Za-z_][A-Za-z0-9_$]*:"
                 color:[NSColor colorWithCalibratedRed:0.65 green:0.32 blue:0.05 alpha:1] options:0];
    [self colorPattern:@"\\b[A-Za-z_][A-Za-z0-9_$]*(?=\\s*\\()"
                 color:[NSColor colorWithCalibratedRed:0.05 green:0.46 blue:0.40 alpha:1] options:0];
    [self colorPattern:@"\"(?:\"\"|[^\"])*\""
                 color:[NSColor colorWithCalibratedRed:0.70 green:0.12 blue:0.18 alpha:1] options:0];
    [self colorPattern:@"(?im)(?:'[^\r\n]*|\\bREM\\b[^\r\n]*)"
                 color:[NSColor colorWithCalibratedRed:0.35 green:0.45 blue:0.35 alpha:1] options:0];
    [storage endEditing];
}
- (void)run:(id)sender {
    self.output.string=@"";self.interpreter=[[MBInterpreter alloc]initWithPlatform:self];
    NSString *source=[self.editor.string copy];
    [NSThread detachNewThreadSelector:@selector(runSourceInBackground:) toTarget:self withObject:source];
}
- (void)runSourceInBackground:(NSString *)source {
    @autoreleasepool {
        NSError *error=nil;BOOL ok=[self.interpreter runSource:source error:&error];
        if(!ok&&error)[self writeText:[NSString stringWithFormat:@"Error: %@\n",error.localizedDescription]];
        else if(!self.interpreter.stopped)[self writeText:@"Program finished.\n"];
    }
}
- (void)stop:(id)sender {self.interpreter.stopped=YES;[self writeText:@"Program stopped.\n"];}
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
    NSAlert *alert=[NSAlert new];alert.messageText=request[@"prompt"]?:@"Input";
    NSTextField *field=[[NSTextField alloc]initWithFrame:NSMakeRect(0,0,320,24)];alert.accessoryView=field;
    [alert addButtonWithTitle:@"OK"];[alert addButtonWithTitle:@"Cancel"];
    request[@"value"]=[alert runModal]==NSAlertFirstButtonReturn?field.stringValue:@"";
}
- (NSString *)readInput:(NSString *)prompt {
    NSMutableDictionary *request=[@{@"prompt":prompt?:@"Input"}mutableCopy];
    [self performSelectorOnMainThread:@selector(collectInput:) withObject:request waitUntilDone:YES];
    return request[@"value"]?:@"";
}
- (void)createBasicWindow:(NSDictionary *)spec {
    CGFloat width=[spec[@"width"]doubleValue],height=[spec[@"height"]doubleValue];
    NSRect frame=NSMakeRect(160,160,width,height);
    if([spec[@"positioned"]boolValue])frame.origin=NSMakePoint([spec[@"x"]doubleValue],[spec[@"y"]doubleValue]);
    NSWindow *w=[[NSWindow alloc]initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    w.title=spec[@"title"];NSTextField *label=[[NSTextField alloc]initWithFrame:NSMakeRect(20,height/2-15,width-40,30)];
    label.stringValue=w.title;label.alignment=NSTextAlignmentCenter;label.editable=NO;label.bezeled=NO;label.drawsBackground=NO;
    [w.contentView addSubview:label];[self.basicWindows addObject:w];[w makeKeyAndOrderFront:nil];
}
- (void)openWindowWithTitle:(NSString *)title width:(CGFloat)width height:(CGFloat)height x:(CGFloat)x y:(CGFloat)y {
    NSDictionary *spec=@{@"title":title,@"width":@(width),@"height":@(height),
        @"x":@(isnan(x)?0:x),@"y":@(isnan(y)?0:y),@"positioned":@(!isnan(x)&&!isnan(y))};
    [self performSelectorOnMainThread:@selector(createBasicWindow:) withObject:spec waitUntilDone:YES];
}
- (void)closeBasicWindow:(NSString *)title {
    for(NSWindow *w in [self.basicWindows copy])if([w.title isEqual:title]){[w close];[self.basicWindows removeObject:w];}
}
- (void)closeWindowWithTitle:(NSString *)title {
    [self performSelectorOnMainThread:@selector(closeBasicWindow:) withObject:title waitUntilDone:NO];
}
- (void)createCanvas:(NSDictionary *)spec {
    NSWindow *target=nil;for(NSWindow *w in self.basicWindows)if([w.title isEqual:spec[@"window"]]){target=w;break;}
    if(!target){[self appendOutput:[NSString stringWithFormat:@"Drawing error: window '%@' not found.\n",spec[@"window"]]];return;}
    MBCanvasView *canvas=[[MBCanvasView alloc]initWithFrame:NSMakeRect([spec[@"x"]doubleValue],[spec[@"y"]doubleValue],
        [spec[@"width"]doubleValue],[spec[@"height"]doubleValue])];
    canvas.autoresizingMask=NSViewMaxXMargin|NSViewMaxYMargin;
    [target.contentView addSubview:canvas];self.canvasViews[[spec[@"name"]uppercaseString]]=canvas;
    self.activeCanvasName=[spec[@"name"]uppercaseString];
    target.acceptsMouseMovedEvents=YES;[target makeFirstResponder:canvas];
}
- (void)addViewNamed:(NSString *)name toWindow:(NSString *)window x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height {
    NSDictionary *spec=@{@"name":name,@"window":window,@"x":@(x),@"y":@(y),@"width":@(width),@"height":@(height)};
    [self performSelectorOnMainThread:@selector(createCanvas:) withObject:spec waitUntilDone:YES];
}
- (void)applyDrawingCommand:(NSDictionary *)command {
    NSString *name=[command[@"view"]length]?[command[@"view"]uppercaseString]:self.activeCanvasName;
    MBCanvasView *canvas=self.canvasViews[name];
    if(!canvas){[self appendOutput:[NSString stringWithFormat:@"Drawing error: view '%@' not found.\n",command[@"view"]]];return;}
    [canvas addDrawingCommand:command];
}
- (void)drawCommand:(NSString *)command onView:(NSString *)view arguments:(NSArray *)arguments {
    NSDictionary *spec=@{@"type":command,@"view":view,@"args":arguments};
    [self performSelectorOnMainThread:@selector(applyDrawingCommand:) withObject:spec waitUntilDone:YES];
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
    NSSound *sound=[[NSSound alloc]initWithData:[self toneDataAtFrequency:[spec[@"frequency"]doubleValue] duration:[spec[@"duration"]doubleValue]
        volume:[spec[@"volume"]doubleValue] waveform:[spec[@"waveform"]integerValue]]];
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
    __block id value=@0;MBCanvasView *canvas=self.canvasViews[self.activeCanvasName];
    if([[name uppercaseString]isEqual:@"INKEY$"]){value=canvas.lastKey?:@"";canvas.lastKey=@"";}
    else if([[name uppercaseString]isEqual:@"MOUSE"]){if(argument==0)value=@(canvas.mousePressed?-1:0);else if(argument==1)value=@(canvas.mousePosition.x);else value=@(canvas.mousePosition.y);}
    return value;
}
- (void)basicMenuChosen:(NSMenuItem *)sender {
    self.lastMenu=sender.tag/100;self.lastMenuItem=sender.tag%100;
}
- (void)applyMenuSpec:(NSDictionary *)spec {
    NSInteger menu=[spec[@"menu"]integerValue],item=[spec[@"item"]integerValue],state=[spec[@"state"]integerValue];NSString *title=spec[@"title"];
    NSMenuItem *top=nil;for(NSMenuItem *candidate in NSApp.mainMenu.itemArray)if(candidate.tag==5000+menu){top=candidate;break;}
    if(!top){top=[[NSMenuItem alloc]initWithTitle:(item==0&&title.length?title:[NSString stringWithFormat:@"Menu %ld",(long)menu]) action:NULL keyEquivalent:@""];
        top.tag=5000+menu;top.submenu=[[NSMenu alloc]initWithTitle:top.title];[NSApp.mainMenu addItem:top];}
    if(item==0){if(title.length)top.title=title;top.enabled=state!=0;return;}
    NSMenuItem *entry=[top.submenu itemWithTag:menu*100+item];
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
