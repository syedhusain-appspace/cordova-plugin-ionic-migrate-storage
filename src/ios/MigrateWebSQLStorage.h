#import <Cordova/CDVPlugin.h>

@interface MigrateWebSQLStorage : CDVPlugin {}

- (BOOL)moveFile:(NSString*)src to:(NSString*)dest;
- (void)migrateWebSQL;
- (void)pluginInitialize;

@end
