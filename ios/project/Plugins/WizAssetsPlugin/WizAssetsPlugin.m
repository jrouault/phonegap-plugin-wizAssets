/* WizAssetsPlugin - IOS side of the bridge to WizAssetsPlugin JavaScript for PhoneGap
 *
 * @author Ally Ogilvie
 * @copyright WizCorp Inc. [ Incorporated Wizards ] 2011
 * @file WizAssetsPlugin.m for PhoneGap
 *
 *
 */

#import "WizAssetsPlugin.h"
#import "WizDebugLog.h"

NSString *const assetsVersionKey = @"plugins.wizassets.assetsversion";
NSString *const assetsErrorKey = @"plugins.wizassets.errors";

@implementation WizAssetsPlugin

@synthesize queue;
@synthesize isProcessing;

- (void)pluginInitialize {
    [super pluginInitialize];

    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
        queue = [[SimpleQueue alloc] init];
        isProcessing = false;
    }
}

- (void)dealloc {
    [queue release];
    [super dealloc];
}

/*
 *
 * Methods
 *
 */

- (void)backgroundDownloadWrapper:(NSDictionary *)args {
    // Create a pool
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    [self backgroundDownload:[args objectForKey:@"command"] fullDir:[args objectForKey:@"fullDir"] filePath:[args objectForKey:@"filePath"]];

    // clean up
    [pool release];
}

- (void)backgroundDownload:(CDVInvokedUrlCommand*)command fullDir:(NSString *)fullDir filePath:(NSString *)filePath {
    // url
    NSString *urlString = [command.arguments objectAtIndex:0];

    // holds our return data
    NSString* returnString;

    if (urlString) {

        NSFileManager *filemgr;
        filemgr =[NSFileManager defaultManager];


        NSURL  *url = [NSURL URLWithString:urlString];

        WizLog(@"downloading ---------------- >%@", url);

        NSError *error = nil;
        NSData *urlData = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:&error];

        if (error) {
            returnString = [NSString stringWithFormat:@"error - %@", error];
        } else if (urlData) {
            // Check if we didn't received a 401
            // TODO: We might want to find another solution to check for this kind of error, and check other possible errors
            NSString *dataContent = [[NSString alloc] initWithBytes:[urlData bytes] length:12 encoding:NSUTF8StringEncoding];
            bool urlUnauthorized = [dataContent isEqualToString:@"Unauthorized"];
            [dataContent release];

            if (urlUnauthorized) {
                returnString = @"error - url unauthorized";
            } else if ([filemgr createDirectoryAtPath:fullDir withIntermediateDirectories:YES attributes:nil error: NULL] == YES) {
                // Success to create directory download data to temp and move to library/cache when complete
                [urlData writeToFile:filePath atomically:YES];

                returnString = filePath;
            } else {
                // Fail to download

                returnString = @"error - failed download";
            }
        } else {
            WizLog(@"ERROR: URL no exist");
            returnString = @"error - bad url";
        }
    } else {
        returnString = @"error - no urlString";
    }

    NSArray* callbackData = [[NSArray alloc] initWithObjects:command.callbackId, returnString, nil];


    // download complete pass back confirmation to JS
    [self performSelectorOnMainThread:@selector(completeDownload:) withObject:callbackData waitUntilDone:YES];

    [callbackData release];
}

/*
 * downloadFile - download from an HTTP to app folder
 */
- (void)sendCallback:(NSArray*)callbackdata
{
    // faked the return string for now
    NSString* callbackId = [callbackdata objectAtIndex:0];
    NSString* returnString = [callbackdata objectAtIndex:1];

    WizLog(@"Path: %@", returnString);
    WizLog(@"callbackId ----------> : %@", callbackId);

    if ([returnString rangeOfString:@"error"].location == NSNotFound) {
        // no error
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:returnString];
        [self writeJavascript: [pluginResult toSuccessCallbackString:callbackId]];

    } else {
        // found error
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:returnString];
        [self writeJavascript: [pluginResult toErrorCallbackString:callbackId]];

    }
}

- (void)completeDownload:(NSArray*)callbackdata
{
    [self sendCallback:callbackdata];

    if (queue) {
        NSDictionary *args = [queue dequeue];
        if (args) {
            [self performSelectorInBackground:@selector(backgroundDownloadWrapper:) withObject:args];
        } else {
            isProcessing = false;
        }
    }
}


/*
 * downloadFile - download from an HTTP to app folder
 */
- (void)downloadFile:(CDVInvokedUrlCommand*)command
{
    WizLog(@"[WizAssetsPlugin] ******* downloadFile-> " );

    int count = [command.arguments count];
    if(count > 0) {
        // dir store path and name
        NSString *savePath = [command.arguments objectAtIndex:1];
        // split storePath
        NSMutableArray *pathSpliter = [[NSMutableArray alloc] initWithArray:[savePath componentsSeparatedByString:@"/"] copyItems:YES];
        NSString *fileName = [pathSpliter lastObject];
        // remove last object (filename)
        [pathSpliter removeLastObject];
        // join all dir(s)
        NSString *storePath = [pathSpliter componentsJoinedByString:@"/"];

        // path to library caches
        NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);

        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *gameDir = [[[NSBundle mainBundle] infoDictionary]   objectForKey:@"CFBundleName"];
        NSString *fullDir = [NSString stringWithFormat:@"%@/%@/%@", documentsDirectory, gameDir, storePath];
        NSString *filePath = [fullDir stringByAppendingPathComponent:fileName];


        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:filePath] == YES)
        {
            // Updating file modification date attribute
            NSDate *now = [NSDate date];
            NSDictionary *modificationDateAttr = [NSDictionary dictionaryWithObjectsAndKeys: now, NSFileModificationDate, nil];
            [fileManager setAttributes:modificationDateAttr ofItemAtPath:filePath error:nil];

            // holds our return data
            NSString *returnString = filePath;

            NSArray *callbackData = [[NSArray alloc] initWithObjects:command.callbackId, returnString, nil];

            // download complete pass back confirmation to JS
            [self sendCallback:callbackData];

            [callbackData release];

        } else {
            NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                                  command, @"command",
                                  fullDir, @"fullDir",
                                  filePath, @"filePath",
                                  nil];
            if (queue) {
                NSString *urlString = [command.arguments objectAtIndex:0];
                if (urlString) {
                    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".+?//.+?:.+@.+"
                                                                                           options:NSRegularExpressionCaseInsensitive
                                                                                             error:nil];
                    NSUInteger numberMatches = [regex numberOfMatchesInString:urlString
                                                                      options:0
                                                                        range:NSMakeRange(0, [urlString length])];
                    bool isBasicAuthUrl = numberMatches > 0 ? true : false;
                    if (isBasicAuthUrl) {
                        if (isProcessing) {
                            [queue enqueue:args];
                        } else {
                            isProcessing = true;
                            [self performSelectorInBackground:@selector(backgroundDownloadWrapper:) withObject:args];
                        }
                    } else {
                        [self performSelectorInBackground:@selector(backgroundDownloadWrapper:) withObject:args];
                    }
                } else {
                    NSString *returnString = @"error - bad url";
                    NSArray *callbackData = [[NSArray alloc] initWithObjects:command.callbackId, returnString, nil];
                    [self sendCallback:callbackData];
                }
            } else {
                [self performSelectorInBackground:@selector(backgroundDownloadWrapper:) withObject:args];
            }
        }
        // clean up
        [pathSpliter release];

    } else {

        CDVPluginResult* pluginResult;
        NSString *returnString;



        returnString = @"noParam";
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:returnString];
        [self writeJavascript: [pluginResult toErrorCallbackString:command.callbackId]];
        return;
    }





}

- (void)getAssetsVersion:(CDVInvokedUrlCommand*)command {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *assetsVersion = [defaults stringForKey:assetsVersionKey];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:assetsVersion];
    [self writeJavascript: [pluginResult toSuccessCallbackString:command.callbackId]];
}

- (void)upgradeAssets:(CDVInvokedUrlCommand*)command {
    if (command.arguments.count < 2) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not enough parameters."];
        [self writeJavascript: [pluginResult toErrorCallbackString:command.callbackId]];
        return;
    }

    [self deleteAssets:command isUri:YES];
}


/*
 * purgeEmptyDirectories - purge that which is most unclean
 */
- (void)purgeEmptyDirectories:(CDVInvokedUrlCommand*)command
{




}






- (void)scanDir:(NSString*)basePath relPath:(NSString*)relPath assetMap:(NSMutableDictionary*)assetMap
{
    // absPath is the exact path of where we currently are on the filesystem

    NSString * absPath;

    if ([relPath length] > 0) {
        absPath = [basePath stringByAppendingString:[NSString stringWithFormat:@"/%@", relPath]];
    } else {
        absPath = [basePath stringByAppendingString:relPath];
    }

    //WizLog(@"[WizAssetsPlugin] ******* scanning path %@", absPath );

    // for each file inside this dir

    for (NSString* fileName in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:absPath error:nil]) {
        // create a new relative path for this file

        NSString * newRelPath;

        if ([relPath length] > 0) {
            newRelPath = [relPath stringByAppendingString:[NSString stringWithFormat:@"/%@", fileName]];
        } else {
            newRelPath = [relPath stringByAppendingString:fileName];
        }

        // create a new absolute path for this file, based on the basePath and the new relative path

        NSString * newAbsPath = [basePath stringByAppendingString:[NSString stringWithFormat:@"/%@", newRelPath]];

        if ( [[NSFileManager defaultManager] contentsOfDirectoryAtPath:newAbsPath error:NULL] ){
            // the found file is a directory, so we recursively scan it

            [self scanDir:basePath relPath:newRelPath assetMap:assetMap ];
        } else {
            // the found file is a real file, so we add it to the asset map
            // I JUST DELETED HERE file://localhost
            NSString * URIString = [NSString stringWithFormat:@"%@", newAbsPath];

            // WizLog(@"[WizAssetsPlugin] ******* newRelPath URI %@", newRelPath );
            // WizLog(@"[WizAssetsPlugin] ******* assetMap URI %@", URIString );

            [assetMap setObject: URIString forKey: newRelPath];



        }
    }
}



/*
 * getFileURI - return a URI to the requested resource
 */
- (void)getFileURI:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult;

    NSString *findFile = [command.arguments objectAtIndex:0];
    NSString *returnURI = @"";


    NSMutableArray *fileStruct = [[NSMutableArray alloc] initWithArray:[findFile componentsSeparatedByString:@"/"]];
    // ie [0]img, [1]ui, [2]bob.mp3

    NSString * fileName = [fileStruct lastObject];
    // ie bob.mp3

    [fileStruct removeLastObject];
    NSString * findFilePath = [fileStruct componentsJoinedByString:@"/"];
    // ie img/ui

    // cut out suffix from file name
    NSMutableArray *fileTypeStruct = [[NSMutableArray alloc] initWithArray:[fileName componentsSeparatedByString:@"."]];
    // ie [0]bob, [1]mp3,



    if([[NSBundle mainBundle] pathForResource:[fileTypeStruct objectAtIndex:0] ofType:[fileTypeStruct objectAtIndex:1] inDirectory:[@"www" stringByAppendingFormat:@"/assets/%@", findFilePath]])
    {   // check local

        // path to bundle resources
        NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
        NSString *bundleSearchPath = [NSString stringWithFormat:@"%@/%@/%@/%@", bundlePath , @"www", @"assets", findFile];

        // we have locally return same string
        returnURI = bundleSearchPath;

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:returnURI];
    } else {
        // check in app docs folder

        // path to app library/caches
        NSString * documentsPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString * gamePath = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
        NSString * searchPath = [documentsPath stringByAppendingFormat:@"/%@", gamePath];

        NSMutableDictionary * resourceMap = [NSMutableDictionary dictionary];
        [self scanDir:searchPath relPath:@"" assetMap:resourceMap];

        // return URI to storage folder
        returnURI = [resourceMap objectForKey:findFile];

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:returnURI];
    }

    [fileStruct release];
    [fileTypeStruct release];
    [self writeJavascript: [pluginResult toSuccessCallbackString:command.callbackId]];
}



/*
 * getFileURIs - return all resources in app folder
 */
- (void)getFileURIs:(CDVInvokedUrlCommand*)command
{
    WizLog(@"[WizAssetsPlugin] ******* getfileURIs-> " );
    // [self.appDelegate updateLoaderLabel:@"Checking for updates..."];


    CDVPluginResult* pluginResult;

    // path to bundle resources
    NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
    NSString *bundleSearchPath = [NSString stringWithFormat:@"%@/%@/%@", bundlePath , @"www", @"assets"];

    // scan bundle assets
    NSMutableDictionary * bundleAssetMap = [NSMutableDictionary dictionary];
    [self scanDir:bundleSearchPath relPath:@"" assetMap:bundleAssetMap];

    // WizLog(@"[WizAssetsPlugin] ******* bundleAssetMap-> %@  ", bundleAssetMap );


    // path to app library caches
    NSString * documentsPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * gamePath = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    NSString * searchPath = [documentsPath stringByAppendingFormat:@"/%@", gamePath];

    // scan downloaded assets
    NSMutableDictionary * docAssetMap = [NSMutableDictionary dictionary];
    [self scanDir:searchPath relPath:@"" assetMap:docAssetMap];

    // WizLog(@"[WizAssetsPlugin] ******* docAssetMap-> %@  ", docAssetMap );



    NSMutableDictionary *assetMap = [docAssetMap mutableCopy];
    [assetMap addEntriesFromDictionary:bundleAssetMap];

    // WizLog(@"[WizAssetsPlugin] ******* final assetMap-> %@  ", assetMap );


    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:assetMap];
    [self writeJavascript: [pluginResult toSuccessCallbackString:command.callbackId]];

    [assetMap release];

}

/*
 * deleteAssets - delete all resources specified in array from app folder
 */
- (void)deleteAssets:(CDVInvokedUrlCommand *)command isUri:(BOOL)isUri {
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                          command, @"command",
                          [NSNumber numberWithBool:isUri], @"isUri",
                          nil];
    [self performSelectorInBackground:@selector(backgroundDeleteWrapper:) withObject:args];
}

- (void)backgroundDeleteWrapper:(NSDictionary *)args {
    // Create a pool
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    [self backgroundDelete:[args objectForKey:@"command"] isUri:[[args objectForKey:@"isUri"] boolValue]];

    // clean up
    [pool release];
}

- (void)backgroundDelete:(CDVInvokedUrlCommand *)command isUri:(BOOL)isUri {

    NSString *newVersion = [NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]];
    NSMutableArray *fileArray = [[NSMutableArray alloc] initWithArray:[command.arguments objectAtIndex:1] copyItems:YES];

    NSError *error = nil;
    for (int i=0; i< [fileArray count]; i++) {
        NSString *filePath = [fileArray objectAtIndex:i];
        [self deleteAsset:filePath isUri:isUri error:&error];
        if (error) {
            error = [NSError errorWithDomain:assetsErrorKey code:100 userInfo:nil];
            break;
        }
    }

    NSArray* callbackData = [[NSArray alloc] initWithObjects:command.callbackId, newVersion, error, nil];

    // download complete pass back confirmation to JS
    [self performSelectorOnMainThread:@selector(completeDelete:) withObject:callbackData waitUntilDone:YES];

    [callbackData release];
}

/*
 * completeDelete - callback after delete
 */
- (void)completeDelete:(NSArray*)callbackdata {
    NSString *callbackId = [callbackdata objectAtIndex:0];
    NSString *newVersion = [callbackdata objectAtIndex:1];
    NSError *error = nil;
    if ([callbackdata count] > 2) {
        error = [callbackdata objectAtIndex:2];
    }

    if (error) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Deleting files failed."];
        [self writeJavascript: [pluginResult toErrorCallbackString:callbackId]];
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:newVersion forKey:assetsVersionKey];
    [defaults synchronize];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self writeJavascript: [pluginResult toSuccessCallbackString:callbackId]];
}

/*
 * deleteAsset - delete resource specified in string from app folder
 */
- (void)deleteAsset:(NSString *)filePath isUri:(BOOL)isUri error:(NSError **)error {
    NSFileManager *filemgr = [NSFileManager defaultManager];

    if (filePath && [filePath length] > 0) {
        // Check if the file is not in the bundle..
        NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
        if ([filePath rangeOfString:bundlePath].location == NSNotFound) {
            if (isUri) {
                filePath = [self buildAssetFilePathFromUri:filePath];
            }

            NSError *localError = nil;
            if (![filemgr removeItemAtPath:filePath error:&localError]) {
                *error = [NSError errorWithDomain:assetsErrorKey code:200 userInfo:nil];
            }
        } else {
            *error = [NSError errorWithDomain:assetsErrorKey code:200 userInfo:nil];
        }
    }
}

- (NSString *)buildAssetFilePathFromUri:(NSString *)uri {
    NSString * documentsPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * gamePath = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    return [documentsPath stringByAppendingFormat:@"/%@/%@", gamePath, uri];
}

/*
 * deleteFile - delete all resources specified in string from app folder
 */
- (void)deleteFile:(CDVInvokedUrlCommand*)command
{
    NSFileManager *filemgr;
    filemgr =[NSFileManager defaultManager];

    CDVPluginResult* pluginResult;

    NSString *filePath = [command.arguments objectAtIndex:0];
    // example filePath -
    // file://localhost/Users/WizardBookPro/Library/Application%20Support/iPhone%20Simulator/4.3.2/Applications/AD92CAB6-C364-4536-A4F5-E8333CB9F054/Documents/ZombieBoss/img/ui/logo-v1-g.jpg


    // note: if no files sent here, still success (technically it is not an error as we success to delete nothing)

    if (filePath) {


        // check not file in bundle..

        NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
        if ([filePath rangeOfString:bundlePath].location == NSNotFound) {

            if ([filemgr removeItemAtPath:filePath error:nil ]) {
                // success delete
                WizLog(@"[WizAssetsPlugin] ******* deletingFile > %@", filePath);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [self writeJavascript: [pluginResult toSuccessCallbackString:command.callbackId]];

            } else {
                // cannot delete
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"NotFoundError"];
                [self writeJavascript: [pluginResult toErrorCallbackString:command.callbackId]];
            }
        } else {
            // cannot delete file in the bundle
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                             messageAsString:@"NoModificationAllowedError"];
            [self writeJavascript: [pluginResult toErrorCallbackString:command.callbackId]];
        }


    } else {
        // successfully deleted nothing
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self writeJavascript: [pluginResult toSuccessCallbackString:command.callbackId]];
    }
}




/*
 * deleteFiles - delete all resources specified in array from app folder
 */
- (void)deleteFiles:(CDVInvokedUrlCommand*)command
{
    NSFileManager *filemgr;
    filemgr =[NSFileManager defaultManager];

    CDVPluginResult* pluginResult;

    NSMutableArray *fileArray = [[NSMutableArray alloc] initWithArray:command.arguments copyItems:YES];
    // example filePath[] -
    // [file://localhost/Users/WizardBookPro/Library/Application%20Support/iPhone%20Simulator/4.3.2/Applications/AD92CAB6-C364-4536-A4F5-E8333CB9F054/Documents/ZombieBoss/img/ui/logo-v1-g.jpg, file://localhost/Users/WizardBookPro/Library/Application%20Support/iPhone%20Simulator/4.3.2/Applications/AD92CAB6-C364-4536-A4F5-E8333CB9F054/Documents/ZombieBoss/img/ui/logo2-v1-g.jpg ]

    if (fileArray) {

        // count array
        for (int i=0; i< [fileArray count]; i++){

            /*
             was using file:// locahost

            // split each URI in array to remove PhoneGap prefix (file://localhost) then delete
            NSString *singleFile = [fileArray objectAtIndex:i];

            NSMutableArray *pathSpliter = [[NSMutableArray alloc] initWithArray:[singleFile componentsSeparatedByString:@"localhost"] copyItems:YES];
            NSString *iphonePath = [pathSpliter lastObject];
            WizLog(@"[WizAssetsPlugin] ******* deletingFile > %@", iphonePath);

            [filemgr removeItemAtPath:iphonePath error:NULL];
            [pathSpliter release];

             */

            // split each URI in array to remove PhoneGap prefix (file://localhost) then delete
            NSString *singleFile = [fileArray objectAtIndex:i];

            WizLog(@"[WizAssetsPlugin] ******* deletingFile > %@", singleFile);

            [filemgr removeItemAtPath:singleFile error:NULL];

        }

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"noParam"];
    }

    [fileArray release];
    [self writeJavascript: [pluginResult toSuccessCallbackString:command.callbackId]];

}

@end
