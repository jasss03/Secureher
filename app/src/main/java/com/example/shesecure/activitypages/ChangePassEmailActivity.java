package com.example.shesecure.activitypages;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.annotation.SuppressLint;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.widget.EditText;
import android.widget.Toast;

import com.example.shesecure.R;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.android.material.textfield.TextInputLayout;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.EmailAuthProvider;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;

public class ChangePassEmailActivity extends AppCompatActivity {

    TextInputLayout t1,t2,t3;
    String mode;
    EditText etM,etNewM;
    Drawable icon;
    Drawable icon1;

    public void changes(View view) {
        if(mode.equals("email")) {
            FirebaseUser user = FirebaseAuth.getInstance().getCurrentUser();

            if (user != null) {
                String currentEmail = t1.getEditText().getText().toString(); // Current email address
                String password = t3.getEditText().getText().toString(); // User's current password
                String newEmail = t2.getEditText().getText().toString(); // New email address
                if(currentEmail.equals(user.getEmail())) {
                    // Re-authenticate the user
                    AuthCredential credential = EmailAuthProvider.getCredential(currentEmail, password);

                    user.reauthenticate(credential)
                            .addOnCompleteListener(new OnCompleteListener<Void>() {
                                @Override
                                public void onComplete(@NonNull Task<Void> task) {
                                    if (task.isSuccessful()) {
                                        // User re-authenticated successfully
                                        // Proceed with updating the email address
                                        user.updateEmail(newEmail)
                                                .addOnCompleteListener(new OnCompleteListener<Void>() {
                                                    @Override
                                                    public void onComplete(@NonNull Task<Void> task) {
                                                        if (task.isSuccessful()) {
                                                            // Email address updated successfully
                                                            Toast.makeText(ChangePassEmailActivity.this, "Email address updated", Toast.LENGTH_SHORT).show();
                                                        } else {
                                                            // An error occurred while updating the email address
                                                            String errorMessage = task.getException().getMessage();
                                                            Toast.makeText(ChangePassEmailActivity.this, "Error: " + errorMessage, Toast.LENGTH_SHORT).show();
                                                        }
                                                    }
                                                });
                                    } else {
                                        // Re-authentication failed
                                        String errorMessage = task.getException().getMessage();
                                        Toast.makeText(ChangePassEmailActivity.this, "Error: " + errorMessage, Toast.LENGTH_SHORT).show();
                                    }
                                }
                            });
                }
            }
        }else if(mode.equals("password")) {
            // Make sure the user is signed in
            FirebaseUser user = FirebaseAuth.getInstance().getCurrentUser();

            if (user != null) {
                String currentEmail = user.getEmail(); // Current email address
                String currentPassword = t1.getEditText().getText().toString(); // User's current password
                String newPassword = t2.getEditText().getText().toString(); // New password

                // Re-authenticate the user
                AuthCredential credential = EmailAuthProvider.getCredential(currentEmail, currentPassword);

                user.reauthenticate(credential)
                        .addOnCompleteListener(new OnCompleteListener<Void>() {
                            @Override
                            public void onComplete(@NonNull Task<Void> task) {
                                if (task.isSuccessful()) {
                                    // User re-authenticated successfully
                                    // Proceed with updating the password
                                    user.updatePassword(newPassword)
                                            .addOnCompleteListener(new OnCompleteListener<Void>() {
                                                @Override
                                                public void onComplete(@NonNull Task<Void> task) {
                                                    if (task.isSuccessful()) {
                                                        // Password updated successfully
                                                        Toast.makeText(ChangePassEmailActivity.this, "Password updated", Toast.LENGTH_SHORT).show();
                                                    } else {
                                                        // An error occurred while updating the password
                                                        String errorMessage = task.getException().getMessage();
                                                        Toast.makeText(ChangePassEmailActivity.this, "Error: " + errorMessage, Toast.LENGTH_SHORT).show();
                                                    }
                                                }
                                            });
                                } else {
                                    // Re-authentication failed
                                    String errorMessage = task.getException().getMessage();
                                    Toast.makeText(ChangePassEmailActivity.this, "Error: " + errorMessage, Toast.LENGTH_SHORT).show();
                                }
                            }
                        });
            }
        }
    }

    @SuppressLint("MissingInflatedId")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_change_pass_email);
        mode = getIntent().getStringExtra("mode");
        t1 = findViewById(R.id.textInputLayout);
        t2 = findViewById(R.id.textInputLayout1);
        t3 = findViewById(R.id.textInputLayout2);
        etM = t1.getEditText();
        etNewM = t2.getEditText();

        icon = getResources().getDrawable(R.drawable.password);
        icon1 = getResources().getDrawable(R.drawable.mail);

        if(mode.equals("email")) {
            t1.setStartIconDrawable(icon1);
            t2.setStartIconDrawable(icon1);
            t1.setHint("Enter Previous Email");
            t2.setHint("Enter new Email");
            t3.setHint("Enter Password");
            etNewM.setInputType(InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);

        } else if (mode.equals("password")) {
            t1.setStartIconDrawable(icon);
            t2.setStartIconDrawable(icon);
            t1.setHint("Enter Previous Password");
            t2.setHint("Enter new Password");
            t3.setVisibility(View.INVISIBLE);
            etM.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);

        }else ;
    }
}