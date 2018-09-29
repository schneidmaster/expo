// Copyright 2018-present 650 Industries. All rights reserved.

#import <EXAppLoaderProvider/EXAppLoaderProvider.h>
#import <EXAppLoaderProvider/EXAppLoaderInterface.h>

static Class providedAppLoaderClass;

extern void EXRegisterAppLoader(Class);
extern void EXRegisterAppLoader(Class loaderClass)
{
  if (providedAppLoaderClass == nil) {
    if ([loaderClass conformsToProtocol:@protocol(EXAppLoaderInterface)]) {
      providedAppLoaderClass = loaderClass;
    } else {
      NSLog(@"EXAppLoader class (%@) doesn't conform to EXAppLoaderInterface protocol.", NSStringFromClass(providedAppLoaderClass));
    }
  } else {
    NSLog(@"Another EXAppLoader class (%@) is already registered. Your project should depend on only one application loader.", NSStringFromClass(providedAppLoaderClass));
  }
}

@implementation EXAppLoaderProvider

- (nullable id<EXAppLoaderInterface>)createAppLoader
{
  return [providedAppLoaderClass new];
}

# pragma mark - static

+ (nonnull instancetype)sharedInstance
{
  static EXAppLoaderProvider *loaderProvider = nil;
  static dispatch_once_t once;

  dispatch_once(&once, ^{
    if (loaderProvider == nil) {
      loaderProvider = [[EXAppLoaderProvider alloc] init];
    }
  });
  return loaderProvider;
}

@end
