package com.example.shesecure.fragments;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.os.Bundle;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.fragment.app.Fragment;

import com.example.shesecure.helper.MessageSender;
import com.example.shesecure.models.Place;
import com.example.shesecure.R;
import com.example.shesecure.helper.SharedPreferenceHelper;
import com.example.shesecure.services.MyLocationService;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.SupportMapFragment;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class MapFragment extends Fragment implements OnMapReadyCallback {

    private static final int LOCATION_REQUEST_CODE = 1;
    private static final float NEARBY_DISTANCE_THRESHOLD = 1000; // in meters

    private GoogleMap googleMap;
    private FusedLocationProviderClient fusedLocationClient;
    private LocationRequest locationRequest;
    private LocationCallback locationCallback;
    private List<Place> placeList;
    private SharedPreferences sharedPreferences;
    private MessageSender messageSender;
    FloatingActionButton fab;

    private Marker currentLocationMarker;


    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_map, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        SupportMapFragment mapFragment = (SupportMapFragment) getChildFragmentManager().findFragmentById(R.id.map_fragment);
        if (mapFragment != null) {
            mapFragment.getMapAsync(this);
        }

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(requireContext());
        locationRequest = createLocationRequest();

        placeList = new ArrayList<>();
        sharedPreferences = requireContext().getSharedPreferences("MyPrefs", Context.MODE_PRIVATE);
        SharedPreferenceHelper helper = new SharedPreferenceHelper(requireContext());
        helper = new SharedPreferenceHelper(requireContext());
        fab = view.findViewById(R.id.sendMsg);

        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                // Handle the click event here, for example, start the location service
                startMyLocationService();

            }
        });

        setupLocationCallback();
    }


    private void startMyLocationService() {
        MyLocationService.LocationCallback myLocationCallback = new MyLocationService.LocationCallback() {
            @Override
            public void onLocationResult(String address) {
                // Handle the address here
                if (address != null) {
                    // The address is available, do something with it (e.g., send SMS)
                    Toast.makeText(requireContext(), "Current Address: " + address, Toast.LENGTH_SHORT).show();
                    SharedPreferenceHelper helper = new SharedPreferenceHelper(requireContext());
                    messageSender = new MessageSender(helper.getContacts(), "I reached near "+address);
                    // You can also use the MessageSender class here to send the address to contacts
                } else {
                    // Address is null, handle it accordingly
                    Toast.makeText(requireContext(), "Address not available", Toast.LENGTH_SHORT).show();
                }
            }
        };

        // Start the service using the activity context
        Intent serviceIntent = new Intent(requireContext(), MyLocationService.class);
        // Pass the callback to the service through the intent
        MyLocationService myLocationService = new MyLocationService();
        myLocationService.setLocationCallback(myLocationCallback);
        requireContext().startService(serviceIntent);
    }





    @Override
    public void onMapReady(GoogleMap googleMap) {
        this.googleMap = googleMap;
        SharedPreferenceHelper helper = new SharedPreferenceHelper(requireContext());
        enableMyLocation();
        addSavedPlaceMarkers();
        setMapLongClickListener();

    }


    private void enableMyLocation() {
        if (ActivityCompat.checkSelfPermission(requireContext(), Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(requireContext(), Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(requireActivity(), new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOCATION_REQUEST_CODE);
            return;
        }

        googleMap.setMyLocationEnabled(true);

        fusedLocationClient.getLastLocation().addOnSuccessListener(location -> {
            if (location != null) {
                addCurrentLocationMarker(location);
            }
        });

        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, null);
    }


    private void addCurrentLocationMarker(Location location) {
        LatLng currentLatLng = new LatLng(location.getLatitude(), location.getLongitude());

        if (currentLocationMarker != null) {
            currentLocationMarker.setPosition(currentLatLng); // Update the marker's position
        } else {
            // Add new marker with different color
            currentLocationMarker = googleMap.addMarker(new MarkerOptions()
                    .position(currentLatLng)
                    .title("Current Location")
                    .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_ROSE)));
        }

        googleMap.moveCamera(CameraUpdateFactory.newLatLngZoom(currentLatLng, 17f));
    }

    private void addSavedPlaceMarkers() {
        placeList = getPlaceListFromSharedPreferences();
        for (Place place : placeList) {
            googleMap.addMarker(new MarkerOptions().position(place.getLatLng()).title(place.getName()));
        }
    }

    private void setMapLongClickListener() {
        googleMap.setOnMapLongClickListener(latLng -> {
            // Handle the long click event here
            // Create a new Place object with the clicked LatLng coordinates
            String placeName = getPlaceNameFromCoordinates(latLng);
            Place newPlace = new Place(placeName, latLng);

            // Add the new place to the shared preferences
            addPlaceToSharedPreferences(newPlace);

            // Add the new place marker on the map
            googleMap.addMarker(new MarkerOptions().position(newPlace.getLatLng()).title(newPlace.getName()));

            // Show a toast indicating that the place is added
            Toast.makeText(requireContext(), "Place added: " + newPlace.getName(), Toast.LENGTH_SHORT).show();
        });
    }

    private String getPlaceNameFromCoordinates(LatLng latLng) {
        Geocoder geocoder = new Geocoder(requireContext(), Locale.getDefault());
        try {
            List<Address> addresses = geocoder.getFromLocation(latLng.latitude, latLng.longitude, 1);
            if (addresses.size() > 0) {
                Address address = addresses.get(0);
                return address.getAddressLine(0); // Adjust the address format as per your requirement
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
        return "Unknown Place";
    }

    private void setupLocationCallback() {
        locationCallback = new LocationCallback() {
            @Override
            public void onLocationResult(LocationResult locationResult) {
                if (locationResult == null) {
                    return;
                }

                Location lastLocation = locationResult.getLastLocation();
                addCurrentLocationMarker(lastLocation);
                checkNearbyPlaces(lastLocation);
            }
        };
    }

    private void checkNearbyPlaces(Location currentLocation) {
        List<Place> nearbyPlaces = new ArrayList<>();
        for (Place place : placeList) {
            float distance = currentLocation.distanceTo(place.getLocation());
            if (distance <= NEARBY_DISTANCE_THRESHOLD) {
                nearbyPlaces.add(place);
            }
        }

        for (Place nearbyPlace : nearbyPlaces) {
            SharedPreferenceHelper helper = new SharedPreferenceHelper(requireContext());
            messageSender = new MessageSender(helper.getContacts(), "I reached near "+nearbyPlace.getName());
            Toast.makeText(requireContext(), "You are near: " + nearbyPlace.getName(), Toast.LENGTH_SHORT).show();
            removePlaceFromSharedPreferences(nearbyPlace);
        }
    }

    private LocationRequest createLocationRequest() {
        LocationRequest locationRequest = new LocationRequest();
        locationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
        locationRequest.setInterval(5000);
        locationRequest.setFastestInterval(2000);
        locationRequest.setSmallestDisplacement(10); // Update location when the user moves at least 10 meters
        return locationRequest;
    }




    private void addPlaceToSharedPreferences(Place place) {
        placeList.add(place);
        savePlaceListToSharedPreferences();
    }

    private void removePlaceFromSharedPreferences(Place place) {
        placeList.remove(place);
        savePlaceListToSharedPreferences();
    }

    private List<Place> getPlaceListFromSharedPreferences() {
        String json = sharedPreferences.getString("placeList", "");
        if (!json.isEmpty()) {
            Gson gson = new Gson();
            return gson.fromJson(json, new TypeToken<List<Place>>() {}.getType());
        }
        return new ArrayList<>();
    }

    private void savePlaceListToSharedPreferences() {
        Gson gson = new Gson();
        String json = gson.toJson(placeList);
        sharedPreferences.edit().putString("placeList", json).apply();
    }

    @Override
    public void onResume() {
        super.onResume();
        startLocationUpdates();
    }

    @Override
    public void onPause() {
        super.onPause();
        stopLocationUpdates();
    }

    private void startLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(requireContext(), Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(requireContext(), Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return;
        }

        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper());
    }

    private void stopLocationUpdates() {
        fusedLocationClient.removeLocationUpdates(locationCallback);
    }
}
