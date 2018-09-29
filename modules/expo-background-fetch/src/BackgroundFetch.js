import { NativeModulesProxy } from 'expo-core';
import { TaskManager } from 'expo-task-manager';

const { ExpoBackgroundFetch: BackgroundFetch } = NativeModulesProxy;

type BackgroundFetchStatus = 'restricted' | 'denied' | 'available';

type ResultEnum = {
  NO_DATA: string,
  NEW_DATA: string,
  FAILED: string,
};

type StatusEnum = {
  DENIED: string,
  RESTRICTED: string,
  AVAILABLE: string,
}

export const Result: ResultEnum = BackgroundFetch.Result;
export const Status: StatusEnum = BackgroundFetch.Status;

export async function getStatusAsync(): Promise<StatusEnum> {
  return BackgroundFetch.getStatusAsync();
}

export async function setMinimumIntervalAsync(minimumInterval: number): Promise<void> {
  return BackgroundFetch.setMinimumIntervalAsync(minimumInterval);
}

export async function registerTaskAsync(taskName: string): Promise<void> {
  if (!TaskManager.isTaskDefined(taskName)) {
    throw new Error(
      `Task '${taskName}' is not defined. You must define a task using TaskManager.defineTask before registering`
    );
  }
  return BackgroundFetch.registerTaskAsync(taskName);
}

export async function unregisterTaskAsync(taskName: string): Promise<void> {
  return BackgroundFetch.unregisterTaskAsync(taskName);
}
