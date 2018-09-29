// Copyright 2018-present 650 Industries. All rights reserved.

#import <CoreLocation/CLLocationManager.h>

#import <EXLocation/EXLocation.h>
#import <EXLocation/EXLocationTaskConsumer.h>
#import <EXTaskManagerInterface/EXTaskInterface.h>

@interface EXLocationTaskConsumer ()

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSDictionary *options;

@end

@implementation EXLocationTaskConsumer

+ (BOOL)supportsLaunchReason:(EXTaskLaunchReason)launchReason
{
  return launchReason == EXTaskLaunchReasonLocation;
}

- (void)dealloc
{
  NSLog(@"EXLocationTaskConsumer.dealloc");
  if (_locationManager != nil) {
    [_locationManager stopMonitoringSignificantLocationChanges];
    _locationManager = nil;
  }
}

# pragma mark - EXTaskConsumerInterface

- (void)didReceiveTask:(id<EXTaskInterface>)task
{
  _task = task;
  _locationManager = [CLLocationManager new];

  _locationManager.delegate = self;
  _locationManager.allowsBackgroundLocationUpdates = YES;
  _locationManager.pausesLocationUpdatesAutomatically = NO;
  _locationManager.desiredAccuracy = [task.options[@"enableHighAccuracy"] boolValue] ? kCLLocationAccuracyBest : kCLLocationAccuracyHundredMeters;

  if (@available(iOS 11.0, *)) {
    _locationManager.showsBackgroundLocationIndicator = [[task.options objectForKey:@"showsBackgroundLocationIndicator"] boolValue];
  }

  [_locationManager startMonitoringSignificantLocationChanges];
  NSLog(@"EXLocation: registered task %@", task.name);
}

- (void)didUnregister
{
  [_locationManager stopMonitoringSignificantLocationChanges];
  _locationManager = nil;
  _task = nil;

  NSLog(@"EXLocationTaskConsumer.didUnregister");
}

- (void)didFinishTask
{
  NSLog(@"EXLocationTaskConsumer.didFinishTask");
}

# pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
  NSLog(@"EXLocationTaskConsumer.locationManager:didUpdateLocations");
  if (_task != nil) {
    NSDictionary *data = @{
                           @"locations": [EXLocationTaskConsumer _exportLocations:locations],
                           };
    [_task executeWithData:data withError:nil];
  }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
  NSLog(@"EXLocationTaskConsumer: didFailWithError %@", error.description);
  [_task executeWithData:nil withError:error];
}

# pragma mark - internal

+ (NSArray<NSDictionary *> *)_exportLocations:(NSArray<CLLocation *> *)locations
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray new];

  for (CLLocation *location in locations) {
    [result addObject:[EXLocation exportLocation:location]];
  }
  return result;
}

@end
