package com.example.shesecure.helper;

import android.telephony.SmsManager;

import java.util.ArrayList;

public class MessageSender {
    private ArrayList<String> phoneNumbers;
    private String message;

    public MessageSender(ArrayList<String> phoneNumbers,String message) {
        this.phoneNumbers = phoneNumbers;

        this.message = message;
        if (phoneNumbers != null && !phoneNumbers.isEmpty()) {
            for (String contact : phoneNumbers) {
                String[] namePhno = contact.split(":");
                String phno = namePhno[1];
                sendMessage(phno);
            }
        };
    }

    public void sendMessage(String phno) {
            SmsManager smsManager = SmsManager.getDefault();
            smsManager.sendTextMessage(phno, null, message, null, null);
    }
}
