// Copyright 2015-present 650 Industries. All rights reserved.

@import ObjectiveC;

#import "EXBuildConstants.h"
#import "EXAppDelegate.h"

#import <Crashlytics/Crashlytics.h>
#import <Fabric/Fabric.h>
#import <EXTaskManager/EXTaskService.h>

#import "ExpoKit.h"
#import "EXRootViewController.h"
#import "EXConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface ExpoKit (Crashlytics) <CrashlyticsDelegate>

@end

@implementation EXAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions
{
  CrashlyticsKit.delegate = [ExpoKit sharedInstance]; // this must be set prior to init'ing fabric.
  [Fabric with:@[CrashlyticsKit]];
  [CrashlyticsKit setObjectValue:[EXBuildConstants sharedInstance].expoRuntimeVersion forKey:@"exp_client_version"];

  if ([application applicationState] != UIApplicationStateBackground) {
    // App launched in foreground
    [self _setupUserInterfaceForApplication:application withLaunchOptions:launchOptions];
  }
  [[EXTaskService sharedInstance] applicationDidFinishLaunchingWithOptions:launchOptions];
  return YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  NSLog(@"ExpoClient will enter foreground");
  [self _setupUserInterfaceForApplication:application withLaunchOptions:nil];
}

- (void)_setupUserInterfaceForApplication:(UIApplication *)application withLaunchOptions:(nullable NSDictionary *)launchOptions
{
  if (_window == nil) {
    [[ExpoKit sharedInstance] registerRootViewControllerClass:[EXRootViewController class]];
    [[ExpoKit sharedInstance] application:application didFinishLaunchingWithOptions:nil];

    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.backgroundColor = [UIColor whiteColor];
    _rootViewController = (EXRootViewController *)[ExpoKit sharedInstance].rootViewController;
    _window.rootViewController = _rootViewController;

    [_window makeKeyAndVisible];
  }
}

#pragma mark - Background Fetch

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  [[EXTaskService sharedInstance] runTasksWithReason:EXTaskLaunchReasonBackgroundFetch userInfo:nil completionHandler:completionHandler];
}

#pragma mark - Handling URLs

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(nullable NSString *)sourceApplication annotation:(id)annotation
{
  return [[ExpoKit sharedInstance] application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray * _Nullable))restorationHandler
{
  return [[ExpoKit sharedInstance] application:application continueUserActivity:userActivity restorationHandler:restorationHandler];
}

#pragma mark - Notifications

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  [[EXTaskService sharedInstance] runTasksWithReason:EXTaskLaunchReasonRemoteNotification userInfo:userInfo completionHandler:completionHandler];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)token
{
  [[ExpoKit sharedInstance] application:application didRegisterForRemoteNotificationsWithDeviceToken:token];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)err
{
  [[ExpoKit sharedInstance] application:application didFailToRegisterForRemoteNotificationsWithError:err];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)notification
{
  [[ExpoKit sharedInstance] application:application didReceiveRemoteNotification:notification];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(nonnull UILocalNotification *)notification
{
  [[ExpoKit sharedInstance] application:application didReceiveLocalNotification:notification];
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(nonnull UIUserNotificationSettings *)notificationSettings
{
  [[ExpoKit sharedInstance] application:application didRegisterUserNotificationSettings:notificationSettings];
}

@end

NS_ASSUME_NONNULL_END
