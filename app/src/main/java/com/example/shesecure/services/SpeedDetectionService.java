package com.example.shesecure.services;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Build;
import android.os.CountDownTimer;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import androidx.core.app.NotificationCompat;

import com.example.shesecure.R;


public class SpeedDetectionService extends Service implements SensorEventListener {
    private SensorManager sensorManager;
    private Sensor accelerometerSensor;

    // Set your desired threshold speed here, i.e the speed threshold that triggers the pop-up menu
    private float thresholdSpeed = 0.1f;


    private long lastUpdate = 0;
    private float lastX = 0, lastY = 0, lastZ = 0;
    private static final float ALPHA = 0.8f;

    @Override
    public void onCreate() {
        super.onCreate();
        sensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        accelerometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        createNotificationChannel();
        startForegroundService();
        startSpeedDetection();
        return START_STICKY;
    }

    private void startForegroundService() {
        // Create a notification for the foreground service
        Notification notification = new NotificationCompat.Builder(this, "channelId")
                .setContentTitle("Speed Detection Service")
                .setContentText("Running in background")
                .setSmallIcon(R.drawable.ic_dot_selected)
                .build();

        // Start the service in the foreground
        startForeground(1, notification);
    }
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            String channelId = "channelId";
            String channelName = "Channel Name";
            int importance = NotificationManager.IMPORTANCE_DEFAULT;

            NotificationChannel channel = new NotificationChannel(channelId, channelName, importance);

            // Customize additional channel settings if needed
            channel.setDescription("Channel description");

            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
    }


    private void startSpeedDetection() {
        sensorManager.registerListener(this, accelerometerSensor, SensorManager.SENSOR_DELAY_NORMAL);
    }

    private float calculateSpeed(float x, float y, float z) {
        long currentTime = System.currentTimeMillis();
        float deltaTime = (currentTime - lastUpdate) / 1000.0f; // Convert time difference to seconds

        // Apply low-pass filter to reduce noise
        float filteredX = ALPHA * lastX + (1 - ALPHA) * x;
        float filteredY = ALPHA * lastY + (1 - ALPHA) * y;
        float filteredZ = ALPHA * lastZ + (1 - ALPHA) * z;

        // Calculate acceleration changes
        float deltaX = (filteredX - lastX);
        float deltaY = (filteredY - lastY);
        float deltaZ = (filteredZ - lastZ);

        // Update last values
        lastX = filteredX;
        lastY = filteredY;
        lastZ = filteredZ;
        lastUpdate = currentTime;

        // Calculate the total acceleration (excluding gravity)
        float acceleration = (float) Math.sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ);

        // Calculate speed using acceleration (ignoring direction)
        float speed = acceleration * deltaTime;

        return speed;
    }

    private void showToast(String message) {
        Handler handler = new Handler(Looper.getMainLooper());
        handler.post(new Runnable() {
            @Override
            public void run() {

                Toast.makeText(getApplicationContext(), message, Toast.LENGTH_SHORT).show();
                //MessageSender ms = new MessageSender(helper.getContacts(),message);
            }
        });
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
            float x = event.values[0];
            float y = event.values[1];
            float z = event.values[2];

            // Calculate the speed using accelerometer data
            float speed = calculateSpeed(x, y, z);

            // Check if speed exceeds the threshold
            if (speed >= thresholdSpeed) {
                //showToast("sent message!");
                showSpeedDetectionDialog();
            }
        }
    }

    private void showSpeedDetectionDialog() {
        Intent dialogIntent = new Intent("com.example.shesecure.SHOW_DIALOG");
        sendBroadcast(dialogIntent);
    }



    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
        // Not used in this example
    }

    @Override
    public IBinder onBind(Intent intent) {
        // This method is not used for started services
        return null;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        sensorManager.unregisterListener(this);
    }
}

