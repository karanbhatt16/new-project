# APK Download Setup Instructions

## Overview
The web app now includes a download banner at the top that allows users to download the Android APK directly without going through the Play Store.

## ⚠️ IMPORTANT: Large APK Files

Firebase Hosting may have issues serving very large APK files (100+ MB). **We recommend hosting the APK externally** for better reliability.

## Recommended Setup: External Hosting

### Option 1: Google Drive (Easiest)

1. **Upload APK to Google Drive**
   - Go to https://drive.google.com
   - Upload `build/app/outputs/flutter-apk/app-release.apk`

2. **Get Shareable Link**
   - Right-click the file → Share
   - Change to "Anyone with the link"
   - Copy the link (format: `https://drive.google.com/file/d/FILE_ID/view`)

3. **Convert to Direct Download Link**
   - Change the link format from:
     ```
     https://drive.google.com/file/d/FILE_ID/view
     ```
   - To:
     ```
     https://drive.google.com/uc?export=download&id=FILE_ID
     ```

4. **Update web/index.html**
   - Find the line with `YOUR_DOWNLOAD_LINK_HERE`
   - Replace it with your Google Drive direct download link

5. **Deploy**
   ```bash
   firebase deploy --only hosting
   ```

### Option 2: GitHub Releases

1. **Create a Release**
   - Go to your GitHub repository
   - Click "Releases" → "Create a new release"
   - Tag version (e.g., `v1.0.0`)

2. **Upload APK**
   - Attach `app-release.apk` as a release asset
   - Publish the release

3. **Get Download Link**
   - Right-click the APK → Copy link address
   - Format: `https://github.com/username/repo/releases/download/v1.0.0/app-release.apk`

4. **Update web/index.html** with the GitHub link

### Option 3: Firebase Storage

1. **Upload to Firebase Storage**
   ```bash
   # Install Firebase CLI if needed
   npm install -g firebase-tools
   
   # Upload APK
   firebase storage:upload build/app/outputs/flutter-apk/app-release.apk /downloads/vibeu.apk
   ```

2. **Make Public**
   - Go to Firebase Console → Storage
   - Find the file → Make public
   - Copy the public URL

3. **Update web/index.html** with the Storage URL

## Alternative: Host on Firebase Hosting (For Smaller APKs)

If your APK is small (<50 MB), you can try hosting directly:

### 1. Build the Android APK
```bash
flutter build apk --release
```

### 2. Copy APK to Web Directory
```bash
cp build/app/outputs/flutter-apk/app-release.apk web/app-release.apk
```

### 3. Rebuild Web App
```bash
flutter build web
```

### 4. Copy APK to build/web
```bash
cp web/app-release.apk build/web/app-release.apk
```

### 5. Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
```

## Features

✅ **Download Button** - Prominent banner at the top of the web app
✅ **Responsive Design** - Adapts to different screen sizes
✅ **Dark Mode Support** - Matches system theme preference
✅ **Direct Download** - Users can download APK directly to their device
✅ **Custom Filename** - Downloads as "VibeU.apk" instead of "app-release.apk"

## Important Notes

### Security Warning
When users install the APK:
- Android will show a warning about installing from "Unknown Sources"
- Users need to enable "Install from Unknown Sources" in their settings
- This is normal for APKs not from the Play Store

### APK Signing
Make sure your APK is properly signed with your release keystore:
1. Configure signing in `android/key.properties`
2. Reference it in `android/app/build.gradle.kts`
3. Build with `flutter build apk --release`

### File Size Considerations
- APK files can be large (typically 20-50 MB for Flutter apps)
- Ensure your hosting service supports large file downloads
- Consider using CDN for faster downloads
- Firebase Hosting supports files up to 2 GB

### User Instructions
Consider adding these instructions for your users:

**How to Install:**
1. Click the "Download APK" button
2. Wait for download to complete
3. Open the downloaded file
4. If prompted, enable "Install from Unknown Sources"
5. Tap "Install"
6. Open the app and enjoy!

## Testing

Test the download flow:
1. Visit your web app
2. Click the download button
3. Verify the APK downloads with the correct filename
4. Install the APK on an Android device
5. Ensure the app runs correctly

## Troubleshooting

**Button not showing?**
- Clear browser cache and hard reload (Ctrl+Shift+R)
- Check browser console for errors

**Download fails?**
- Verify the APK file exists in the web directory
- Check file permissions on your hosting server
- Ensure the APK is properly signed

**APK won't install?**
- Verify the APK is signed with a valid keystore
- Check Android version compatibility
- Enable "Install from Unknown Sources" in Android settings
