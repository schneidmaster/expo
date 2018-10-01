// Copyright 2018-present 650 Industries. All rights reserved.

#import <EXLocalization/EXLocalization.h>

@implementation EXLocalization

EX_EXPORT_MODULE(ExpoLocalization)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (NSMutableArray *)ensureLocaleTags:(NSArray *)locales
{
    NSMutableArray *sanitizedLocales = [NSMutableArray array];
    for (id locale in locales)
        [sanitizedLocales addObject:[locale stringByReplacingOccurrencesOfString:@"_" withString:@"-"]];

    return sanitizedLocales;
}

- (NSDictionary *)constantsToExport
{
  NSArray *preferredLocales = [self ensureLocaleTags:[NSLocale preferredLanguages]];
  NSTimeZone *currentTimeZone = [NSTimeZone localTimeZone];
  NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
  
  NSLocaleLanguageDirection localeLanguageDirection = [NSLocale characterDirectionForLanguage:[NSLocale preferredLanguages][0]];
  BOOL isRTL = localeLanguageDirection == NSLocaleLanguageDirectionRightToLeft;
  
  return @{
           @"isRTL": @(isRTL),
           @"locale": [preferredLocales objectAtIndex:0],
           @"locales": preferredLocales,
           @"timezone": [currentTimeZone name],
           @"isoCurrencyCodes": [NSLocale ISOCurrencyCodes],
           @"country": countryCode
           };
}

@end
