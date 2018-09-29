package expo.interfaces.taskManager;

import android.app.PendingIntent;
import android.os.Bundle;

import java.util.Map;

public interface TaskManagerInterface {
  PendingIntent createTaskIntent(TaskInterface task);
  void registerTask(String taskName, TaskConsumerInterface consumer, Map<String, Object> options) throws Exception;
  void unregisterTaskWithName(String taskName) throws Exception;

  void executeTaskWithData(TaskInterface task, Bundle data);
  void executeTaskWithError(TaskInterface task, Error error);
}
