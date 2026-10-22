# ClassConnect (softwareclass)

Class lecture notifications and notes sharing app for university students and administrators.

## Security & Environment Configuration

All sensitive credentials (database passwords, admin emails, admin master passcode, Supabase keys) are strictly kept out of version control and managed via environment files (`.env` or `env.json`).

### 1. Setup Environment File

Copy the provided example template:

```bash
# Using .env:
cp .env.example .env

# OR using JSON format:
cp .env.example.json env.json
```

### 2. Configure Your Variables

Fill in your project-specific credentials in `.env` (or `env.json`):

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your_supabase_anon_publishable_key
ADMIN_EMAILS=admin1@example.com,admin2@example.com
ADMIN_PASSWORD=your_secure_admin_password
DB_PASSWORD=your_database_password
```

### 3. Running the App

Pass the environment file using `--dart-define-from-file`:

```bash
# Run with .env
flutter run --dart-define-from-file=.env

# OR run with env.json
flutter run --dart-define-from-file=env.json
```

### 4. Building Release APK / Bundle

```bash
flutter build apk --release --dart-define-from-file=.env
```
