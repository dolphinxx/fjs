#import "FlutterJsPlugin.h"
#if __has_include(<fjs/fjs-Swift.h>)
#import <fjs/fjs-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "fjs-Swift.h"
#endif

@implementation FlutterJsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterJsPlugin registerWithRegistrar:registrar];
}
@end
