package com.example.shesecure.services;

import android.Manifest;
import android.app.Service;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.os.Binder;
import android.os.IBinder;

import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;

import java.io.IOException;
import java.util.List;
import java.util.Locale;

public class MyLocationService extends Service {

    private static LocationCallback locationCallback;

    public interface LocationCallback {
        void onLocationResult(String address);
    }

    public static void setLocationCallback(LocationCallback callback) {
        locationCallback = callback;
    }



    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        getCurrentLocation();
        return START_NOT_STICKY;
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return new LocalBinder();
    }

    public void getCurrentLocation() {
        FusedLocationProviderClient fusedLocationClient = LocationServices.getFusedLocationProviderClient(this);

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            // Handle the case where permissions are not granted
            if (locationCallback != null) {
                locationCallback.onLocationResult("Permission not granted");
            }
            return;
        }

        fusedLocationClient.getLastLocation().addOnSuccessListener(location -> {
            if (location != null) {
                String address = getAddressFromLocation(location);
                if (locationCallback != null) {
                    locationCallback.onLocationResult(address);
                }
            } else {
                if (locationCallback != null) {
                    locationCallback.onLocationResult("Location not available");
                }
            }
        });
    }

    public class LocalBinder extends Binder {
        MyLocationService getService() {
            return MyLocationService.this;
        }
    }

    private String getAddressFromLocation(Location location) {
        Geocoder geocoder = new Geocoder(this, Locale.getDefault());
        try {
            List<Address> addresses = geocoder.getFromLocation(
                    location.getLatitude(),
                    location.getLongitude(),
                    1
            );

            if (addresses.size() > 0) {
                Address address = addresses.get(0);
                return address.getAddressLine(0); // Adjust the address format as per your requirement
            } else {
                return "Address not found";
            }
        } catch (IOException e) {
            e.printStackTrace();
            return "Error fetching address";
        }
    }
}
