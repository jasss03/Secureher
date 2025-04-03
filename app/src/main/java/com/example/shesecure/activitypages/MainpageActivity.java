package com.example.shesecure.activitypages;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.os.CountDownTimer;
import android.widget.Toast;

import com.example.shesecure.R;
import com.example.shesecure.fragments.PanicFragment;
import com.example.shesecure.fragments.ProfileFragment;
import com.example.shesecure.fragments.TabFragment;
import com.example.shesecure.fragments.TipsFragment;
import com.example.shesecure.helper.MessageSender;
import com.example.shesecure.helper.SharedPreferenceHelper;
import com.example.shesecure.services.MyLocationService;
import com.example.shesecure.services.SpeedDetectionService;
import com.google.android.material.bottomnavigation.BottomNavigationView;

public class MainpageActivity extends AppCompatActivity {

    BottomNavigationView bnv;
    FragmentManager fragmentManager;
    private AlertDialog speedDialog;
    private CountDownTimer dialogTimer;

    SharedPreferenceHelper helper;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_mainpage);

        bnv = findViewById(R.id.bottomNavBar);
        fragmentManager = getSupportFragmentManager();
        helper = new SharedPreferenceHelper(getApplicationContext());


        IntentFilter filter = new IntentFilter("com.example.shesecure.SHOW_DIALOG");
        registerReceiver(speedDialogReceiver, filter);


        showFragment(new TipsFragment());

        bnv.setOnItemSelectedListener(item -> {
            switch (item.getItemId()){
                case R.id.bottom_panic:
                    showFragment(new PanicFragment());
                    return true;
                case R.id.bottom_location:
                    showFragment(new TabFragment());
                    return true;
                case R.id.bottom_tips:
                    showFragment(new TipsFragment());
                    return true;
                case R.id.bottom_profile:
                    showFragment(new ProfileFragment());
                    return true;
            }
            return false;
        });
    }
    private void showFragment(Fragment fragment) {
        fragmentManager.beginTransaction()
                .replace(R.id.fragmentContainer, fragment)
                .commit();
    }
    @Override
    protected void onDestroy() {
        super.onDestroy();

        // Stop the SpeedDetectionService when the app is closed
        Intent serviceIntent = new Intent(this, SpeedDetectionService.class);
        stopService(serviceIntent);
        unregisterReceiver(speedDialogReceiver);
        if (dialogTimer != null) {
            dialogTimer.cancel();
        }

    }

    private final BroadcastReceiver speedDialogReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            showSpeedDetectionDialog();
        }
    };


    private void startMyLocationService() {
        MyLocationService.LocationCallback myLocationCallback = new MyLocationService.LocationCallback() {
            @Override
            public void onLocationResult(String address) {
                // Handle the address here
                if (address != null) {
                    // The address is available, do something with it (e.g., send SMS)
                    Toast.makeText(getApplicationContext(), "Current Address: " + address, Toast.LENGTH_SHORT).show();
                    SharedPreferenceHelper helper = new SharedPreferenceHelper(getApplicationContext());
                    MessageSender messageSender = new MessageSender(helper.getContacts(), "I'm in "+address);
                    // You can also use the MessageSender class here to send the address to contacts
                } else {
                    // Address is null, handle it accordingly
                    Toast.makeText(getApplicationContext(), "Address not available", Toast.LENGTH_SHORT).show();
                }
            }
        };

        // Start the service using the activity context
        Intent serviceIntent = new Intent(getApplicationContext(), MyLocationService.class);
        // Pass the callback to the service through the intent
        MyLocationService myLocationService = new MyLocationService();
        myLocationService.setLocationCallback(myLocationCallback);
        getApplicationContext().startService(serviceIntent);
    }

    private void showSpeedDetectionDialog() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Confirmation");
        builder.setMessage("Are you safe ?");
        builder.setPositiveButton("Yes", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                // Do nothing if "Yes" is clicked
            }
        });
        builder.setNegativeButton("No", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                Toast.makeText(MainpageActivity.this, "sent message!", Toast.LENGTH_SHORT).show();
                startMyLocationService();
            }
        });

        speedDialog = builder.create();
        speedDialog.show();

        dialogTimer = new CountDownTimer(5000, 1000) {
            @Override
            public void onTick(long millisUntilFinished) {
                // Do nothing during the countdown
            }

            @Override
            public void onFinish() {
                if (speedDialog != null && speedDialog.isShowing()) {
                    Toast.makeText(MainpageActivity.this, "sent message!", Toast.LENGTH_SHORT).show();
                    MessageSender ms = new MessageSender(helper.getContacts(),"reached");
                    speedDialog.dismiss();
                }
            }
        }.start();
    }
}