package com.example.shesecure.fragments;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.example.shesecure.R;

public class TipsFragment extends Fragment {

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        // Inflate the XML layout for the fragment
        View rootView = inflater.inflate(R.layout.fragment_tips, container, false);

        // Find and initialize any views or handle other operations related to the fragment

        return rootView;
    }

    // Rest of the fragment code
}
