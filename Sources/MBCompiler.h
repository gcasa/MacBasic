#import <Foundation/Foundation.h>

BOOL MBCompileSource(NSString *source, NSString *outputPath, NSError **error);
BOOL MBCompileApplication(NSString *source, NSString *outputPath, NSString *iconPath, NSError **error);
NSString *MBEmbeddedSource(NSError **error);
