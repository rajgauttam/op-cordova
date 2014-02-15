/**

*/

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDV.h>
#import <Cordova/CDVViewController.h>

//OP SDK
#import "OpenpeerSDK/HOPStack.h"
#import "OpenpeerSDK/HOPLogger.h"
#import "OpenpeerSDK/HOPMediaEngine.h"
#import "OpenpeerSDK/HOPCache.h"
#import "OpenpeerSDK/HOPAccount.h"
#import "OpenpeerSDK/HOPIdentity.h"

@interface CDVOP : CDVPlugin <UIWebViewDelegate> {
    NSString* callbackId;
    UIImageView* peerImageView;
    UIImageView* selfImageView;
}

@property (nonatomic, copy) NSString* callbackId;
@property (retain, nonatomic) UIImageView *peerImageView;
@property (retain, nonatomic) UIImageView *selfImageView;

- (void) authorizeApp:(CDVInvokedUrlCommand*)command;
- (void) configureApp:(CDVInvokedUrlCommand*)command;
- (void) getAccountState:(CDVInvokedUrlCommand*)command;
- (void) startLoginProcess:(CDVInvokedUrlCommand*)command;
- (void) showCatPictures:(CDVInvokedUrlCommand*)command

@end


