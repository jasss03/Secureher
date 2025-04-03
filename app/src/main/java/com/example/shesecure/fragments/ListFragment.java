package com.example.shesecure.fragments;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.ListView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.example.shesecure.models.Place;
import com.example.shesecure.R;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import java.util.ArrayList;
import java.util.List;

public class ListFragment extends Fragment {

    private ListView listView;
    private List<Place> placeList;
    private SharedPreferences sharedPreferences;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_list, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        listView = view.findViewById(R.id.list_view);
        placeList = new ArrayList<>();
        sharedPreferences = requireContext().getSharedPreferences("MyPrefs", Context.MODE_PRIVATE);

        populateListView();
    }

    private void populateListView() {
        placeList = getPlaceListFromSharedPreferences();
        List<String> placeNames = new ArrayList<>();
        for (Place place : placeList) {
            placeNames.add(place.getName());
        }

        ArrayAdapter<String> adapter = new ArrayAdapter<>(requireContext(), android.R.layout.simple_list_item_1, placeNames);
        listView.setAdapter(adapter);
    }

    private List<Place> getPlaceListFromSharedPreferences() {
        String json = sharedPreferences.getString("placeList", "");
        if (!json.isEmpty()) {
            Gson gson = new Gson();
            return gson.fromJson(json, new TypeToken<List<Place>>() {}.getType());
        }
        return new ArrayList<>();
    }
}
