package com.example.shesecure.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;

import androidx.fragment.app.Fragment;

import androidx.viewpager2.widget.ViewPager2;

import com.example.shesecure.activitypages.LoginActivity;
import com.example.shesecure.R;

public class WizardFragment1 extends Fragment {
    private Button btnNext,btnSkip;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_wizard1, container, false);
        btnNext = view.findViewById(R.id.btnNext1);
        btnSkip = view.findViewById(R.id.btnSkip1);

        btnNext.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                ViewPager2 viewPager = requireActivity().findViewById(R.id.viewPager);
                viewPager.setCurrentItem(1);
            }
        });
        btnSkip.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent intent = new Intent(getContext(), LoginActivity.class);
                startActivity(intent);
            }
        });

        return view;
    }
}

