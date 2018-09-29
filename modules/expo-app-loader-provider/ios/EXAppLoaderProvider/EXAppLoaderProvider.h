// Copyright 2018-present 650 Industries. All rights reserved.

#import <EXAppLoaderProvider/EXAppLoaderInterface.h>

#define EX_REGISTER_APP_LOADER(_custom_load_code) \
extern void EXRegisterAppLoader(Class); \
+ (void)load { \
  EXRegisterAppLoader(self); \
  _custom_load_code \
}

@interface EXAppLoaderProvider : NSObject

- (nullable id<EXAppLoaderInterface>)createAppLoader;

+ (nonnull instancetype)sharedInstance;

@end
