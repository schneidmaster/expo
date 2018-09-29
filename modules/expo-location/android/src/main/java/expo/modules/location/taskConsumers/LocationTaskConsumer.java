package expo.modules.location.taskConsumers;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.util.Log;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;

import expo.interfaces.taskManager.TaskConsumerInterface;
import expo.interfaces.taskManager.TaskInterface;
import expo.interfaces.taskManager.TaskManagerInterface;
import expo.modules.location.LocationModule;

public class LocationTaskConsumer implements TaskConsumerInterface, GoogleApiClient.ConnectionCallbacks, GoogleApiClient.OnConnectionFailedListener {
  private WeakReference<Context> mContextRef;
  private TaskInterface mTask;
  private GoogleApiClient mGoogleApiClient;
  private LocationRequest mLocationRequest;
  private TaskManagerInterface mTaskManager;
  private PendingIntent mPendingIntent;

  public LocationTaskConsumer(Context context, TaskManagerInterface taskManager) {
    mContextRef = new WeakReference<>(context);
    mTaskManager = taskManager;
  }

  public void onRegister(TaskInterface task) throws Exception {
    mTask = task;

    Context context = mContextRef.get();

    if (context == null) {
      throw new Exception("The context has been abandoned.");
    }

    prepareGoogleClient();
    prepareLocationRequest();
    preparePendingIntent();

    try {
      Log.i("EXPO", "Starting location updates");

      LocationServices
          .getFusedLocationProviderClient(context)
          .requestLocationUpdates(mLocationRequest, mPendingIntent);
    } catch (SecurityException e) {
      throw new Exception("Location request has been rejected.", e);
    }
  }

  public void onUnregister() throws Exception {
    if (mPendingIntent == null) {
      preparePendingIntent();
    }

    Context context = mContextRef.get();

    if (context == null) {
      throw new Exception("The context has been abandoned.");
    }

    LocationServices
        .getFusedLocationProviderClient(context)
        .removeLocationUpdates(mPendingIntent);
  }

  public void onHandleIntent(Intent intent) {
    Log.i("EXPO", "LocationTaskConsumer.onHandleIntent 1");

    if (mTask == null) {
      // TODO: execution failure
      return;
    }

    LocationResult result = LocationResult.extractResult(intent);

    Log.i("EXPO", "LocationTaskConsumer.onHandleIntent 2");

    if (result != null) {
      List<Location> locations = result.getLocations();
      ArrayList<Bundle> locationBundles = new ArrayList<>();
      Bundle data = new Bundle();

      for (Location location : locations) {
        Bundle locationBundle = LocationModule.locationToMap(location);
        locationBundles.add(locationBundle);
      }

      Log.i("EXPO", "LocationTaskConsumer.onHandleIntent 3");

      data.putParcelableArrayList("locations", locationBundles);
      mTask.executeWithData(data);

      Log.i("EXPO", "Executed background location task with intent...");
    }
  }

  // GoogleApiClient callbacks

  @Override
  public void onConnected(@Nullable Bundle bundle) {
    Log.i("EXPO", "Google API Client connected");
  }

  @Override
  public void onConnectionSuspended(int i) {
    Log.i("EXPO", "Google API Client connection suspended");
  }

  @Override
  public void onConnectionFailed(@NonNull ConnectionResult connectionResult) {
    Log.i("EXPO", "Google API Client connection failed");
  }

  // private

  private void prepareGoogleClient() {
    Context context = mContextRef.get();

    if (mGoogleApiClient != null || context == null) {
      return;
    }

    mGoogleApiClient = new GoogleApiClient.Builder(context)
        .addConnectionCallbacks(this)
        .addApi(LocationServices.API)
        .build();

    mGoogleApiClient.connect();
  }

  private void prepareLocationRequest() {
    mLocationRequest = new LocationRequest();
    mLocationRequest.setInterval(10 * 1000);
    mLocationRequest.setFastestInterval(5 * 1000);
    mLocationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
    mLocationRequest.setMaxWaitTime(30 * 1000);
  }

  private void preparePendingIntent() {
    if (mPendingIntent == null) {
      mPendingIntent = mTaskManager.createTaskIntent(mTask);
    }
  }
}
