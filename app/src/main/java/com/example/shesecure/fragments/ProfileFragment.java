package com.example.shesecure.fragments;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.Toast;

import androidx.fragment.app.Fragment;

import com.example.shesecure.activitypages.ChangePassEmailActivity;
import com.example.shesecure.activitypages.LoginActivity;
import com.example.shesecure.activitypages.ProfileActivity;
import com.example.shesecure.R;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;

public class ProfileFragment extends Fragment {

    public ProfileFragment() {
        // Required empty public constructor
    }


    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        View view = inflater.inflate(R.layout.fragment_profile, container, false);
        Button btn = view.findViewById(R.id.btnAddRem);
        Button btnEm = view.findViewById(R.id.btnEmailSettings);
        Button btnPas = view.findViewById(R.id.btnPas);
        Button btnLogout = view.findViewById(R.id.btnSet);

        btn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startActivity(new Intent(requireContext(), ProfileActivity.class));
            }
        });
        btnEm.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                    Intent intent = new Intent(requireContext(), ChangePassEmailActivity.class);
                    intent.putExtra("mode","email");
                    startActivity(intent);
            }
        });
        btnPas.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent intent = new Intent(requireContext(),ChangePassEmailActivity.class);
                intent.putExtra("mode","password");
                startActivity(intent);
            }
        });
        btnLogout.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                FirebaseAuth firebaseAuth = FirebaseAuth.getInstance();
                FirebaseUser currentUser = firebaseAuth.getCurrentUser();

                if (currentUser != null) {
                    currentUser.delete()
                            .addOnCompleteListener(task -> {
                                if (task.isSuccessful()) {
                                    Intent intent = new Intent(requireContext(), LoginActivity.class);
                                    startActivity(intent);
                                } else {
                                    // An error occurred while deleting the account
                                }
                            });
                }
            }
        });

        return view;
    }

    private void showToast(String buttonText) {
        Toast.makeText(getActivity(), buttonText, Toast.LENGTH_SHORT).show();
    }
}

