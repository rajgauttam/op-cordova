/*
 
 Copyright (c) 2012, SMB Phone Inc.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 The views and conclusions contained in the software and documentation are those
 of the authors and should not be interpreted as representing official policies,
 either expressed or implied, of the FreeBSD Project.
 
 */

#import "OpenPeer.h"
#import "AppConsts.h"
#import "Logger.h"
#import "CDVOP.h"

//SDK
#import "OpenpeerSDK/HOPStack.h"
#import "OpenpeerSDK/HOPLogger.h"
#import "OpenpeerSDK/HOPMediaEngine.h"
#import "OpenpeerSDK/HOPCache.h"
#import "OpenpeerSDK/HOPModelManager.h"
#import "OpenpeerSDK/HOPSettings.h"

//Delegates
#import "StackDelegate.h"
#import "MediaEngineDelegate.h"
#import "ConversationThreadDelegate.h"
#import "CallDelegate.h"
#import "AccountDelegate.h"
#import "IdentityDelegate.h"
#import "IdentityLookupDelegate.h"

//Private methods
@interface OpenPeer ()
- (void) createDelegates;
@end


@implementation OpenPeer

/**
 Retrieves singleton object of the Open Peer.
 @return Singleton object of the Open Peer.
 */
+ (id) sharedOpenPeer
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (NSString*) deviceId
{
    if (!_deviceId)
    {
        _deviceId = [[NSUserDefaults standardUserDefaults] objectForKey:keyOpenPeerUser];
        if ([_deviceId length] == 0)
        {
            _deviceId = [OpenPeer getGUIDstring];
            [[NSUserDefaults standardUserDefaults] setObject:_deviceId forKey:keyOpenPeerUser];
        }
    }
    return _deviceId;
}


/*
 * If default settings have never been persisted (first run of the app) or if reset flag
 * is set to true, this method will store app settings
 */
- (void) storeDefaultSettings:(BOOL)reset
{
    //TODO: reset
    //Set persistent stores
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dataPathDirectory = [libraryPath stringByAppendingPathComponent:@"db"];
    [[HOPModelManager sharedModelManager] setDataPath:dataPathDirectory backupData:NO];
    NSString *cachePathDirectory = [libraryPath stringByAppendingPathComponent:@"cache"];
    [[HOPModelManager sharedModelManager] setCachePath:cachePathDirectory];
    
    //Set settigns delegate
    [[HOPSettings sharedSettings] setup];//WithDelegate:[Settings sharedSettings]];
    
    //Cleare expired cookies and set delegate
    [[HOPCache sharedCache] removeExpiredCookies];
    //[[HOPCache sharedCache] setDelegate:self.cacheDelegate];
    
    // TODO: get this from client side
    NSString* tmpSettings =
    @"{'root':\
    {\
    'outerFrameURL': 'http://jsouter-v1-beta-1-i.hcs.io/identity.html?view=choose&federated=false',\
    'identityProviderDomain': 'identity-v1-beta-1-i.hcs.io',\
    'identityFederateBaseURI': 'identity://identity-v1-beta-1-i.hcs.io/',\
    'namespaceGrantServiceURL': 'http://jsouter-v1-beta-1-i.hcs.io/grant.html',\
    'lockBoxServiceDomain': 'lockbox-v1-beta-1-i.hcs.io',\
    'archiveOutgoingTelnetLoggerServer': 'tcp-logger-v1-beta-1-i.hcs.io:8055',\
    'archiveTelnetLoggerServer': '59999'\
    }\
    }";
    
    [[HOPSettings sharedSettings] applySettings:tmpSettings];
    
    // for now manually apply the rest of the default settings. TODO: get all from client
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:archiveMediaAEC];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:archiveMediaAGC];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:archiveMediaNS];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:archiveRemoteSessionActivationMode];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:archiveFaceDetectionMode];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:archiveRedialMode];

    [[NSUserDefaults standardUserDefaults] synchronize];
    
    
    if (![[HOPModelManager sharedModelManager] getLastLoggedInHomeUser])
    {
        //If not already set, set default login settings
        /*
        BOOL isSetLoginSettings = [[Settings sharedSettings] isLoginSettingsSet];
        if (!isSetLoginSettings)
        {
            [[HOPSettings sharedSettings] applyDefaults];
            
            NSString *filePath = [[NSBundle mainBundle] pathForResource:@"DefaultSettings" ofType:@"plist"];
            if ([filePath length] > 0)
            {
                NSDictionary* filteredDictionary = [[Settings sharedSettings] dictionaryWithRemovedAllInvalidEntriesForPath:filePath];
                if ([filteredDictionary count] > 0)
                    [[HOPSettings sharedSettings] storeSettingsFromDictionary:filteredDictionary];
                //[[HOPSettings sharedSettings] storeSettingsFromPath:filePath];
            }
            
            isSetLoginSettings = [[Settings sharedSettings] isLoginSettingsSet];
        }
        */
        
        //If not already set, set default app data
        /*
        BOOL isSetAppData = [[Settings sharedSettings] isAppDataSet];
        if (!isSetAppData)
        {
            NSString* filePath = [[NSBundle mainBundle] pathForResource:@"CustomerSpecific" ofType:@"plist"];
            if ([filePath length] > 0)
            {
                NSDictionary* filteredDictionary = [[Settings sharedSettings] dictionaryWithRemovedAllInvalidEntriesForPath:filePath];
                if ([filteredDictionary count] > 0)
                    [[HOPSettings sharedSettings] storeSettingsFromDictionary:filteredDictionary];
                //[[HOPSettings sharedSettings] storeSettingsFromPath:filePath];
            }
            isSetAppData = [[Settings sharedSettings] isAppDataSet];
        }
         */
        
    }
}

/**
 Initializes the open peer stack. After initialization succeeds, login screen is displayed, or user relogin started.
 @param authorizedApplicationId that is generated based on app id and shared secret
 */
- (void) setup:(NSString*)authorizedApplicationId
{
    //Create all delegates required for communication with core
    [self createDelegates];
    [self storeDefaultSettings:YES];

    // temporary logging to debug. TODO: remove this
    [OpenPeer startLogging];

    NSString* applicationName = [[CDVOP sharedObject] getSetting:@"applicationName"];
    NSString* applicationURL = [[CDVOP sharedObject] getSetting:@"applicationURL"];
    NSString* applicationImageURL = [[CDVOP sharedObject] getSetting:@"applicationImageURL"];
    
    //TODO: Init openpeer stack using client side settings and set created delegates
    [[HOPStack sharedStack] setupWithStackDelegate:self.stackDelegate mediaEngineDelegate:self.mediaEngineDelegate appID:authorizedApplicationId appName:applicationName appImageURL:applicationImageURL appURL:applicationURL userAgent:[OpenPeer getUserAgentName] deviceID:self.deviceId deviceOs:[OpenPeer getDeviceOs] system:[OpenPeer getPlatform]];

    //Start with login procedure and display login view
    //[[LoginManager sharedLoginManager] login];

    /*
    [[HOPMediaEngine sharedInstance] setEcEnabled:[[CDVOP sharedObject] getSettingAsBool:@"isMediaAECOn"]];
    [[HOPMediaEngine sharedInstance] setAgcEnabled:[[Settings sharedSettings] isMediaAGCOn]];
    [[HOPMediaEngine sharedInstance] setNsEnabled:[[Settings sharedSettings] isMediaNSOn]];
     */
    NSLog(@"Finished setting up HOP stack");
}

- (void) shutdown
{
    [[HOPStack sharedStack] shutdown];
    
    self.stackDelegate = nil;
    self.mediaEngineDelegate = nil;
    self.conversationThreadDelegate = nil;
    self.callDelegate = nil;
    self.accountDelegate = nil;
    self.identityDelegate = nil;
    self.identityLookupDelegate = nil;
    //self.cacheDelegate = nil;
}
/**
 Method used for all delegates creation. Delegates will catch events from the Open Peer SDK and handle them properly.
 */
- (void) createDelegates
{
    self.stackDelegate = [[StackDelegate alloc] init];
    self.mediaEngineDelegate = [[MediaEngineDelegate alloc] init];
    self.conversationThreadDelegate = [[ConversationThreadDelegate alloc] init];
    self.callDelegate = [[CallDelegate alloc] init];
    self.accountDelegate = [[AccountDelegate alloc] init];
    self.identityDelegate = [[IdentityDelegate alloc] init];
    //self.identityDelegate.loginDelegate = self.mainViewController;
    self.identityDelegate.loginDelegate = [CDVOP sharedObject];
    self.identityLookupDelegate = [[IdentityLookupDelegate alloc] init];
    //self.cacheDelegate = [[CacheDelegate alloc] init];
}

// Utility functions

+ (NSString *)getGUIDstring
{
    CFUUIDRef guid = CFUUIDCreate(nil);
    NSString *strGuid = (NSString *)CFBridgingRelease(CFUUIDCreateString(nil, guid));
    CFRelease(guid);
    return strGuid;
}

+ (NSString*) getDeviceOs
{
    NSString* deviceOs = [NSString stringWithFormat:@"%@ %@,",[[UIDevice currentDevice] systemName],[[UIDevice currentDevice]  systemVersion]];
    return deviceOs;
}

+ (NSString*) getPlatform
{
    size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    //sysctlbyname("hw.model", NULL, &size, NULL, 0);
	char *machine = (char*)malloc(size);
	sysctlbyname("hw.machine", machine, &size, NULL, 0);
    //sysctlbyname("hw.model", machine, &size, NULL, 0);
	NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
	free(machine);
    
    if ([platform isEqualToString:@"iPhone1,1"]) return @"iPhone 1G";
	if ([platform isEqualToString:@"iPhone1,2"]) return @"iPhone 3G";
	if ([platform isEqualToString:@"iPhone2,1"]) return @"iPhone 3GS";
    if ([platform hasPrefix:@"iPhone3"]) return @"iPhone 4";
    if ([platform hasPrefix:@"iPhone4"]) return @"iPhone 4S";
    
	if ([platform isEqualToString:@"iPod1,1"])   return @"iPod Touch 1G";
	if ([platform isEqualToString:@"iPod2,1"])   return @"iPod Touch 2G";
    if ([platform hasPrefix:@"iPod3"])   return @"iPod Touch 3G";
    if ([platform hasPrefix:@"iPod4"])   return @"iPod Touch 4G";
    
    
    if ([platform isEqualToString:@"iPad1,1"])   return @"iPad 1";
	if ([platform isEqualToString:@"iPad2,1"])   return @"iPad 2";
    if ([platform hasPrefix:@"iPad3"])    return @"iPad 3";
    
	if ([platform isEqualToString:@"i386"])   return @"iPhone Simulator";
	return platform;
}

+ (NSString*) getUserAgentName
{
    NSString* developerId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Hookflash Developer ID"];
    
    NSString* appName = [[[NSBundle mainBundle] infoDictionary]   objectForKey:@"CFBundleName"];
    NSString* appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString* appOs = [[UIDevice currentDevice] systemName];
    NSString* appVersionOs = [[UIDevice currentDevice] systemVersion];
    NSString* deviceModel = [[UIDevice currentDevice] model];
    
    NSString* model = nil;
    
    if ([deviceModel hasPrefix:@"iPhone"] || [deviceModel hasPrefix:@"iPod"])
        model = @"iPhone";
    else if ([deviceModel hasPrefix:@"iPad"])
        model = @"iPad";
    
    NSString* userAgent = [NSString stringWithFormat:@"%@/%@ (%@ %@;%@) HOPID/1.0 (%@)",appName,appVersion,appOs,appVersionOs,model,developerId];
    
    return userAgent;
}

// this function for debugging purpose. TODO: remove this and replace with proper logger configuration
+ (void) startLogging {
    HOPLoggerLevels logLevel = HOPLoggerLevelTrace;
    [HOPLogger setLogLevelbyName:moduleApplication level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServices level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServicesWire level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServicesIce level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServicesTurn level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServicesRudp level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServicesHttp level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServicesMls level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServicesTcp level:logLevel];
    [HOPLogger setLogLevelbyName:moduleServicesTransport level:logLevel];
    [HOPLogger setLogLevelbyName:moduleCore level:logLevel];
    [HOPLogger setLogLevelbyName:moduleStackMessage level:logLevel];
    [HOPLogger setLogLevelbyName:moduleStack level:logLevel];
    [HOPLogger setLogLevelbyName:moduleWebRTC level:logLevel];
    [HOPLogger setLogLevelbyName:moduleZsLib level:logLevel];
    [HOPLogger setLogLevelbyName:moduleSDK level:logLevel];
    [HOPLogger setLogLevelbyName:moduleMedia level:logLevel];
    [HOPLogger setLogLevelbyName:moduleJavaScript level:logLevel];

    [Logger startStdLogger:YES];
    
    
}

@end
