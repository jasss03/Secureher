package com.example.shesecure.fragments;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import android.telephony.SmsManager;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.Fragment;

import com.example.shesecure.R;
import com.example.shesecure.helper.SharedPreferenceHelper;

import java.util.ArrayList;
import java.util.Set;

public class PanicFragment extends Fragment {
    private static final int REQUEST_VIDEO_CAPTURE = 1;
    private static final int REQUEST_PERMISSIONS = 2;
    private static final String SHARED_PREFS_KEY = "MyContacts";

    private String videoFilePath;

    private Button startButton;
    private Button stopButton;

    private ArrayList<String> contacts;
    private Set<String> stringSet;




    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_panic, container, false);

        startButton = view.findViewById(R.id.startButton);
        stopButton = view.findViewById(R.id.stopButton);

        startButton.setOnClickListener(v -> startVideoRecording());
        stopButton.setOnClickListener(v -> stopVideoRecording());

        SharedPreferenceHelper sharedPreferenceHelper = new SharedPreferenceHelper(requireContext());
        contacts = sharedPreferenceHelper.getContacts();
        Log.i("contacts",contacts.toString());

        return view;
    }

    private void startVideoRecording() {
        if (ContextCompat.checkSelfPermission(requireContext(), Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED
                || ContextCompat.checkSelfPermission(requireContext(), Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(requireActivity(), new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO}, REQUEST_PERMISSIONS);
        } else {
            dispatchTakeVideoIntent();
        }
    }

    private void stopVideoRecording() {
        // Stop the video recording if needed
        // You can handle stopping the recording based on your requirements
        // For example, if you are using MediaStore.ACTION_VIDEO_CAPTURE, stopping may not be necessary

        // Check if videoFilePath is not null or empty
        if (videoFilePath != null && !videoFilePath.isEmpty()) {
            sendVideoToContacts();
        }
    }

    private void dispatchTakeVideoIntent() {
        Intent takeVideoIntent = new Intent(MediaStore.ACTION_VIDEO_CAPTURE);
        if (takeVideoIntent.resolveActivity(requireActivity().getPackageManager()) != null) {
            startActivityForResult(takeVideoIntent, REQUEST_VIDEO_CAPTURE);
        } else {
            Toast.makeText(requireContext(), "No app to handle video recording", Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQUEST_VIDEO_CAPTURE && resultCode == Activity.RESULT_OK) {
            Uri videoUri = data.getData();
            videoFilePath = videoUri.toString();
            Toast.makeText(requireContext(), "Video saved: " + videoFilePath, Toast.LENGTH_SHORT).show();
            sendVideoToContacts();

            // Check if videoFilePath is not null or empty
            if (videoFilePath != null && !videoFilePath.isEmpty()) {
                sendVideoToContacts();
            }
        } else {
            Toast.makeText(requireContext(), "Failed to record video", Toast.LENGTH_SHORT).show();
        }
    }

    private void sendVideoToContacts() {
        // Check if contacts list is not null or empty
        if (contacts != null && !contacts.isEmpty()) {
            for (String contact : contacts) {
                String[] namePhno = contact.split(":");
                String name = namePhno[0];
                String phno = namePhno[1];
                String message = "Hey " + name + ", check out this video!";
                sendSms(phno, message);
            }
        }
        else
            Toast.makeText(requireContext(), "empty contacts", Toast.LENGTH_SHORT).show();
    }

    private void sendSms(String phoneNumber, String message) {
        if (ContextCompat.checkSelfPermission(requireContext(), Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            SmsManager smsManager = SmsManager.getDefault();
            smsManager.sendTextMessage(phoneNumber, null, message, null, null);
            Toast.makeText(requireContext(), "Video sent to contacts", Toast.LENGTH_SHORT).show();

            // Create the intent
            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.putExtra("sms_body", message);
            intent.putExtra(Intent.EXTRA_STREAM, Uri.parse(videoFilePath));
            intent.setType("video/*");

            // Check if there is an app that can handle the intent
            if (intent.resolveActivity(requireActivity().getPackageManager()) != null) {
                startActivity(Intent.createChooser(intent, "Send video via"));
            } else {
                Toast.makeText(requireContext(), "No app to handle sending SMS", Toast.LENGTH_SHORT).show();
            }
        } else {
            ActivityCompat.requestPermissions(requireActivity(), new String[]{Manifest.permission.SEND_SMS}, REQUEST_PERMISSIONS);
        }
    }



    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQUEST_PERMISSIONS) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                sendVideoToContacts();
            } else {
                Toast.makeText(requireContext(), "SMS permission required", Toast.LENGTH_SHORT).show();
            }
        }
    }

}
