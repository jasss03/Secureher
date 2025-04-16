
# DisasterResQ  
**"DisasterResQ"** is a mobile application developed using Android Studio and Java, designed to aid individuals during natural disasters by providing real-time alerts, emergency contact features, and intelligent distress detection.

## Key Features

`Trusted Contacts:` Users can add and manage a list of emergency contacts who will be notified during disaster events. These contacts receive real-time updates and alerts regarding the user's safety and location.

`Motion Detection (Accelerometer):` The app uses the phone's accelerometer to detect abnormal movements such as sudden shaking (earthquakes) or falls. When such motion is detected, the app automatically sends the user's live location to their trusted contacts, enabling a quicker response.

`Disaster Safety Tips:` The app offers essential disaster preparedness and response tips—covering events such as floods, earthquakes, cyclones, and more. These tips help users stay informed and ready before, during, and after a disaster.

`SOS Button:` Users can instantly activate an SOS feature that begins video and audio recording to document their surroundings. These recordings are automatically sent to trusted contacts to help them understand the situation and act accordingly.

`Emergency Alert Button:` A prominently placed button on the home screen allows users to quickly send their current location and a distress message to all their emergency contacts at the press of a button—ideal in moments when time is critical.

---

### Testing on a Mobile Device:

To effectively test motion detection on your mobile device, you might need to adjust the accelerometer sensitivity. Here's how:

Navigate to the `SpeedDetectionService.java` file located in the `services` directory.

Find and modify the variable:

```java
private float thresholdSpeed = 0.1f;
```

Tweak this value to fine-tune the app’s sensitivity in detecting sudden or disaster-related movements.

`Note:` Be sure to configure the **Google Maps API key** and properly calibrate the accelerometer threshold for the best experience with DisasterResQ.

---

**DisasterResQ** is a step toward building safer, more responsive communities during times of crisis. Thank you for supporting safety through technology!


