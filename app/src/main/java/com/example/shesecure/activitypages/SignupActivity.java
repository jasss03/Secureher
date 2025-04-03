package com.example.shesecure.activitypages;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.EditText;
import android.widget.Toast;

import com.example.shesecure.R;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.auth.AuthResult;
import com.google.firebase.auth.FirebaseAuth;

public class SignupActivity extends AppCompatActivity {


    FirebaseAuth mAuth;
    EditText mail,pass,rePass;

    public void signup(View view) {
        String email = mail.getText().toString();
        String password = pass.getText().toString();
        String rePasswd = rePass.getText().toString();
        if(password.isEmpty() || rePasswd.isEmpty() || email.isEmpty())
            Toast.makeText(this, "Empty", Toast.LENGTH_SHORT).show();
        else if(password.equals(rePasswd)) {
            mAuth.createUserWithEmailAndPassword(email, password)
                    .addOnCompleteListener( new OnCompleteListener<AuthResult>() {
                        @Override
                        public void onComplete(@NonNull Task<AuthResult> task) {
                            if (task.isSuccessful()) {
                                Toast.makeText(SignupActivity.this, "Authentication successful!",
                                        Toast.LENGTH_SHORT).show();
                            } else {
                                // If sign in fails, display a message to the user.
                                Toast.makeText(SignupActivity.this, "Authentication failed.",
                                        Toast.LENGTH_SHORT).show();
                            }
                        }
                    });
        }
        else
            Toast.makeText(this, "Password doesn't match", Toast.LENGTH_SHORT).show();
    }

    public void linkpressed(View view) {
        Intent intent = new Intent(this, LoginActivity.class);
        startActivity(intent);
        finish();
    }
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_signup);
        mail = findViewById(R.id.etMail);
        pass = findViewById(R.id.etPassSignup);
        rePass = findViewById(R.id.etRePass);
        mAuth = FirebaseAuth.getInstance();
    }
}