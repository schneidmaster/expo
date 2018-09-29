// Copyright 2018-present 650 Industries. All rights reserved.

#import <EXCore/EXDefines.h>

#import <EXTaskManager/EXTask.h>
#import <EXTaskManager/EXTaskService.h>
#import <EXTaskManagerInterface/EXTaskConsumerInterface.h>

#import <EXAppLoaderProvider/EXAppLoaderProvider.h>
#import <EXAppLoaderProvider/EXAppRecordInterface.h>

NSTimeInterval const EXAppLoaderDefaultTimeout = 10;

@interface EXTaskService ()

@property (nonatomic, strong) NSDictionary *launchOptions;
@property (nonatomic, strong) NSMutableArray<EXTaskExecutionRequest *> *requests;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, EXTask *> *> *tasks;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<EXAppRecordInterface>> *appRecords;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<EXTaskManagerInterface>> *taskManagers;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<NSDictionary *> *> *eventsQueues;

// Storing events per app. Schema: { "<appId>": [<eventIds...>] }
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *events;

@end

@implementation EXTaskService

EX_REGISTER_SINGLETON_MODULE(TaskService)

- (instancetype)init
{
  if (self = [super init]) {
    _tasks = [NSMutableDictionary new];
    _requests = [NSMutableArray new];
    _appRecords = [NSMutableDictionary new];
    _taskManagers = [NSMutableDictionary new];
    _eventsQueues = [NSMutableDictionary new];
    _events = [NSMutableDictionary new];

    [self restoreTasks];
  }
  return self;
}

- (void)dealloc
{
  NSLog(@"EXTaskManager: EXTaskService.dealloc");
}

+ (nonnull instancetype)sharedInstance
{
  static EXTaskService *service = nil;
  static dispatch_once_t once;

  dispatch_once(&once, ^{
    if (service == nil) {
      service = [[EXTaskService alloc] init];
    }
  });
  return service;
}

# pragma mark - EXTaskServiceInterface

/**
 *  Creates a new task, registers it and saves to the config stored in user defaults.
 *  It can throw an exception if given consumer class doesn't conform to EXTaskConsumerInterface protocol
 *  or another task with the same name and appId is already registered.
 */
- (void)registerTaskWithName:(NSString *)taskName
                       appId:(NSString *)appId
                      appUrl:(NSString *)appUrl
               consumerClass:(Class)consumerClass
                     options:(NSDictionary *)options
{
  // Given consumer class doesn't conform to EXTaskConsumerInterface protocol
  if (![consumerClass conformsToProtocol:@protocol(EXTaskConsumerInterface)]) {
    NSString *reason = @"Invalid `consumer` argument. It must be a class that conforms to EXTaskConsumerInterface protocol.";
    @throw [NSException exceptionWithName:@"E_INVALID_TASK_CONSUMER" reason:reason userInfo:nil];
  }

  // Task already registered
  if ([self getTaskWithName:taskName forAppId:appId] != nil) {
    NSString *reason = [NSString stringWithFormat:@"Task with name `%@` is already registered.", taskName];
    @throw [NSException exceptionWithName:@"E_TASK_ALREADY_EXISTS" reason:reason userInfo:nil];
  }

  EXTask *task = [self _internalRegisterTaskWithName:taskName
                                               appId:appId
                                              appUrl:appUrl
                                       consumerClass:consumerClass
                                             options:options];
  [self _addTaskToConfig:task];
}

/**
 *  Unregisters task with given name and for given appId. Also removes the task from the config.
 */
- (void)unregisterTaskWithName:(NSString *)taskName
                      forAppId:(NSString *)appId
               ofConsumerClass:(Class)consumerClass
{
  EXTask *task = (EXTask *)[self getTaskWithName:taskName forAppId:appId];

  if (consumerClass != nil && ![task.consumer isMemberOfClass:consumerClass]) {
    NSString *reason = [NSString stringWithFormat:@"Cannot unregister task with name '%@' because it is associated with different consumer class.", taskName];
    @throw [NSException exceptionWithName:@"E_INVALID_TASK_CONSUMER" reason:reason userInfo:nil];
  }

  NSLog(@"EXTaskManager: unregistering task %@", task.name);

  if (task) {
    NSMutableDictionary *appTasks = [[self getTasksForAppId:appId] mutableCopy];

    [appTasks removeObjectForKey:taskName];
    NSLog(@"EXTaskManager: unregistering task %@ %d", task.name, (int)appTasks.count);

    if (appTasks.count == 0) {
      [_tasks removeObjectForKey:appId];
    } else {
      [_tasks setObject:appTasks forKey:appId];
    }
    if (_tasks.count == 0) {
      [self _unregisterAppLifecycleNotifications];
    }

    if ([task.consumer respondsToSelector:@selector(didUnregister)]) {
      [task.consumer didUnregister];
    }
    [self _removeTaskFromConfig:task];
  }
}

/**
 *  Unregisters all tasks associated with the specific app.
 */
- (void)unregisterAllTasksForAppId:(NSString *)appId
{
  NSDictionary *appTasks = [_tasks objectForKey:appId];

  if (appTasks) {
    // Call `didUnregister` on task consumers
    for (EXTask *task in [appTasks allValues]) {
      if ([task.consumer respondsToSelector:@selector(didUnregister)]) {
        [task.consumer didUnregister];
      }
    }

    [_tasks removeObjectForKey:appId];

    // Maybe unregister app lifecycle notification?
    if (_tasks.count == 0) {
      [self _unregisterAppLifecycleNotifications];
    }

    // Remove the app from the config in user defaults.
    [self _removeFromConfigAppWithId:appId];
  }
}

- (BOOL)taskWithName:(NSString *)taskName
            forAppId:(NSString *)appId
  hasConsumerOfClass:(Class)consumerClass
{
  id<EXTaskInterface> task = [self getTaskWithName:taskName forAppId:appId];
  return task ? [task.consumer isMemberOfClass:consumerClass] : NO;
}

- (id<EXTaskInterface>)getTaskWithName:(NSString *)taskName
                              forAppId:(NSString *)appId
{
  return [[self getTasksForAppId:appId] objectForKey:taskName];
}

- (NSDictionary *)getTasksForAppId:(NSString *)appId
{
  return [_tasks objectForKey:appId];
}

- (NSDictionary *)getRestoredStateForAppId:(NSString *)appId
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *tasksConfig = [userDefaults dictionaryForKey:NSStringFromClass([self class])];
  NSLog(@"EXTaskService.getRestoredStateForAppId: %@, %@", NSStringFromClass([self class]), tasksConfig.description);
  return [[tasksConfig objectForKey:appId] objectForKey:@"tasks"];
}

- (void)notifyTaskWithName:(NSString *)taskName
                  forAppId:(NSString *)appId
     didFinishWithResponse:(NSDictionary *)response
{
  NSLog(@"EXTaskService got response from task %@ from app %@", taskName, appId);

  id<EXTaskInterface> task = [self getTaskWithName:taskName forAppId:appId];
  NSString *eventId = [response objectForKey:@"eventId"];
  id result = [response objectForKey:@"result"];

  if ([task.consumer respondsToSelector:@selector(normalizeTaskResult:)]) {
    result = [task.consumer normalizeTaskResult:result];
  }
  if ([task.consumer respondsToSelector:@selector(didFinish)]) {
    [task.consumer didFinish];
  }

  // Inform requests about finished tasks
  for (EXTaskExecutionRequest *request in _requests) {
    if ([request isIncludingTask:task]) {
      [request task:task didFinishWithResult:result];
    }
  }

  // Remove event and maybe invalidate related app record
  NSMutableArray *appEvents = [_events objectForKey:appId];

  if (appEvents) {
    [appEvents removeObject:eventId];

    if (appEvents.count == 0) {
      [self->_events removeObjectForKey:appId];

      // Invalidate app record but after 1 seconds delay
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"EXTaskService will invalidate app record");
        if (![self->_events objectForKey:appId]) {
          [self _invalidateAppWithId:appId];
        }
      });
    }
  }
}

- (void)maybeUpdateAppUrl:(NSString *)appUrl
                 forAppId:(NSString *)appId
{
  NSMutableDictionary *dict = [[self _dictionaryWithRegisteredTasks] mutableCopy];
  NSMutableDictionary *appDict = [[dict objectForKey:appId] mutableCopy];

  if (appDict != nil && ![[appDict objectForKey:@"appUrl"] isEqualToString:appUrl]) {
    [appDict setObject:appUrl forKey:@"appUrl"];
    [dict setObject:appDict forKey:appId];
    [self _saveConfigWithDictionary:dict];
  }
}

- (void)setOptions:(nonnull NSDictionary *)options
   forTaskWithName:(nonnull NSString *)taskName
          forAppId:(nonnull NSString *)appId
   ofConsumerClass:(Class)consumerClass
{
  id<EXTaskInterface> task = [self getTaskWithName:taskName forAppId:appId];

  // Task not found
  if (task == nil) {
    NSString *reason = [NSString stringWithFormat:@"Task with name '%@' doesn't exist.", taskName];
    @throw [NSException exceptionWithName:@"E_NO_TASK" reason:reason userInfo:nil];
  }

  // Task consumer mismatches with given consumer class
  if (consumerClass != nil && ![task.consumer isMemberOfClass:consumerClass]) {
    NSString *reason = [NSString stringWithFormat:@"Cannot update task with name '%@' because it is associated with different consumer class.", taskName];
    @throw [NSException exceptionWithName:@"E_INVALID_TASK_CONSUMER" reason:reason userInfo:nil];
  }

  // Set task's options
  [task setOptions:options];

  // Notify the consumer of the new options
  if ([task.consumer respondsToSelector:@selector(setOptions:)]) {
    [task.consumer setOptions:options];
  }
}

- (void)setTaskManager:(id<EXTaskManagerInterface>)taskManager forAppId:(NSString *)appId
{
  NSLog(@"EXTaskService: setTaskManager:forAppId");

  if (taskManager == nil) {
    [_taskManagers removeObjectForKey:appId];
  } else {
    [_taskManagers setObject:taskManager forKey:appId];

    NSLog(@"EXTaskService: setTaskManager:forAppId 2");
    
    NSMutableArray *appEventQueue = [_eventsQueues objectForKey:appId];

    if (appEventQueue) {
      for (NSDictionary *body in appEventQueue) {
        [taskManager executeWithBody:body];
      }
    }
  }
  [_eventsQueues removeObjectForKey:appId];
}

# pragma mark - EXTaskDelegate

- (void)executeTask:(nonnull id<EXTaskInterface>)task
           withData:(nullable NSDictionary *)data
          withError:(nullable NSError *)error
{
  NSLog(@"EXTaskService: executing task %@", task.name);

  id<EXTaskManagerInterface> taskManager = [_taskManagers objectForKey:task.appId];
  NSDictionary *executionInfo = [self _executionInfoForTask:task];
  NSDictionary *body = @{
                         @"executionInfo": executionInfo,
                         @"data": EXNullIfNil(data),
                         @"error": EXNullIfNil([self _exportError:error]),
                         };

  // Save an event so we can keep tracking events for this app
  NSMutableArray *appEvents = [_events objectForKey:task.appId] ?: [NSMutableArray new];
  [appEvents addObject:executionInfo[@"eventId"]];
  [_events setObject:appEvents forKey:task.appId];

  if (taskManager != nil) {
    // Task manager is initialized and can execute events
    [taskManager executeWithBody:body];
    return;
  }

  if ([_appRecords objectForKey:task.appId] == nil) {
    // No app record yet - let's spin it up!
    [self _loadAppWithId:task.appId appUrl:task.appUrl];
  }

  // App record for that app exists, but it's not fully loaded as its task manager is not there yet.
  // We need to add event's body to the queue from which events will be executed once the task manager is ready.
  NSMutableArray *appEventsQueue = [_eventsQueues objectForKey:task.appId] ?: [NSMutableArray new];
  [appEventsQueue addObject:body];
  [_eventsQueues setObject:appEventsQueue forKey:task.appId];
  return;
}

# pragma mark - Application lifecycle notifications

- (void)applicationWillResignActive
{
  [self _iterateTasksUsingBlock:^(EXTask *task) {
    if ([task.consumer respondsToSelector:@selector(applicationWillResignActive)]) {
      [task.consumer applicationWillResignActive];
    }
  }];
  NSLog(@"EXTaskManager: app backgrounded");
}

- (void)applicationDidBecomeActive
{
  [self _iterateTasksUsingBlock:^(EXTask *task) {
    if ([task.consumer respondsToSelector:@selector(applicationDidBecomeActive)]) {
      [task.consumer applicationDidBecomeActive];
    }
  }];
  NSLog(@"EXTaskManager: app foregrounded");
}

# pragma mark - statics

+ (BOOL)hasBackgroundModeEnabled:(nonnull NSString *)backgroundMode
{
  NSArray *backgroundModes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIBackgroundModes"];
  return backgroundModes != nil && [backgroundModes containsObject:backgroundMode];
}

# pragma mark - AppDelegate handlers

- (void)applicationDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  NSLog(@"EXTaskService applicationDidFinishLaunchingWithOptions");
}

- (void)runTasksWithReason:(EXTaskLaunchReason)launchReason
                  userInfo:(nullable NSDictionary *)userInfo
         completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
  [self _runTasksSupportingLaunchReason:launchReason userInfo:userInfo callback:^(NSArray * _Nonnull results) {
    BOOL wasCompletionCalled = NO;

    // Iterate through the array of results. If there is at least one "NewData" or "Failed" result,
    // then just call completionHandler immediately with that value, otherwise return "NoData".
    for (NSNumber *result in results) {
      UIBackgroundFetchResult fetchResult = [result intValue];

      if (fetchResult == UIBackgroundFetchResultNewData || fetchResult == UIBackgroundFetchResultFailed) {
        completionHandler(fetchResult);
        wasCompletionCalled = YES;
        break;
      }
    }
    if (!wasCompletionCalled) {
      completionHandler(UIBackgroundFetchResultNoData);
    }
    NSLog(@"EXTaskManager: completion handler called");
  }];
}

# pragma mark - internals

/**
 *  Internal method that creates a task and registers it. It doesn't save anything to user defaults!
 */
- (EXTask *)_internalRegisterTaskWithName:(nonnull NSString *)taskName
                                    appId:(nonnull NSString *)appId
                                   appUrl:(nonnull NSString *)appUrl
                            consumerClass:(Class)consumerClass
                                  options:(nullable NSDictionary *)options
{
  NSMutableDictionary *appTasks = [[self getTasksForAppId:appId] mutableCopy] ?: [NSMutableDictionary new];
  EXTask *task = [[EXTask alloc] initWithName:taskName
                                        appId:appId
                                       appUrl:appUrl
                                consumerClass:consumerClass
                                      options:options
                                     delegate:self];

  [appTasks setObject:task forKey:task.name];
  [_tasks setObject:appTasks forKey:appId];
  [task.consumer didReceiveTask:task];
  return task;
}

/**
 *  Modifies existing config of registered task with given task.
 */
- (void)_addTaskToConfig:(nonnull EXTask *)task
{
  NSMutableDictionary *dict = [[self _dictionaryWithRegisteredTasks] mutableCopy] ?: [NSMutableDictionary new];
  NSMutableDictionary *appDict = [[dict objectForKey:task.appId] mutableCopy] ?: [NSMutableDictionary new];
  NSMutableDictionary *tasks = [[appDict objectForKey:@"tasks"] mutableCopy] ?: [NSMutableDictionary new];
  NSDictionary *taskDict = [self _dictionaryFromTask:task];

  [tasks setObject:taskDict forKey:task.name];
  [appDict setObject:tasks forKey:@"tasks"];
  [appDict setObject:task.appUrl forKey:@"appUrl"];
  [dict setObject:appDict forKey:task.appId];
  [self _saveConfigWithDictionary:dict];
}

/**
 *  Removes given task from the config of registered tasks.
 */
- (void)_removeTaskFromConfig:(nonnull EXTask *)task
{
  NSMutableDictionary *dict = [[self _dictionaryWithRegisteredTasks] mutableCopy];
  NSMutableDictionary *appDict = [[dict objectForKey:task.appId] mutableCopy];
  NSMutableDictionary *tasks = [[appDict objectForKey:@"tasks"] mutableCopy];

  if (tasks != nil) {
    [tasks removeObjectForKey:task.name];

    if ([tasks count] > 0) {
      [appDict setObject:tasks forKey:@"tasks"];
      [dict setObject:appDict forKey:task.appId];
    } else {
      [dict removeObjectForKey:task.appId];
    }
    [self _saveConfigWithDictionary:dict];
  }
}

- (void)_removeFromConfigAppWithId:(nonnull NSString *)appId
{
  NSMutableDictionary *dict = [[self _dictionaryWithRegisteredTasks] mutableCopy];

  if ([dict objectForKey:appId]) {
    [dict removeObjectForKey:appId];
    [self _saveConfigWithDictionary:dict];
  }
}

/**
 *  Saves given dictionary to user defaults, as a config with registered tasks.
 */
- (void)_saveConfigWithDictionary:(nonnull NSDictionary *)dict
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setObject:dict forKey:NSStringFromClass([self class])];
  [userDefaults synchronize];
}

- (void)_registerAppLifecycleNotifications
{
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

  [notificationCenter addObserver:self
                         selector:@selector(applicationWillResignActive)
                             name:UIApplicationWillResignActiveNotification
                           object:nil];

  [notificationCenter addObserver:self
                         selector:@selector(applicationDidBecomeActive)
                             name:UIApplicationDidBecomeActiveNotification
                           object:nil];
}

- (void)_unregisterAppLifecycleNotifications
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_iterateTasksUsingBlock:(void(^)(id<EXTaskInterface> task))block
{
  for (NSString *appId in _tasks) {
    NSDictionary *appTasks = [self getTasksForAppId:appId];

    for (NSString *taskName in appTasks) {
      id<EXTaskInterface> task = [self getTaskWithName:taskName forAppId:appId];
      block(task);
    }
  }
}

- (BOOL)_tasksConfig:(nullable NSDictionary *)tasksConfig hasConsumerSupportingLaunchReason:(EXTaskLaunchReason)launchReason
{
  if (tasksConfig == nil || [tasksConfig count] == 0) {
    return NO;
  }
  for (NSString *taskName in tasksConfig) {
    NSDictionary *taskConfig = [tasksConfig objectForKey:taskName];
    NSString *consumerClassString = [taskConfig objectForKey:@"consumerClass"];
    NSLog(@"EXTaskManager checking task %@", taskName);
    if (consumerClassString != nil) {
      Class consumerClass = NSClassFromString(consumerClassString);

      if ([consumerClass respondsToSelector:@selector(supportsLaunchReason:)] && [consumerClass supportsLaunchReason:launchReason]) {
        return YES;
      }
    }
  }
  return NO;
}

/**
 *  Returns NSDictionary with registered tasks.
 *  Schema: {
 *    "<appId>": {
 *      "appUrl": "url to the bundle",
 *      "tasks": {
 *        "<taskName>": {
 *          "name": "task's name",
 *          "consumerClass": "name of consumer class, e.g. EXLocationTaskConsumer",
 *          "options": {},
 *        },
 *      }
 *    }
 *  }
 */
- (nullable NSDictionary *)_dictionaryWithRegisteredTasks
{
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  return [userDefaults dictionaryForKey:NSStringFromClass([self class])];
}

/**
 *  Returns NSDictionary representing single task.
 */
- (nullable NSDictionary *)_dictionaryFromTask:(EXTask *)task
{
  return @{
           @"name": task.name,
           @"consumerClass": NSStringFromClass([task.consumer class]),
           @"options": EXNullIfNil([task options]),
           };
}

- (void)_runTasksSupportingLaunchReason:(EXTaskLaunchReason)launchReason
                               userInfo:(nullable NSDictionary *)userInfo
                               callback:(void(^)(NSArray * _Nonnull results))callback
{
  __block EXTaskExecutionRequest *request;

  request = [[EXTaskExecutionRequest alloc] initWithCallback:^(NSArray * _Nonnull results) {
    NSLog(@"EXTaskManager: EXTaskExecutionRequest callback, results = %@", results.description);

    if (callback != nil) {
      callback(results);
    }

    [self->_requests removeObject:request];
    request = nil;
  }];

  [_requests addObject:request];

  [self _iterateTasksUsingBlock:^(id<EXTaskInterface> task) {
    if ([task.consumer.class supportsLaunchReason:launchReason]) {
      [self _addTask:task toRequest:request];
    }
  }];

  [request maybeEvaluate];
}

- (void)_loadAppWithId:(nonnull NSString *)appId
                appUrl:(nonnull NSString *)appUrl
{
  id<EXAppLoaderInterface> appLoader = [[EXAppLoaderProvider sharedInstance] createAppLoader];

  if (appLoader != nil && appUrl != nil) {
    __block id<EXAppRecordInterface> appRecord;
    NSDictionary *options = @{ @"timeout": @(EXAppLoaderDefaultTimeout) };

    NSLog(@"EXTaskManager: loading app with id %@ and appUrl %@", appId, appUrl);

    appRecord = [appLoader loadAppWithUrl:appUrl options:options callback:^(BOOL success, NSError *error) {
      NSLog(@"EXTaskManager: App record with appId %@ has been loaded with success = %d", appId, success);

      if (success) {
        // cool!
        NSLog(@"EXTaskService: cool, app is loaded!");
      } else {
        [self->_events removeObjectForKey:appId];
        [self->_eventsQueues removeObjectForKey:appId];
        [self->_appRecords removeObjectForKey:appId];
      }
    }];

    [_appRecords setObject:appRecord forKey:appId];
  }
}

- (void)restoreTasks
{
  NSDictionary *config = [self _dictionaryWithRegisteredTasks];
  NSLog(@"EXTaskService: restoring config %@", config.description);

  for (NSString *appId in config) {
    NSDictionary *appConfig = [config objectForKey:appId];
    NSDictionary *tasksConfig = [appConfig objectForKey:@"tasks"];
    NSString *appUrl = [appConfig objectForKey:@"appUrl"];

    for (NSString *taskName in tasksConfig) {
      NSDictionary *taskConfig = [tasksConfig objectForKey:taskName];
      NSDictionary *options = [taskConfig objectForKey:@"options"];
      Class consumerClass = NSClassFromString([taskConfig objectForKey:@"consumerClass"]);

      if (consumerClass != nil) {
        [self _internalRegisterTaskWithName:taskName
                                      appId:appId
                                     appUrl:appUrl
                              consumerClass:consumerClass
                                    options:options];
      } else {
        EXLogWarn(@"EXTaskManager: Cannot restore task '%@' because consumer class doesn't exist.", taskName);
      }
    }
  }
}

- (void)_addTask:(id<EXTaskInterface>)task toRequest:(EXTaskExecutionRequest *)request
{
  [request addTask:task];

  // Inform the consumer that the task can be executed from then on.
  // Some types of background tasks (like background fetch) may execute the task immediately.
  if ([[task consumer] respondsToSelector:@selector(didBecomeReadyToExecute)]) {
    [[task consumer] didBecomeReadyToExecute];
  }
}

- (NSDictionary *)_executionInfoForTask:(nonnull id<EXTaskInterface>)task
{
  NSString *appState = [self _exportAppState:[[UIApplication sharedApplication] applicationState]];
  return @{
           @"eventId": [[NSUUID UUID] UUIDString],
           @"taskName": task.name,
           @"appState": appState,
           };
}

- (void)_invalidateAppWithId:(NSString *)appId
{
  NSLog(@"EXTaskService invalidating app with appId = %@", appId);
  id<EXAppRecordInterface> appRecord = [_appRecords objectForKey:appId];

  if (appRecord) {
    [appRecord invalidate];
    [_appRecords removeObjectForKey:appId];
    [_taskManagers removeObjectForKey:appId];
  }
}

- (nullable NSDictionary *)_exportError:(nullable NSError *)error
{
  if (error == nil) {
    return nil;
  }
  return @{
           @"code": @(error.code),
           @"message": error.localizedFailureReason,
           };
}

- (EXTaskLaunchReason)_launchReasonForLaunchOptions:(nullable NSDictionary *)launchOptions
{
  if (launchOptions == nil) {
    return EXTaskLaunchReasonUser;
  }
  if (launchOptions[UIApplicationLaunchOptionsBluetoothCentralsKey]) {
    return EXTaskLaunchReasonBluetoothCentrals;
  }
  if (launchOptions[UIApplicationLaunchOptionsBluetoothPeripheralsKey]) {
    return EXTaskLaunchReasonBluetoothPeripherals;
  }
  if (launchOptions[UIApplicationLaunchOptionsLocationKey]) {
    return EXTaskLaunchReasonLocation;
  }
  if (launchOptions[UIApplicationLaunchOptionsNewsstandDownloadsKey]) {
    return EXTaskLaunchReasonNewsstandDownloads;
  }
  if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
    return EXTaskLaunchReasonRemoteNotification;
  }
  return EXTaskLaunchReasonUnrecognized;
}

- (NSString *)_exportAppState:(UIApplicationState)appState
{
  switch (appState) {
    case UIApplicationStateActive:
      return @"active";
    case UIApplicationStateInactive:
      return @"inactive";
    case UIApplicationStateBackground:
      return @"background";
  }
}

@end
