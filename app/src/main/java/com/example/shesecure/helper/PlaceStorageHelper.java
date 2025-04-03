package com.example.shesecure.helper;

import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;

import com.example.shesecure.models.Place;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;

public class PlaceStorageHelper {
    private static final String PREF_NAME = "MyPlaces";
    private static final String KEY_PLACE_LIST = "placeList";

    public static void savePlaces(Context context, List<Place> places) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        String placeListJson = new Gson().toJson(places);
        editor.putString(KEY_PLACE_LIST, placeListJson);
        editor.apply();
    }

    public static List<Place> getPlaces(Context context) {
        SharedPreferences sharedPreferences = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
        String placeListJson = sharedPreferences.getString(KEY_PLACE_LIST, "");
        List<Place> places = new ArrayList<>();
        if (!TextUtils.isEmpty(placeListJson)) {
            Type type = new TypeToken<List<Place>>() {}.getType();
            places = new Gson().fromJson(placeListJson, type);
        }
        return places;
    }
}
