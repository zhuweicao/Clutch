//
//  Cracker.m
//  Clutch
//
//  Created by DilDog on 12/22/13.
//
//

#import "Cracker.h"
#import "CAApplication.h"
#import "out.h"
#import "imetadata.h"
#import "scinfo.h"
#import "izip.h"
#import "ZipArchive.h"

#import "Packager.h"

@interface Cracker ()

@end

@implementation Cracker

- (id)init
{
    self = [super init];
    if (self)
    {
        _appDescription = NULL;
        _workingDir = NULL;
    }
    return self;
}

-(void)dealloc
{
    if(_appDescription)
    {
        [_appDescription release];
    }
    if(_baselinedir)
    {
        [_baselinedir release];
    }
    if(_finaldir)
    {
        [_finaldir release];
    }
    if(_workingDir)
    {
        [_workingDir release];
    }
    
    [super dealloc];
}

static BOOL forceRemoveDirectory(NSString *dirpath)
{
    BOOL isDir;
    NSFileManager *fileManager=[NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:dirpath isDirectory:&isDir])
    {
        if(![fileManager removeItemAtPath:dirpath error:NULL])
        {
            return NO;
        }
    }
    return YES;
}

static BOOL forceCreateDirectory(NSString *dirpath)
{
    BOOL isDir;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:dirpath isDirectory:&isDir])
    {
        if(![fileManager removeItemAtPath:dirpath error:NULL])
        {
            return NO;
        }
    }
    if(![fileManager createDirectoryAtPath:dirpath withIntermediateDirectories:YES attributes:nil error:NULL])
    {
        return NO;
    }
    return YES;
}

static BOOL copyFile(NSString *infile, NSString *outfile)
{
    NSFileManager *fileManager= [NSFileManager defaultManager];
    if(![fileManager createDirectoryAtPath:[outfile stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL])
    {
        return NO;
    }
    
    if(![fileManager copyItemAtPath:infile toPath:outfile error:NULL])
    {
        return NO;
    }
    return YES;
}

static ZipArchive * createZip(NSString *file) {
    ZipArchive *archiver = [[ZipArchive alloc] init];
    
    if (!file) {
        DEBUG("File string is nil");
        
        return nil;
    }
    
    [archiver CreateZipFile2:file];
    
    return archiver;
}

-(BOOL)crackBinary {
    
}

// createPartialCopy
// copies only the files required for cracking an application to a staging area

-(BOOL)createPartialCopy:(NSString *)outdir withApplicationDir:(NSString *)appdir withMainExecutable:(NSString *)mainexe
{
    // Create output directory
    if(!forceCreateDirectory(outdir))
    {
        return NO;
    }
    
    // XXX: This, only if necessary: Get sandbox folder
    //NSString *topleveldir=[appdir stringByDeletingLastPathComponent];
    //NSString *appdirprefix=[appdir lastPathComponent];
    
    // Get top level .app folder
    NSString *topleveldir=[appdir copy];
    
    // Files required for cracking
    NSMutableArray *files=[[NSMutableArray alloc] init];
    [files addObject:@"_CodeSignature/CodeResources"];
    [files addObject:[NSString stringWithFormat:@"SC_Info/%@.sinf", mainexe]];
    [files addObject:[NSString stringWithFormat:@"SC_Info/%@.supp", mainexe]];
    [files addObject:mainexe];
    
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/_CodeSignature/CodeResources", appdirprefix]];
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/SC_Info/%@.sinf", appdirprefix, mainexe]];
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/SC_Info/%@.supp", appdirprefix, mainexe]];
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/%@", appdirprefix, mainexe]];
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/Info.plist", appdirprefix];
    //XXX:[files addObject:@"iTunesMetadata.plist"];
    //XXX:[files addObject:@"iTunesArtwork"];
    
    NSEnumerator *e = [files objectEnumerator];
    NSString *file;
    while(file = [e nextObject])
    {
        if(!copyFile([NSString stringWithFormat:@"%@/%@", topleveldir, file],
                     [NSString stringWithFormat:@"%@/%@", outdir, file]))
        {
            forceRemoveDirectory(outdir);
            return NO;
        }
    }
    
    [topleveldir release];
    [files release];
    
    return YES;
}
static NSString * genRandStringLength(int len) {
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%c", [letters characterAtIndex: arc4random()%[letters length]]];
    }
    
    return randomString;
}


// prepareFromInstalledApp
// set up application cracking from an installed application

-(BOOL)prepareFromInstalledApp:(CAApplication*)app
{
    // Create the app description
    _app = app;
    _appDescription = [NSString stringWithFormat:@"%@: %@ (%@)",
                     app.applicationBundleID,
                     app.applicationDisplayName,
                     app.applicationVersion];
    
    
    
    // Create working directory
    _workingDir = [NSString stringWithFormat:@"%@%@/Payload/%@", @"/tmp/clutch_", genRandStringLength(8), app.appDirectory];
    DebugLog(@"temporary directory %@", _workingDir);
    if (![[NSFileManager defaultManager] createDirectoryAtPath:_workingDir withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile",NSFileGroupOwnerAccountName:@"mobile"} error:NULL]) {
        
        printf("error: Could not create working directory\n");
        return nil;
    }
    _tempBinaryPath = [_workingDir stringByAppendingFormat:@"/%@", app.applicationExecutableName];
    DebugLog(@"tempBinaryPath: %@", _tempBinaryPath);
        
    _binaryPath = [[app.applicationContainer stringByAppendingPathComponent:app.appDirectory] stringByAppendingPathComponent:app.applicationExecutableName];
    
    _binary = [[CABinary alloc] initWithBinary:_binaryPath];
    DebugLog(@"binaryPath: %@", _binaryPath);
    return (!_binary)?NO:YES;
}

-(NSString*) generateIPAPath {
    NSString* ipapath;
    NSString *crackerName = [[Prefs sharedInstance] objectForKey:@"crackerName"];
    if (crackerName == nil) {
        crackerName = @"no-name-cracker";
    }
    
    ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@-%@-(%@).ipa", _app.applicationDisplayName, _app.applicationVersion, crackerName, [NSString stringWithUTF8String:CLUTCH_VERSION]];
    _ipapath = ipapath;
    return ipapath;
}

-(BOOL) execute {
    //1. dump binary
    NSError* error;
    if (![_binary crackBinaryToFile:_tempBinaryPath error:&error]) {
        DebugLog(@"Failed to crack %@ with error: %@",_app.applicationDisplayName,error.localizedDescription);
        return NO;
    }
    
   return [self packageIPA];
    
}

-(BOOL)packageIPA {

    NSString *crackerName = [[Prefs sharedInstance] objectForKey:@"crackerName"];
    if (crackerName == nil) {
        crackerName = @"no-name-cracker";
    }
    
    if (![[Prefs sharedInstance] boolForKey:@"removeMetadata"])
    {
        generateMetadata([_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"], [[[_workingDir stringByDeletingLastPathComponent]stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"]);
    }
    
    
    NSDictionary *imetadata_orig = [NSDictionary dictionaryWithContentsOfFile:[_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"]];
    
    DebugLog(@"Creating fake SC_Info data...");
    // create fake SC_Info directory
    [[NSFileManager defaultManager] createDirectoryAtPath:[_workingDir stringByAppendingPathComponent:@"SF_Info"] withIntermediateDirectories:YES attributes:nil error:NULL];
    
    NSLog(@"DEBUG: made fake directory");
    // create fake SC_Info SINF file
    FILE *sinfh = fopen([[_workingDir stringByAppendingPathComponent:@"SF_Info"]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sinf", _app.applicationExecutableName]].UTF8String, "w");

    void *sinf = generate_sinf([imetadata_orig[@"itemId"] intValue], (char *)[crackerName UTF8String], [imetadata_orig[@"vendorId"] intValue]);
    
    fwrite(sinf, CFSwapInt32(*(uint32_t *)sinf), 1, sinfh);
    fclose(sinfh);
    free(sinf);
    
    // create fake SC_Info SUPP file
    FILE *supph = fopen([[_workingDir stringByAppendingPathComponent:@"SF_Info"]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.supp", _app.applicationExecutableName]].UTF8String, "w");
    uint32_t suppsize;
    void *supp = generate_supp(&suppsize);
    fwrite(supp, suppsize, 1, supph);
    fclose(supph);
    free(supp);
    
    NOTIFY("Compressing original application (native zip) (1/2)...");
    ZipArchive *archiver = createZip(_ipapath);
    zip_original(archiver, _app.applicationContainer, _app.applicationExecutableName, _ipapath, 0);
    stop_bar();
    NOTIFY("Compressing second cracked application (native zip) (2/2)...");
    zip(archiver, _workingDir, [NSString stringWithFormat:@"Payload/%@.app/", _app.applicationName], 0);
    stop_bar();
    [archiver CloseZipFile2];
    
    return NO;
}
-(BOOL)prepareFromSpecificExecutable:(NSString *)exepath returnDescription:(NSMutableString *)description
{
    // Create the app description
    _appDescription=[NSString stringWithFormat:@"%@",exepath];
    
    return YES;
}

-(NSString *)getAppDescription
{
    return _appDescription;
}

-(NSString *)getOutputFolder
{
    return _finaldir;
}


@end