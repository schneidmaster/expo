package expo.interfaces.taskManager;

import android.content.Intent;

public interface TaskConsumerInterface {
  void onRegister(TaskInterface task) throws Exception;
  void onUnregister() throws Exception;
  void onHandleIntent(Intent intent);
}
