package expo.modules.taskManager;

import android.app.Application;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import expo.core.ExportedModule;
import expo.core.ModuleRegistry;
import expo.core.Promise;
import expo.core.interfaces.ExpoMethod;
import expo.core.interfaces.InternalModule;
import expo.core.interfaces.ModuleRegistryConsumer;
import expo.core.interfaces.services.EventEmitter;
import expo.interfaces.taskManager.TaskConsumerInterface;
import expo.interfaces.taskManager.TaskInterface;
import expo.interfaces.taskManager.TaskManagerInterface;
import expo.loaders.react.ReactNativeAppLoader;

public class TaskManager extends ExportedModule implements InternalModule, ModuleRegistryConsumer, TaskManagerInterface {

  private static String EVENT_NAME = "TaskManager.executeTask";
  private static String SHARED_PREFERENCES_NAME = "TaskManager";
  private static String INTENT_ACTION_PREFIX = "expo.modules.taskManager.";

  private static Map<String, Map<String, Task>> tasks = new HashMap<>();

  private EventEmitter mEventEmitter;

  public TaskManager(Context context) {
    super(context);
  }

  @Override
  public String getName() {
    return "TaskManager";
  }

  @Override
  public Map<String, Object> getConstants() {
    Map<String, Object> constants = new HashMap<>();
    constants.put("EVENT_NAME", EVENT_NAME);
    return constants;
  }

  @Override
  public List<Class> getExportedInterfaces() {
    return Arrays.<Class>asList(TaskManagerInterface.class);
  }

  @Override
  public void setModuleRegistry(ModuleRegistry moduleRegistry) {
    mEventEmitter = moduleRegistry.getModule(EventEmitter.class);
  }

  @ExpoMethod
  public void notifyTaskDidFinish(String taskName, final Promise promise) {
    promise.resolve(null);
  }

  // TaskManagerInterface

  public void registerTask(String taskName, TaskConsumerInterface consumer, Map<String, Object> options) throws Exception {
    Task task = new Task(taskName, consumer, options, this);

    Map<String, Task> appTasks = tasks.get("appId");

    if (appTasks == null) {
      appTasks = new HashMap<>();
      tasks.put("appId", appTasks);
    }

    appTasks.put(taskName, task);
    Log.i("EXPO", "Registered task with name " + taskName);

    consumer.onRegister(task);
  }

  public void unregisterTaskWithName(String taskName) throws Exception {
    Map<String, Task> appTasks = tasks.get("appId");

    if (appTasks != null) {
      Task task = appTasks.get(taskName);

      appTasks.remove(taskName);

      if (appTasks.size() == 0) {
        tasks.remove("appId");
      }

      if (task != null) {
        task.getConsumer().onUnregister();
      }
    }
  }

  public PendingIntent createTaskIntent(TaskInterface task) {
    String action = INTENT_ACTION_PREFIX + task.getActionConfig();
    Intent intent = new Intent(action, null, getContext(), TaskIntentService.class);
    return PendingIntent.getService(getContext(), action.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT);
  }

  @Override
  public void executeTaskWithData(TaskInterface task, Bundle data) {
    Bundle body = new Bundle();

    body.putString("taskName", task.getName());
    body.putBundle("data", data);

    mEventEmitter.emit(EVENT_NAME, body);
  }

  @Override
  public void executeTaskWithError(TaskInterface task, Error error) {
    Bundle body = new Bundle();
    Bundle errorBundle = new Bundle();

    errorBundle.putInt("code", error.hashCode());
    errorBundle.putString("message", error.getMessage());

    body.putString("taskName", task.getName());
    body.putBundle("error", errorBundle);

    mEventEmitter.emit(EVENT_NAME, body);
  }

  // EventEmitter

  public void startObserving() {
    // restore tasks
  }

  public void stopObserving() {}

  // statics

  public static SharedPreferences getSharedPreferences(Context context) {
    return context.getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE);
  }

  public static boolean hasTask(String appId, String taskName) {
    Map<String, Task> appTasks = tasks.get(appId);
    return appTasks != null && appTasks.containsKey(taskName);
  }

  public static void saveTasks(Context context, String appId) {
    SharedPreferences preferences = getSharedPreferences(context);
    Map<String, Task> appTasks = tasks.get(appId);
    Map<String, String> appConfig = new HashMap<>();

//    appConfig.put("bundleUrl", );

    for (String taskName : appTasks.keySet()) {
      Task task = appTasks.get(taskName);
      Map<String, String> taskConfig = new HashMap<>();

      taskConfig.put("consumerClass", task.getConsumer().getClass().getName());
      taskConfig.put("options", new JSONObject(task.getOptions()).toString());

      appConfig.put(taskName, new JSONObject(taskConfig).toString());
    }

    preferences
        .edit()
        .putString(appId, new JSONObject(appConfig).toString())
        .apply();
  }

  public static void maybeRestoreTasks(Context context, String appId) {
    SharedPreferences preferences = getSharedPreferences(context);
  }

  public static Task getTask(String appId, String taskName) {
    Map<String, Task> appTasks = tasks.get(appId);

    if (appTasks != null) {
      return appTasks.get(taskName);
    }
    return null;
  }

  public static void handleIntent(Application application, Intent intent) {
    String action = intent.getAction();

    if (!action.startsWith(INTENT_ACTION_PREFIX)) {
      // TODO: handle invalid action
      return;
    }

    Log.i("EXPO", "Handling intent with action: " + action);
    Log.i("EXPO", "Stringified action config: " + action.substring(INTENT_ACTION_PREFIX.length()));

    String appId;
    String taskName;

    try {
      // @tsapeta: Unfortunately, appId and taskName cannot be passed to the Intent as extras,
      // as there is a weird bug in PendingIntent that doesn't allow us to use extras.
      // As a workaround, we put these params to intent's action as a JSON string.
      // https://stackoverflow.com/questions/42028993/class-not-found-when-unmarshalling-com-google-android-gms-location-locationresu

      JSONObject json = new JSONObject(action.substring(INTENT_ACTION_PREFIX.length()));
      appId = json.getString("appId");
      taskName = json.getString("taskName");
    } catch (JSONException e) {
      // TODO: how to handle this JSON exception?
      return;
    }

    Log.i("EXPO", "Handling intent service with taskName " + taskName + " and appId " + appId);
    Log.i("EXPO", "TaskManager has this task registered: " + TaskManager.hasTask(appId, taskName));

    Task task = getTask(appId, taskName);
    TaskConsumerInterface consumer = task != null ? task.getConsumer() : null;

    if (consumer == null) {
      Log.i("EXPO", "Application package name: " + application.getPackageName());
      ReactNativeAppLoader.loadApplicationOnUiThread(application);

      // TODO: failure callback or rerun js app?
      Log.i("EXPO", "Task consumer not found");
      return;
    }

    // executes task
    consumer.onHandleIntent(intent);
  }
}
