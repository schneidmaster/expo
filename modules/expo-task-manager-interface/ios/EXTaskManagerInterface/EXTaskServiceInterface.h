// Copyright 2015-present 650 Industries. All rights reserved.

#import <EXTaskManagerInterface/EXTaskInterface.h>

@protocol EXTaskServiceInterface

/**
 *  Registers task in any kind of persistent storage, so it could be restored in future sessions.
 */
- (void)registerTaskWithName:(nonnull NSString *)taskName
                       appId:(nonnull NSString *)appId
                      appUrl:(nonnull NSString *)appUrl
               consumerClass:(Class)consumerClass
                     options:(nullable NSDictionary *)options;

/**
 *  Unregisters task with given name and for given appId. If consumer class is provided,
 *  it can throw an exception if task's consumer is not a member of that class.
 */
- (void)unregisterTaskWithName:(nonnull NSString *)taskName
                      forAppId:(nonnull NSString *)appId
               ofConsumerClass:(Class)consumerClass;

/**
 *  Unregisters all tasks registered for the app with given appId.
 */
- (void)unregisterAllTasksForAppId:(nonnull NSString *)appId;

/**
 *  Returns boolean value whether or not the task's consumer is a member of given class.
 */
- (BOOL)taskWithName:(nonnull NSString *)taskName
            forAppId:(nonnull NSString *)appId
  hasConsumerOfClass:(Class)consumerClass;

/**
 *  Returns task object with given taskName and for given appId.
 */
- (nullable id<EXTaskInterface>)getTaskWithName:(nonnull NSString *)taskName
                                       forAppId:(nonnull NSString *)appId;

/**
 *  Returns dictionary of tasks for given appId. Dictionary in which the keys are the names for tasks,
 *  while the values are the task objects.
 */
- (nonnull NSDictionary *)getTasksForAppId:(nonnull NSString *)appId;

/**
 *  Returns tasks configuration for given appId, that have been saved to the persistent storage.
 */
- (nullable NSDictionary *)getRestoredStateForAppId:(nonnull NSString *)appId;

/**
 *  Notifies the service that a task has just finished.
 */
- (void)notifyTaskWithName:(nonnull NSString *)taskName
                  forAppId:(nonnull NSString *)appId
     didFinishWithResponse:(nonnull NSDictionary *)response;

/**
 *  Updates appUrl for the app with given appId if necessary.
 *  Url to the app might change over time, especially in development.
 */
- (void)maybeUpdateAppUrl:(nonnull NSString *)appUrl forAppId:(nonnull NSString *)appId;

/**
 *  Updates task's options and notifies the consumer.
 *  Can throw an exception if there is no task with given name or its consumer class is incompatible.
 */
- (void)setOptions:(nonnull NSDictionary *)options
   forTaskWithName:(nonnull NSString *)taskName
          forAppId:(nonnull NSString *)appId
   ofConsumerClass:(Class)consumerClass;

/**
 *  Passes a reference of task manager for given appId to the service.
 */
- (void)setTaskManager:(nullable id<EXTaskManagerInterface>)taskManager forAppId:(nonnull NSString *)appId;

@end
