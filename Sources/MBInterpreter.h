#import <Foundation/Foundation.h>

@protocol MBPlatform <NSObject>
- (void)writeText:(NSString *)text;
- (void)clearText;
- (NSString *)readInput:(NSString *)prompt;
- (void)openWindowWithID:(NSInteger)windowID title:(NSString *)title
                   width:(CGFloat)width height:(CGFloat)height x:(CGFloat)x y:(CGFloat)y;
- (void)closeWindowWithID:(NSInteger)windowID;
- (void)addViewWithID:(NSInteger)viewID toWindowID:(NSInteger)windowID
                    x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height;
- (void)drawCommand:(NSString *)command onViewID:(NSInteger)viewID arguments:(NSArray *)arguments;
- (void)playSound:(NSString *)name;
- (void)playTone:(double)frequency duration:(double)duration volume:(double)volume voice:(NSInteger)voice waveform:(NSInteger)waveform;
- (void)speakText:(NSString *)text;
- (void)stopSounds;
- (void)beep;
- (id)inputValue:(NSString *)name argument:(NSInteger)argument;
- (void)setMenu:(NSInteger)menu item:(NSInteger)item state:(NSInteger)state title:(NSString *)title;
- (NSInteger)menuValue:(NSInteger)which reset:(BOOL)reset;
- (void)runProcess:(NSString *)path arguments:(NSArray<NSString *> *)arguments;
@end

@interface MBInterpreter : NSObject
@property (atomic) BOOL stopped;
- (instancetype)initWithPlatform:(id<MBPlatform>)platform;
- (BOOL)runSource:(NSString *)source error:(NSError **)error;
@end
