// Copyright 2018-present 650 Industries. All rights reserved.

#import <EXReactNativeLoader/EXReactNativeLoader.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTBridge.h>

@implementation EXReactNativeLoader

+ (void)createApplication:(nonnull NSString *)applicationUrl launchOptions:(nullable NSDictionary *)launchOptions
{
  NSURL *bundleUrl = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:applicationUrl fallbackResource:nil];
  RCTBridge *bridge = [[RCTBridge alloc] initWithBundleURL:bundleUrl
                                            moduleProvider:nil
                                             launchOptions:launchOptions];
}

@end
