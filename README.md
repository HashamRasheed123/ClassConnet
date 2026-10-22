# 🎓 ClassConnect (softwareclass)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase)](https://supabase.com)
[![License](https://img.shields.io/badge/License-Proprietary-blue.svg)](PRIVACY_POLICY.md)

**ClassConnect** is a comprehensive, production-grade Flutter university class companion application designed for modern university cohorts. It unifies daily timetable management, real-time schedule overrides, a community-driven lecture notes vault with Google Drive integration, assignment tracking with auto-generated submission PDFs, and role-based student and administrator workflows.

---

## 📑 Table of Contents
1. [Core Features](#-core-features)
2. [Architecture & Security](#-architecture--security)
3. [Quick Start Guide](#-quick-start-guide)
4. [Supabase Setup Guide (Zero to Ready in 5 Minutes)](#-supabase-setup-guide)
5. [Environment Configuration](#-environment-configuration)
6. [Running & Building](#-running--building)
7. [Database Schema Reference](#-database-schema-reference)
8. [Testing](#-testing)

---

## ✨ Core Features

- 📅 **Dynamic Timetable & Schedule Overrides**: View weekly lecture schedules and real-time class cancellations, room changes, and rescheduling submitted by class reps or administrators.
- 📚 **Resource Vault**: Upload, browse, upvote, and download verified lecture notes, slides, and past papers (supports PDF, images, and YouTube links) backed by Supabase Storage.
- ✅ **Assignment Tracker & PDF Scanner**: Keep track of pending assignment deadlines, generate formatted university-standard assignment cover pages, and export submission-ready PDFs.
- 🔒 **Dual Authentication**: 
  - Student Roll Number + Security PIN login with offline local caching.
  - Google Sign-In with automated designated administrator role assignment.
- 🛠️ **Administrator Console**: Full in-app control over subjects, daily timetable overrides, verified student registries, content moderation queues, and master passkey management.
- ⚡ **Offline-First Resilience**: All critical schedules and user profiles are cached locally via `SharedPreferences`, enabling seamless startup even without network access.

---

## 🔒 Architecture & Security

- **Compile-Time Secret Injection**: API keys, admin accounts, and passwords are provided via `--dart-define-from-file` using `.env` or `env.json`. No secrets or credentials are ever committed to version control.
- **Strict Row Level Security (RLS)**: Every database table in Supabase enforces granular read/write policies separating student permissions from elevated admin capabilities.
- **Git Protection**: Release APKs, keystores, environment credentials, and system build caches are strictly ignored via [.gitignore](file:///.gitignore).

---

## 🚀 Quick Start Guide

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.7.0`)
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extension
- A free [Supabase](https://supabase.com) account

---

## 🗄️ Supabase Setup Guide

Setting up your backend requires **only 3 simple steps**:

### Step 1: Create a Supabase Project
1. Go to [Supabase Dashboard](https://supabase.com/dashboard) and sign in.
2. Click **New project**.
3. Choose your organization, assign a project name (e.g. `ClassConnect`), set a database password, and select your nearest region.
4. Click **Create new project** and wait ~1 minute for provisioning.

### Step 2: Apply the Database Schema & Storage
1. In your Supabase Dashboard left sidebar, click **SQL Editor** (icon with `>_`).
2. Click **+ New query**.
3. Open the [supabase_schema.sql](file:///supabase_schema.sql) file located at the root of this repository.
4. Copy its entire content, paste it into the Supabase SQL Editor, and click **Run** (green button).

> **What this executes automatically:**
> - Enables the `uuid-ossp` PostgreSQL extension.
> - Creates all 7 relational tables: `users`, `subjects`, `timetable_slots`, `daily_overrides`, `resources`, `attendance_logs`, and `assignments`.
> - Establishes all Row Level Security (RLS) policies and performance indexes.
> - Pre-populates sample academic subjects (`CS201`, `CS204`, `EE210`, `MA105`).
> - Provisions the `lecture-notes` public Storage bucket with upload and download policies (50 MB limit).

### Step 3: Retrieve API Keys
1. In the Supabase Dashboard, click **Project Settings** (gear icon at bottom left).
2. Select **API** under Configuration.
3. Copy the following two values:
   - **Project URL** (e.g. `https://xyzcompany.supabase.co`)
   - **Project API Keys -> `anon` / `public`** (e.g. `eyJhbGciOi...`)

---

## ⚙️ Environment Configuration

ClassConnect supports both standard `.env` (dotenv) and `env.json` formats.

### 1. Create your local environment file
Copy either of the provided example templates:

```bash
# Option A: Standard .env file
cp .env.example .env

# Option B: JSON format
cp .env.example.json env.json
```

### 2. Fill in your credentials

Edit your `.env` (or `env.json`) file:

```env
# 1. Supabase Backend Credentials
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=your_supabase_anon_publishable_key

# 2. Administrator Access Credentials
# Comma-separated list of Google Account emails granted Admin role upon sign-in
ADMIN_EMAILS=your.email@gmail.com,second.admin@gmail.com

# 3. Master Admin Passcode (Used to unlock elevated console features)
ADMIN_PASSWORD=your_custom_admin_password_2026

# 4. Optional Database Password (for external scripts / database migrations)
DB_PASSWORD=your_database_password
```

> [!NOTE]
> `.env` and `env.json` are strictly added to [.gitignore](file:///.gitignore). Never commit real credentials to GitHub.

---

## 📱 Running & Building

### Run Locally (Development)

Run the application targeting your connected device, emulator, or simulator:

```bash
# Using .env:
flutter run --dart-define-from-file=.env

# OR using env.json:
flutter run --dart-define-from-file=env.json
```

### Run on a Specific Device / Emulator

```bash
flutter devices
flutter run -d <device_id> --dart-define-from-file=.env
```

### Build Production Signed APK

```bash
flutter build apk --release --dart-define-from-file=.env
```
The output APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`.

### Build Android App Bundle (AAB for Google Play)

```bash
flutter build appbundle --release --dart-define-from-file=.env
```

---

## 📊 Database Schema Reference

The complete schema is maintained in [supabase_schema.sql](file:///supabase_schema.sql):

| Table | Purpose | Security (RLS) |
|---|---|---|
| `users` | Profiles, roles (`student` \| `admin`), credits, verification status | Public read; users edit own row |
| `subjects` | Course metadata, professor, color themes, attendance targets | Public read; admins write |
| `timetable_slots` | Weekly scheduled lecture timings and room assignments | Public read; admins write |
| `daily_overrides` | Room changes, class cancellations, topic updates | Public read; student insert; admin approval |
| `resources` | Uploaded lecture notes, past papers, YouTube lectures | Approved items public read; uploaders insert; admins moderate |
| `attendance_logs` | Per-student daily attendance tracking records | Private per user |
| `assignments` | Coursework titles, deadlines, Google Drive links | Public read; admins manage |
| `storage.buckets` (`lecture-notes`) | Vault file uploads (PDFs, images up to 50MB) | Public download; authenticated/uploader upload |

---

## 🧪 Testing

Run all unit and widget tests to verify authentication, models, and UI screens:

```bash
flutter test
```

All 13 test suites are fully mock-isolated and pass without requiring external network connectivity.

---

## 📄 License & Contact
- **Developer / Publisher**: Kzynovex Inc.
- **Privacy Policy**: [PRIVACY_POLICY.md](file:///PRIVACY_POLICY.md) / [privacy_policy.html](file:///privacy_policy.html)
- **Support**: `support@kzynovex.online`
