#import <AppKit/AppKit.h>
#import "MBInterpreter.h"

@class MBCanvasView, MBGutterView;

@interface MBDocument : NSDocument <MBPlatform, NSTextViewDelegate, NSToolbarDelegate> {
    NSTextView *_editor;
    NSTextView *_output;
    MBInterpreter *_interpreter;
    NSMutableDictionary *_basicWindows;
    NSMutableDictionary *_canvasViews;
    NSInteger _activeCanvasID;
    NSMutableArray *_playingSounds;
    NSInteger _lastMenu;
    NSInteger _lastMenuItem;
    NSString *_sourceBeforeWindow;
    BOOL _programRunning;
    BOOL _tracePaused;
    NSUInteger _pendingTraceSteps;
    NSCondition *_traceCondition;
    BOOL _closingDocument;
    BOOL _compiledMode;
    NSMutableIndexSet *_breakpoints;
    NSDictionary *_debugVariables;
    MBGutterView *_gutter;
    NSTextField *_variableInspector;
    NSTextView *_traceVariables;
    NSScrollView *_traceSidebar;
}
- (void)compileDocument:(id)sender;
- (void)runCompiledSource:(NSString *)source;
@end
