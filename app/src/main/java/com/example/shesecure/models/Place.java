package com.example.shesecure.models;

import android.location.Location;
import android.location.LocationManager;

import com.google.android.gms.maps.model.LatLng;

public class Place {
    private String name;
    private LatLng latLng;
    private Location location;
    private boolean nearby;

    public Place(String name, LatLng latLng) {
        this.name = name;
        this.latLng = latLng;
        location = new Location(LocationManager.GPS_PROVIDER);
        location.setLatitude(latLng.latitude);
        location.setLongitude(latLng.longitude);
    }

    public String getName() {
        return name;
    }

    public Location getLocation() {
        return location;
    }

    public LatLng getLatLng() {
        return latLng;
    }

    @Override
    public String toString() {
        return name;
    }
    public boolean isNearby() {
        return nearby;
    }

    public void setNearby(boolean nearby) {
        this.nearby = nearby;
    }
}
