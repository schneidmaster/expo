//  Copyright © 2018 650 Industries. All rights reserved.

#import <Foundation/Foundation.h>

@interface EXSendNotificationParams : NSObject
@property (atomic, strong) NSString *experienceId;
@property (atomic, strong) NSDictionary *dic;
@property (atomic, strong) NSNumber *isRemote;
@property (atomic, strong) NSNumber *isFromBackground;
@property (atomic, strong) NSString *actionId;
@property (atomic, strong) NSString *userText;
- (instancetype)initWithExpId:(NSString *)expId
   notificationBody: (NSDictionary *)dic
           isRemote: (NSNumber *) isRemote
   isFromBackground: (NSNumber *)isFromBackground
           actionId: (NSString *)actionId
           userText: (NSString *)userText;
@end
