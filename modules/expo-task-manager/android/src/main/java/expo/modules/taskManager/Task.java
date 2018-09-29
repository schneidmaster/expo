package expo.modules.taskManager;

import android.os.Bundle;

import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

import expo.interfaces.taskManager.TaskConsumerInterface;
import expo.interfaces.taskManager.TaskInterface;
import expo.interfaces.taskManager.TaskManagerInterface;

public class Task implements TaskInterface {
  private String mName;
  private TaskConsumerInterface mConsumer;
  private Map<String, Object> mOptions;
  private TaskManagerInterface mManager;

  public Task(String name, TaskConsumerInterface consumer, Map<String, Object> options, TaskManagerInterface manager) {
    mName = name;
    mConsumer = consumer;
    mOptions = options;
    mManager = manager;
  }

  public String getName() {
    return mName;
  }

  public TaskConsumerInterface getConsumer() {
    return mConsumer;
  }

  public Map<String, Object> getOptions() {
    return mOptions;
  }

  public String getActionConfig() {
    Map<String, String> data = new HashMap<>();
    data.put("appId", "appId");
    data.put("taskName", mName);
    return new JSONObject(data).toString();
  }

  public void executeWithData(Bundle data) {
    mManager.executeTaskWithData(this, data);
  }

  public void executeWithError(Error error) {
    mManager.executeTaskWithError(this, error);
  }
}
