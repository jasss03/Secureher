package com.example.shesecure.activitypages;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;

import com.example.shesecure.R;
import com.example.shesecure.services.SpeedDetectionService;

public class MainActivity extends AppCompatActivity {

    private static final long delay = 2000;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_loading);
        Intent serviceIntent = new Intent(this, SpeedDetectionService.class);
        ContextCompat.startForegroundService(this, serviceIntent);
        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                Intent intent = new Intent(MainActivity.this, WizardActivity.class);
                startActivity(intent);
                finish();
            }
        },delay);

    }
}