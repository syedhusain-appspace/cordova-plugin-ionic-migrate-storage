#import "MigrateStorage.h"
#import "FMDB.h"

#define TAG @"\MigrateStorage"

// TODO Make these paths simpler to deal with? We could embded the full paths in these strings if we want to...
#define ORIG_DIRPATH @"WebKit/LocalStorage/"
#define TARGET_DIRPATH @"WebKit/WebsiteData/"

#define ORIG_WEBSQL_DIRPATH @"WebKit/LocalStorage/"
#define TARGET_WEBSQL_DIRPATH @"WebKit/WebsiteData/WebSQL/"

#define ORIG_LS_DIRPATH @"WebKit/LocalStorage/"
#define ORIG_LS_CACHE_DIRPATH @"Caches/"
#define TARGET_LS_DIRPATH @"WebKit/WebsiteData/LocalStorage/"

#define ORIG_IDB_DIRPATH @"WebKit/LocalStorage/___IndexedDB/"
#define TARGET_IDB_DIRPATH @"WebKit/WebsiteData/IndexedDB/"

#define UI_WEBVIEW_PROTOCOL_DIR @"file__0"
#define WK_WEBVIEW_PROTOCOL_DIR @"http_localhost_8080"

@implementation MigrateStorage

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
    
    NSString *uiWebViewRootPath = [appLibraryDir stringByAppendingPathComponent:ORIG_WEBSQL_DIRPATH];
    NSString *wkWebViewRootPath = [appLibraryDir stringByAppendingPathComponent:TARGET_WEBSQL_DIRPATH];
    
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
    
    // NSLog(@"%@ end migrateWebSQL() with success: %@", TAG, success ? @"YES" : @"NO");
    return YES;
}

- (BOOL) migrateLocalStorage
{
    // NSLog(@"%@ migrateLocalStorage()", TAG);
    
    BOOL success;
    
    NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString* originalLSFileName = [UI_WEBVIEW_PROTOCOL_DIR stringByAppendingString:@".localstorage"];
    NSString* targetLSFileName = [WK_WEBVIEW_PROTOCOL_DIR stringByAppendingString:@".localstorage"];
    
    NSString* originalLSFilePath = [[appLibraryFolder stringByAppendingPathComponent:ORIG_LS_DIRPATH] stringByAppendingPathComponent:originalLSFileName];
    NSString* originalLSCachePath = [[appLibraryFolder stringByAppendingPathComponent:ORIG_LS_CACHE_DIRPATH] stringByAppendingPathComponent:originalLSFileName];
    
    // Use the file in the cache if not found in original path
    NSString* original = [[NSFileManager defaultManager] fileExistsAtPath:originalLSFilePath] ? originalLSFilePath : originalLSCachePath;
    NSString* target = [[appLibraryFolder stringByAppendingPathComponent:TARGET_LS_DIRPATH] stringByAppendingPathComponent:targetLSFileName];

    // NSLog(@"%@ LS original %@", TAG, original);
    // NSLog(@"%@ LS target %@", TAG, target);
    
    // Only copy data if no existing localstorage data exists yet for wkwebview
    if (![[NSFileManager defaultManager] fileExistsAtPath:target]) {
        // NSLog(@"%@ No existing localstorage data found for WKWebView. Migrating data from UIWebView", TAG);
        BOOL success1 = [self moveFile:original to:target];
        BOOL success2 = [self moveFile:[original stringByAppendingString:@"-shm"] to:[target stringByAppendingString:@"-shm"]];
        BOOL success3 = [self moveFile:[original stringByAppendingString:@"-wal"] to:[target stringByAppendingString:@"-wal"]];
        // NSLog(@"%@ copy status %d %d %d", TAG, success1, success2, success3);
        success = success1 && success2 && success3;
    }
    else {
        // NSLog(@"%@ found LS data. not migrating", TAG);
        success = NO;
    }
    
    // NSLog(@"%@ end migrateLocalStorage() with success: %@", TAG, success ? @"YES": @"NO");
    
    return success;
}

- (BOOL) migrateIndexedDB
{
    // NSLog(@"%@ migrateIndexedDB()", TAG);
    
    NSString* appLibraryFolder = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString* original = [[appLibraryFolder stringByAppendingPathComponent:ORIG_IDB_DIRPATH] stringByAppendingPathComponent:UI_WEBVIEW_PROTOCOL_DIR];
    NSString* target = [[appLibraryFolder stringByAppendingPathComponent:TARGET_IDB_DIRPATH] stringByAppendingPathComponent:WK_WEBVIEW_PROTOCOL_DIR];
    
    // NSLog(@"%@ IDB original %@", TAG, original);
    // NSLog(@"%@ IDB target %@", TAG, target);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:target]) {
        // NSLog(@"%@ No existing IDB data found for WKWebView. Migrating data from UIWebView", TAG);
        BOOL success = [self moveFile:original to:target];
        // NSLog(@"%@ copy status %d", TAG, success);
        return success;
    }
    else {
        // NSLog(@"%@ found IDB data. Not migrating", TAG);
        return NO;
    }
}


- (void)pluginInitialize
{
    // NSLog(@"%@ pluginInitialize()", TAG);
    
    [self migrateWebSQL];
    [self migrateLocalStorage];
    [self migrateIndexedDB];
    
    // NSLog(@"%@ end pluginInitialize()", TAG);
}

@end

