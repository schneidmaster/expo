package expo.interfaces.taskManager;

import android.os.Bundle;

public interface TaskInterface {
  String getName();
  String getActionConfig();

  void executeWithData(Bundle data);
  void executeWithError(Error error);
}
