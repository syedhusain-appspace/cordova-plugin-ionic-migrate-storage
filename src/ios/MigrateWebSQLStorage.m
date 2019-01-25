#import "MigrateWebSQLStorage.h"
#import "FMDB.h"

#define TAG @"\nMigrateWebSQL"

#define ORIG_DIRPATH @"WebKit/LocalStorage/"
#define TARGET_DIRPATH @"WebKit/WebsiteData/WebSQL/"

#define UI_WEBVIEW_PROTOCOL_DIR @"file__0"
#define WK_WEBVIEW_PROTOCOL_DIR @"http_localhost_8080"

@implementation MigrateWebSQLStorage

- (BOOL)deleteFile:(NSString *)path
{
    // NSLog(@"%@ deleteFile(path: %@ )", TAG, path);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Bail out if source file does not exist
    if (![fileManager fileExistsAtPath:path]) {
        // NSLog(@"%@ Source file does not exist", TAG);
        return NO;
    }
    
    BOOL res = [fileManager removeItemAtPath:path error:nil];
    
    // NSLog(@"%@ end deleteFile(path: %@ ); success: %@", TAG, path, res ? @"YES" : @"NO");
    
    return res;
}

- (BOOL)moveFile:(NSString*)src to:(NSString*)dest
{
    // NSLog(@"%@ moveFile(src: %@ , dest: %@ )", TAG, src, dest);
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    // Bail out if source file does not exist
    if (![fileManager fileExistsAtPath:src]) {
        // NSLog(@"%@ source file does not exist: %@", TAG, src);
        return NO;
    }
    
    // Bail out if dest file exists
     if ([fileManager fileExistsAtPath:dest]) {
        // NSLog(@"%@ destination file already exists: %@", TAG, dest);
       return NO;
     }
    
    // create path to destination
    if (![fileManager createDirectoryAtPath:[dest stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil]) {
        return NO;
    }
    
    BOOL res = [fileManager moveItemAtPath:src toPath:dest error:nil];
    
    // NSLog(@"%@ end moveFile(src: %@ , dest: %@ ); success: %@", TAG, src, dest, res ? @"YES" : @"NO");
    
    return res;
}

- (BOOL)changeProtocolEntriesinReferenceDB:(NSString *)path from:(NSString *)srcProtocol to:(NSString *)targetProtocol
{
    // NSLog(@"%@ changeProtocolEntriesinReferenceDB()", TAG);
    
    FMDatabase *db = [FMDatabase databaseWithPath:path];
    
    // Can't do anything, just let this fail and let WkWebview create its own DB! :(
    if(![db open])
    {
        
        // NSLog(@"%@ dbOpen error: %@ ; exiting..", TAG, [db lastErrorMessage]);
        return NO;
    }
    
    BOOL success = [db executeUpdate:@"UPDATE Databases SET origin = ? WHERE origin = ?", WK_WEBVIEW_PROTOCOL_DIR, UI_WEBVIEW_PROTOCOL_DIR];

    if (!success)
    {
        // NSLog(@"%@ executeUpdate error = %@", TAG, [db lastErrorMessage]);
    }

    [db close];
    
    // NSLog(@"%@ end changeProtocolEntriesinReferenceDB()", TAG);
    
    return success;
}

- (BOOL)migrateWebSQL
{
    // NSLog(@"%@ migrateWebSQL()", TAG);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *appLibraryDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *uiWebViewRootPath = [appLibraryDir stringByAppendingPathComponent:ORIG_DIRPATH];
    NSString *wkWebViewRootPath = [appLibraryDir stringByAppendingPathComponent:TARGET_DIRPATH];
    
    //
    // Copy {appLibrary}/WebKit/LocalStorage/Databases.db to {appLibrary}/WebKit/WebsiteData/WebSQL/Databases.db
    //
    
    // "Databases.db" contains an "index" of all the WebSQL databases that the app is using
    NSString *uiWebViewRefDBPath = [uiWebViewRootPath stringByAppendingPathComponent:@"Databases.db"];
    NSString *wkWebViewRefDBPath = [wkWebViewRootPath stringByAppendingPathComponent:@"Databases.db"];
    
    // Exit away if the source file does not exist
    if(![fileManager fileExistsAtPath:uiWebViewRefDBPath])
    {
        // NSLog(@"%@ source path not found: %@ ; exiting..", TAG, uiWebViewRefDBPath);
        return NO;
    }
    
    // TODO Check if target file exists or not?
    
    // Before copying, open Databases.db and change the reference from `file__0` to `localhost_http_8080`, so WkWebView will understand this
    if (![self changeProtocolEntriesinReferenceDB:uiWebViewRefDBPath from:UI_WEBVIEW_PROTOCOL_DIR to:WK_WEBVIEW_PROTOCOL_DIR])
    {
        // NSLog(@"%@ could not perform needed update; exiting..", TAG);
        return NO;
    }
    

    // NOTE: There are `-shm` and `-wal` files in this directory. We are not copying them, because we closed the DB in `changeProtocolEntriesinReferenceDB`
    if(![self moveFile:uiWebViewRefDBPath to:wkWebViewRefDBPath])
    {
        // NSLog(@"%@ could not move Databases.db; exiting..", TAG);
        return NO;
    }
    
    //
    // Copy
    //  {appLibrary}/WebKit/LocalStorage/file__0/*
    // to
    //  {appLibrary}/WebKit/WebsiteData/WebSQL/http_localhost_8080/*
    //
    
    // This dir contains all the WebSQL Databases that the cordova app
    NSString *uiWebViewDBFileDir = [uiWebViewRootPath stringByAppendingPathComponent:UI_WEBVIEW_PROTOCOL_DIR];
    
    
    // The target dir that should contain all the databases from `uiWebViewDBFileDir`
    NSString *wkWebViewDBFileDir = [wkWebViewRootPath stringByAppendingPathComponent:WK_WEBVIEW_PROTOCOL_DIR];
    
    NSArray *fileList = [fileManager contentsOfDirectoryAtPath:uiWebViewDBFileDir error:nil];
    
    // Exit if no databases were found
    // This should never happen, because if no databases were found, we would not have found the `Databases.db` file!
    if ([fileList count] == 0) return NO;
    
    BOOL success;
    
    for (NSString *fileName in fileList) {
        NSString *originalFilePath = [uiWebViewDBFileDir stringByAppendingPathComponent:fileName];
        NSString *targetFilePath = [wkWebViewDBFileDir stringByAppendingPathComponent:fileName];
        
        success = [self moveFile:originalFilePath to:targetFilePath];
    }
    
    if(!success)
    {
        // NSLog(@"%@ could not move one of the databases in %@ ; exiting..", TAG, uiWebViewDBFileDir);
        return NO;
    }
    
    // NSLog(@"%@ end migrateWebSQL()", TAG);
    return YES;
}

- (void)pluginInitialize
{
    // NSLog(@"%@ pluginInitialize()", TAG);
    
    if([self migrateWebSQL])
    {
        // if all successfully migrated, do some cleanup!
        NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString* originalFolder = [appLibraryFolder stringByAppendingPathComponent:ORIG_DIRPATH];
        BOOL res = [self deleteFile:originalFolder];
        
        // NSLog(@"%@ final deletion success: %@", TAG, res ? @"YES" : @"NO");
    }
    
    // NSLog(@"%@ end pluginInitialize()", TAG);
}

@end

