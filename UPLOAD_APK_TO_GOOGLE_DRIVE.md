# 📱 How to Upload APK to Google Drive and Enable Downloads

## Step 1: Upload APK to Google Drive

1. **Go to Google Drive**
   - Open https://drive.google.com
   - Log in with your Google account

2. **Upload the APK**
   - Click the **"+ New"** button (top left)
   - Select **"File upload"**
   - Navigate to: `C:\Users\karan\vibeu\build\app\outputs\flutter-apk\app-release.apk`
   - Upload the file (96 MB - will take a minute)

## Step 2: Make the File Shareable

1. **Find the uploaded file** in Google Drive
2. **Right-click** on `app-release.apk`
3. Click **"Share"**
4. Click **"Change to anyone with the link"**
5. Make sure it says **"Anyone with the link"** and **"Viewer"**
6. Click **"Copy link"**

## Step 3: Convert to Direct Download Link

The link you copied looks like:
```
https://drive.google.com/file/d/1ABC123XYZ456/view?usp=sharing
```

You need to extract the **FILE_ID** (the part between `/d/` and `/view`)

Example:
- Original: `https://drive.google.com/file/d/1ABC123XYZ456/view?usp=sharing`
- FILE_ID: `1ABC123XYZ456`

Then create the direct download link:
```
https://drive.google.com/uc?export=download&id=1ABC123XYZ456
```

## Step 4: Update web/index.html

1. Open `C:\Users\karan\vibeu\web\index.html`
2. Find line ~188 where it says: `<a href="YOUR_DOWNLOAD_LINK_HERE"`
3. Replace `YOUR_DOWNLOAD_LINK_HERE` with your Google Drive direct download link
4. Save the file

Example:
```html
<!-- Before -->
<a href="YOUR_DOWNLOAD_LINK_HERE" class="download-apk-button">

<!-- After -->
<a href="https://drive.google.com/uc?export=download&id=1ABC123XYZ456" class="download-apk-button">
```

## Step 5: Rebuild and Deploy

Run these commands:
```powershell
flutter build web
firebase deploy --only hosting
```

## Done! 🎉

Your download button will now work perfectly!

Users will:
1. Visit your website: https://valentine-544b0.web.app
2. Click "Download APK"
3. Download directly from Google Drive
4. Install the VibeU app on their Android device

---

## Troubleshooting

**Download still shows HTML page?**
- Make sure you used the direct download format: `https://drive.google.com/uc?export=download&id=FILE_ID`
- Don't use the regular share link format

**File not downloading?**
- Check the file is set to "Anyone with the link" in Google Drive
- Try the link in an incognito browser window

**Need help?**
- The APK file is located at: `C:\Users\karan\vibeu\build\app\outputs\flutter-apk\app-release.apk`
- File size: 96.04 MB
