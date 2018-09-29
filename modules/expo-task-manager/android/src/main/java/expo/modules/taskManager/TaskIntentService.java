package expo.modules.taskManager;

import android.app.IntentService;
import android.content.Intent;
import android.util.Log;

public class TaskIntentService extends IntentService {

  public TaskIntentService() {
    super("TaskIntentService");
  }

  @Override
  protected void onHandleIntent(Intent intent) {
    Log.i("EXPO", "TaskIntentService is being handled... :)");

    if (intent == null) {
      return;
    }

    Log.i("EXPO", "TaskIntentService, action = " + intent.getAction());

    TaskManager.handleIntent(getApplication(), intent);
  }
}
