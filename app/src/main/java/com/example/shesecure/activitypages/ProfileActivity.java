package com.example.shesecure.activitypages;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import android.annotation.SuppressLint;
import android.content.DialogInterface;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.ContactsContract;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ImageView;
import android.widget.ListView;

import com.example.shesecure.R;
import com.example.shesecure.helper.SharedPreferenceHelper;
import com.google.android.material.floatingactionbutton.FloatingActionButton;

import java.util.ArrayList;

public class ProfileActivity extends AppCompatActivity {

    private static final int CONTACT_PICKER_REQUEST = 1;

    private ListView contactListView;
    static ArrayList<String> contactList;
    private ArrayAdapter<String> adapter;

    private FloatingActionButton addButton;
    private ImageView emptyImageView;

    private SharedPreferenceHelper sharedPreferenceHelper;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_profile);

        sharedPreferenceHelper = new SharedPreferenceHelper(this);

        contactListView = findViewById(R.id.contactListView);
        contactListView.setChoiceMode(ListView.CHOICE_MODE_MULTIPLE);
        emptyImageView = findViewById(R.id.ivEmptyContacts);
        contactList = new ArrayList<>();
        adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, contactList);
        contactListView.setAdapter(adapter);
        Log.i("contacts",sharedPreferenceHelper.getContacts().toString());
        addButton = findViewById(R.id.btnAddContacts);
        contactList.addAll(sharedPreferenceHelper.getContacts());
        adapter.notifyDataSetChanged();

        if (contactList.isEmpty()) {
            emptyImageView.setVisibility(View.VISIBLE);
        } else {
            emptyImageView.setVisibility(View.GONE);
        }

        addButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openContactsPicker();
            }
        });

        contactListView.setOnItemLongClickListener(new AdapterView.OnItemLongClickListener() {
            @Override
            public boolean onItemLongClick(AdapterView<?> parent, View view, int position, long id) {
                AlertDialog.Builder builder = new AlertDialog.Builder(ProfileActivity.this);
                builder.setIcon(android.R.drawable.ic_dialog_alert)
                        .setTitle("Are you sure?")
                        .setMessage("Do you want to delete this contact?")
                        .setPositiveButton("Yes", new DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(DialogInterface dialog, int which) {
                                contactList.remove(position);
                                adapter.notifyDataSetChanged();
                                sharedPreferenceHelper.saveContacts(contactList);
                                Log.i("contacts",sharedPreferenceHelper.getContacts().toString());
                                if (contactList.isEmpty()) {
                                    emptyImageView.setVisibility(View.VISIBLE);
                                } else {
                                    emptyImageView.setVisibility(View.GONE);
                                }
                            }
                        })
                        .setNegativeButton("No", null)
                        .show();

                return true;
            }
        });
    }

    private void openContactsPicker() {
        Intent intent = new Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI);
        startActivityForResult(intent, CONTACT_PICKER_REQUEST);
    }

    private void addContactToList(String name, String number) {
        String contact = name + " : " + number;
        contactList.add(contact);
        adapter.notifyDataSetChanged();

        // Save contacts to SharedPreferences
        sharedPreferenceHelper.addContact(contact);
        Log.i("contacts",sharedPreferenceHelper.getContacts().toString());
    }

    private void removeContactFromList(int position) {
        contactList.remove(position);
        adapter.notifyDataSetChanged();

        // Save contacts to SharedPreferences
        sharedPreferenceHelper.saveContacts(contactList);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == CONTACT_PICKER_REQUEST && resultCode == RESULT_OK) {
            Uri contactUri = data.getData();
            if (contactUri != null) {
                String[] projection = new String[]{ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER};
                Cursor cursor = getContentResolver().query(contactUri, projection, null, null, null);
                if (cursor != null && cursor.moveToFirst()) {
                    @SuppressLint("Range") String name = cursor.getString(cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME));
                    @SuppressLint("Range") String number = cursor.getString(cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER));
                    addContactToList(name, number);
                }
                if (cursor != null) {
                    cursor.close();
                }
            }
        }

        if (contactList.isEmpty()) {
            emptyImageView.setVisibility(View.VISIBLE);
        } else {
            emptyImageView.setVisibility(View.GONE);
        }
    }
}
