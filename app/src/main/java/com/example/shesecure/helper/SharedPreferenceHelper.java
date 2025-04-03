package com.example.shesecure.helper;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

public class SharedPreferenceHelper {
    private static final String SHARED_PREFS_KEY = "MySharedPrefs";
    private static final String CONTACTS_KEY = "Contacts";

    private SharedPreferences sharedPreferences;

    public SharedPreferenceHelper(Context context) {
        sharedPreferences = context.getSharedPreferences(SHARED_PREFS_KEY, Context.MODE_PRIVATE);
    }

    public void addContact(String contact) {
        Set<String> contactSet = sharedPreferences.getStringSet(CONTACTS_KEY, new HashSet<>());
        contactSet.add(contact);
        sharedPreferences.edit().putStringSet(CONTACTS_KEY, contactSet).apply();
    }

    public void saveContacts(ArrayList<String> contacts) {
        Set<String> contactSet = new HashSet<>(contacts);
        sharedPreferences.edit().putStringSet(CONTACTS_KEY, contactSet).apply();
    }

    public ArrayList<String> getContacts() {
        Set<String> contactSet = sharedPreferences.getStringSet(CONTACTS_KEY, new HashSet<>());
        return new ArrayList<>(contactSet);
    }
}

