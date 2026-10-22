# Update Manager API - Developer Guide

This document describes the public API for checking and downloading application updates.

## Base URL
- Local testing (Android Emulator): `http://10.0.2.2:8000/api/v1`
- Local testing (iOS Simulator / Web): `http://127.0.0.1:8000/api/v1`
- Production: `https://<YOUR_PRODUCTION_DOMAIN>/api/v1`

---

## 1. Check for Updates
Use this endpoint to query the latest available release for the application.

**Endpoint:** `GET /update-check/{package_name}`
**Authentication:** None required

### Parameters
- `package_name` (Path parameter): The unique identifier of your app (e.g., `com.mycompany.myapp`).

### Response (200 OK)
Returns JSON containing metadata about the newest release.
```json
{
  "version_code": 2,
  "version_name": "1.0.1",
  "release_notes": "Fixed bugs",
  "is_mandatory": false,
  "download_url": "/api/v1/download/1"
}
```

### Error Responses
- **404 Not Found**: If the `package_name` is not registered on the server, or if no releases have been uploaded for it yet.

### Integration Logic
1. Fetch the JSON from this endpoint.
2. Compare the returned `version_code` (integer) against the app's currently running version code.
3. If the server's `version_code` > local version code, prompt the user to update.

---

## 2. Download Release File
Use this endpoint to download the actual `.apk` or `.exe` file for installation.

**Endpoint:** `GET /download/{release_id}`
*(Note: You do not need to construct this URL manually. Simply append the `download_url` value from the update-check response to your Base URL).*

**Authentication:** None required

### Response (200 OK)
Streams the binary file contents.
Headers will correctly identify the file type:
- `.apk`: `Content-Type: application/vnd.android.package-archive`
- `.exe`: `Content-Type: application/x-msdownload`

### Error Responses
- **404 Not Found**: If the requested release ID doesn't exist, or the physical file is missing from the server.

### Integration Logic
1. Use a package like `dio` to download the file from this URL.
2. Save it to a temporary directory on the device (e.g., using `path_provider`).
3. Use an installation plugin like `open_filex` or `install_plugin` to trigger the native OS installer using the downloaded file path.
