// Copyright 2015-present 650 Industries. All rights reserved.

#import "EXUserNotificationManager.h"
#import "EXKernel.h"
#import "EXRemoteNotificationManager.h"

@interface EXUserNotificationManager()
@property (atomic) UNUserNotificationCenter *center;
@property NSDictionary *Categories;
@end

@implementation EXUserNotificationManager
+ (instancetype)sharedInstance
{
  static EXUserNotificationManager *theManager;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    if (!theManager) {
      theManager = [EXUserNotificationManager new];
    }
  });
  return theManager;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
  if (![[EXKernel sharedInstance].serviceRegistry.remoteNotificationManager supportsCurrentRuntimeEnvironment]) {
    DDLogWarn(@"Expo Remote Notification services won't work in an ExpoKit app because Expo cannot manage your APNS certificates.");
  }
  BOOL isFromBackground = !([UIApplication sharedApplication].applicationState == UIApplicationStateActive);  NSDictionary *payload = response.notification.request.content.userInfo;
  if (payload) {
    NSDictionary *body = (payload[@"body"])?[payload objectForKey:@"body"]:@{};
    NSString *experienceId = [payload objectForKey:@"experienceId"];
    NSString * userText = @"";
    NSString * actionId = @"DEFAULT_ACTION";
    
    if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
      actionId = @"DISMISS_ACTION";
    } else if (![response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
      actionId = response.actionIdentifier;
    }
    
    if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
      userText = ((UNTextInputNotificationResponse *) response).userText;
    }
    
    BOOL isRemote = [response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]];
    if (body && experienceId) {
      [[EXKernel sharedInstance] sendNotification:body
                               toExperienceWithId:experienceId
                                   fromBackground:isFromBackground
                                         isRemote:isRemote
                                         actionId: actionId
                                         userText: userText];
    }
  }
  completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
  NSDictionary *payload = notification.request.content.userInfo;
  if (payload) {
    NSDictionary *body = (payload[@"body"])?[payload objectForKey:@"body"]:@{};
    NSString *experienceId = [payload objectForKey:@"experienceId"];
    NSString * userText = @"";
    
    BOOL isRemote = [notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]];
    if (body && experienceId) {
      [[EXKernel sharedInstance] sendNotification:body
                               toExperienceWithId:experienceId
                                   fromBackground:NO
                                         isRemote:isRemote
                                         actionId: @"WILL_PRESENT_ACTION"
                                         userText: userText];
    }
  }
  completionHandler(UNAuthorizationOptionAlert + UNAuthorizationOptionSound);
}

- (void)authorizeAndInit: (NSDictionary *) launchOptions
{
  _center = [UNUserNotificationCenter currentNotificationCenter];
  _center.delegate = self;
  
  UNAuthorizationOptions options = UNAuthorizationOptionAlert + UNAuthorizationOptionSound;
  [_center requestAuthorizationWithOptions:options
    completionHandler:^(BOOL granted, NSError * _Nullable error) {
      if (!granted) {
      }
    }
  ];
}

@end
