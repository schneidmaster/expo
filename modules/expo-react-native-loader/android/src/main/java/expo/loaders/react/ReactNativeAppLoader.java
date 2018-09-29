package expo.loaders.react;

import android.app.Application;
import android.content.Context;
import android.util.Log;

import com.facebook.react.ReactApplication;
import com.facebook.react.ReactInstanceManager;
import com.facebook.react.ReactNativeHost;
import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.ReactContext;

import java.lang.ref.WeakReference;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.List;

import expo.core.ModuleRegistry;
import expo.core.interfaces.AppLoaderInterface;
import expo.core.interfaces.InternalModule;
import expo.core.interfaces.ModuleRegistryConsumer;
import expo.core.interfaces.services.UIManager;

public class ReactNativeAppLoader implements InternalModule, ModuleRegistryConsumer, AppLoaderInterface {
  private WeakReference<Context> mContextRef;
  private UIManager uiManager;

  public ReactNativeAppLoader(Context context) {
    mContextRef = new WeakReference<>(context);
  }

  @Override
  public void setModuleRegistry(ModuleRegistry moduleRegistry) {
    uiManager = moduleRegistry.getModule(UIManager.class);
  }

  @Override
  public List<Class> getExportedInterfaces() {
    return Arrays.<Class>asList(AppLoaderInterface.class);
  }

  public void loadApplication(String bundleUrl) {
    uiManager.runOnUiQueueThread(new Runnable() {
      @Override
      public void run() {
        ReactApplication appContext = (ReactApplication) mContextRef.get().getApplicationContext();
        loadApplication((Application) appContext, bundleUrl);
      }
    });
  }

  // statics

  public static AppRecord loadApplication(Application application, String bundleUrl) {
    ReactApplication appContext = (ReactApplication) application;
    ReactNativeHost reactNativeHost = appContext.getReactNativeHost();
    Class reactNativeHostClass = reactNativeHost.getClass();

    try {
      Method getPackagesMethod = reactNativeHostClass.getDeclaredMethod("getPackages");
      List<ReactPackage> packages = (List<ReactPackage>) getPackagesMethod.invoke(reactNativeHost);

      Log.i("EXPO", "Got packages from MainApplication");

      final ReactInstanceManager reactInstanceManager = reactNativeHost.getReactInstanceManager();

      reactInstanceManager.addReactInstanceEventListener(new ReactInstanceManager.ReactInstanceEventListener() {
        @Override
        public void onReactContextInitialized(ReactContext reactContext) {
          reactInstanceManager.removeReactInstanceEventListener(this);
        }
      });

      if (!reactInstanceManager.hasStartedCreatingInitialContext()) {
        reactInstanceManager.createReactContextInBackground();
      }
    } catch (Exception e) {
      // TODO: handle exceptions
    }
    return null;
  }
}
