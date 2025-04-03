
# SheSecure
"She Secure" is a women's safety mobile application developed using Android Studio and Java. 
The app offers a range of unique features aimed at enhancing the safety of women.

## Key-Features

`Saved Contacts :` The app offers a dedicated section where users can add and manage phone numbers from their contacts as 
"Saved Contacts." These contacts are essential for the safety check-ins and emergency alert functionalities.

`Accelerometer :` The application utilizes an accelerometer to determine if the user is running or in a 
state of distress. If the app detects unusual activity, such as a sudden increase in movement, it 
automatically sends the user's location to their saved contacts. This feature ensures that help can 
be promptly dispatched if the user is unable to call for assistance.

`Safety-Tips :` The app offers valuable safety tips to educate users on various precautionary measures and best 
practices. This information serves as a resource to enhance personal safety and increase 
awareness of potential risks.

 `Panic Button :` It also incorporates video and audio recording capabilities, allowing users to capture 
evidence in case of emergencies. These recordings can be quickly shared with saved contacts, 
aiding in documenting incidents and seeking assistance.

`Alert Button :` The "She Secure" app includes an "Alert" button prominently displayed on the main interface. When the user presses
this button, the app instantly sends their current location's address to their saved contacts.



#### Testing on a Mobile Device:

If you plan to test the app on your mobile device, you might need to adjust the accelerometer threshold for speed detection. Follow these steps:

Locate the `SpeedDetectionService.java` file in the `services` directory.

Inside the `SpeedDetectionService` class, find the variable:

```
private float thresholdSpeed = 0.1f;
```
Adjust the value of `thresholdSpeed` to suit your needs. This threshold determines how sensitive the app is to detect unusual activities, such as 
running or distress.

`Note:` It is essential to set up the Google Maps API key and, if necessary, adjust the accelerometer threshold to ensure proper functionality of the 
"She Secure" application on your device.

I hope you find "She Secure" valuable in promoting women's safety and personal empowerment. Thank you for your interest and support!
