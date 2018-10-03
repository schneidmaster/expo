//
//  EXSendNotificationParams.m
//  Exponent
//
//  Created by smszymon on 21.09.2018.
//  Copyright © 2018 650 Industries. All rights reserved.
//

#import "EXSendNotificationParams.h"

@implementation EXSendNotificationParams

- (instancetype)initWithExpId:(NSString *)expId
   notificationBody: (NSDictionary *)dic
           isRemote: (NSNumber *) isRemote
   isFromBackground: (NSNumber *)isFromBackground
           actionId: (NSString *)actionId
           userText: (NSString *)userText {
  if (self = [super init]) {
    _isRemote = isRemote;
    _isFromBackground = isFromBackground;
    _experienceId = expId;
    _dic = dic;
    _actionId = actionId;
    _userText = userText;
    return self;
  }
  return nil;
}

@end
