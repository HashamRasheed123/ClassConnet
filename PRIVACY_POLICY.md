# Privacy Policy for Class Connect

**Effective Date:** October 21, 2026  
**Developer / Author:** Hasham Rasheed (Kzynovex)  
**Website:** [https://kzynovex.online](https://kzynovex.online)  
**Contact Email:** kzynovexinc@gmail.com  
**Application:** Class Connect (Academic Companion & Lecture Timetable Hub)

---

## 1. Introduction & Sole Educational Purpose
Class Connect is an academic utility application developed exclusively for educational purposes as a class project. It helps students track weekly lecture timetables, receive real-time schedule change alerts, and exchange verified study notes. 

We respect your privacy and are committed to maintaining the highest level of transparency regarding what information we collect and how it is used.

---

## 2. Information We Collect
We collect the absolute minimum data required to deliver core educational functionality:

1. **Google Account Information**:
   - **Full Name** & **Google Email**: Retrieved via official Google OAuth 2.0 when you sign in, used exclusively to create your student session and display your identity on class notes.
   - **Profile Photo (optional)**: Displayed locally in your student profile card.
2. **Academic Identifier (Roll Number)**:
   - Used solely to match students to their designated class cohort and prevent duplicate account creation.
3. **Academic Contributions**:
   - Study materials, lecture slides, or past exam documents that authorized students voluntarily upload to the Academic Vault.

We **DO NOT** collect:
- Financial or payment card information
- Precise GPS location data
- Personal contact lists, SMS, or call logs
- Ad-tracking or advertising identifiers

---

## 3. How We Use Your Information
Your information is strictly used for:
- Authenticating your identity through secure Google OAuth.
- Displaying your name and verified roll number on notes you contribute.
- Delivering lecture timetable notifications and room change notices.
- Distributing academic credits for peer-reviewed notes contributions.

We **NEVER** sell, rent, monetize, or share student data with third-party advertising brokers or data brokers.

---

## 4. Third-Party Service Providers
Class Connect relies solely on verified infrastructure to provide secure services:
- **Google Play Services & Google Sign-In**: Authentication & account validation.
- **Firebase Cloud Messaging (Google LLC)**: Encrypted push notifications for lecture alerts.
- **Supabase Inc.**: Secure cloud database with Row-Level Security (RLS) policies enforcing role-based permissions.

---

## 5. Device Permissions & Why We Need Them
Every permission requested by Class Connect serves a transparent educational purpose:

| Permission | Technical Name | Reason for Request |
| :--- | :--- | :--- |
| **Internet** | `INTERNET` | Connect to secure cloud database to sync lecture timetables and study notes. |
| **Notifications** | `POST_NOTIFICATIONS` | Send alerts 10 minutes before class starts and notify on room cancellations. |
| **Storage / Media** | `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` | Allow students to pick PDF slides or notes from their device to share with classmates. |
| **Camera (Optional)**| `CAMERA` | Allow students to take photos of whiteboards or handwritten notes to upload. |
| **Vibration** | `VIBRATE` | Haptic feedback and vibration when class alarm triggers. |

---

## 6. Strict Vault Content Policy
Users are strictly prohibited from uploading:
- Personal photos, private correspondence, or confidential documents.
- Defamatory, offensive, obscene, or harmful materials.
- Copyrighted textbooks or commercial publications without permission.

All uploads are submitted to an administrative moderation queue before being published to classmates.

---

## 7. Data Retention & Account Deletion
You retain ownership of your data at all times. If you wish to delete your student account, clear your contributions, or wipe your registry record, you may contact us at **kzynovexinc@gmail.com** or request deletion directly through your class administrator. All associated records will be permanently removed from Supabase and Firebase.

---

## 8. Developer Information
- **Brand / Studio:** Kzynovex
- **Author:** Hasham Rasheed
- **Official Portal:** [https://kzynovex.online](https://kzynovex.online)
- **Support:** kzynovexinc@gmail.com
