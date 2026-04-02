# Quick Start - Flutter Mobile App

Get the Infini-Stock mobile app running in minutes!

## ⚡ Quick Start (5 minutes)

### 1. Prerequisites Check
```bash
# Make sure you have Flutter installed
flutter doctor

# Should show Flutter and Dart versions (green checkmarks)
```

### 2. Install Dependencies
```bash
# Navigate to mobile-app folder
cd Infini-Stock/mobile-app

# Get all packages
flutter pub get
```

### 3. Run the App

**On Physical Device:**
```bash
# Connect phone via USB, enable USB Debugging
flutter run
```

**On Emulator:**
```bash
# Start emulator first
flutter emulators --launch emulator_name

# Or use iOS Simulator (macOS):
open -a Simulator

# Then run
flutter run
```

**On Chrome (Web - experimental):**
```bash
flutter run -d chrome
```

### 4. Login
Use these demo credentials:
- **Email:** `admin@infini.local`
- **Password:** `Password@123`

## 📱 What's Included

- ✅ Dashboard with statistics
- ✅ Monitors list with QR codes
- ✅ System Units management
- ✅ Activity Logs with filters
- ✅ QR Code Generator
- ✅ Dark Lavender Theme (matches web app)
- ✅ Offline support with SharedPreferences

## 🎯 Common Commands

```bash
# Hot reload (fast - preserves state)
r

# Hot restart (full reload)
R

# Stop app
q

# Other options
? - show help
```

## 🔍 Testing Navigation

Once logged in, test each screen:

1. **Dashboard** (Home icon)
   - View statistics
   - See recent activity

2. **Monitors** (Monitor icon)
   - Search by name/QR
   - Filter by status
   - Tap to expand details

3. **Units** (Storage icon)
   - View all system units
   - Check location
   - See linked monitors

4. **Logs** (History icon)
   - Browse all transactions
   - Filter by action type
   - Search by QR code

5. **QR** (QR Code icon)
   - Generate QR codes
   - Share codes
   - See encoded data

## 🚀 Performance Tips

- Use **Release mode** for faster performance:
  ```bash
  flutter run --release
  ```

- Use **Profile mode** for testing:
  ```bash
  flutter run --profile
  ```

## 🛠️ Build for Distribution

### Android APK (recommended for testing)
```bash
flutter build apk --release
# Find it at: build/app/outputs/apk/release/app-release.apk
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Find it at: build/app/outputs/bundle/release/app-release.aab
```

### iOS App (on macOS)
```bash
flutter build ios --release
```

## 🐛 Troubleshooting

**App won't start?**
```bash
flutter clean
flutter pub get
flutter run -v  # Shows detailed logs
```

**Can't connect to API?**
- Make sure backend is running on `http://localhost:5000`
- For physical device, update API URL to use actual server IP
- Edit: `lib/services/api_client.dart` line 10

**Device not showing up?**
```bash
flutter devices
# If empty, check USB cable and enable USB Debugging
```

**Cold start takes too long?**
```bash
flutter run --release  # Much faster!
```

## 📚 Full Documentation

- 📖 **Feature Guide**: [README.md](README.md)
- 🔧 **Setup Guide**: [SETUP_GUIDE.md](SETUP_GUIDE.md)
- 🎨 **Theme**: Check `lib/theme/app_theme.dart`
- 📡 **API**: Check `lib/services/api_client.dart`

## 💡 Pro Tips

1. **Use Profile Mode for Real Testing**: Release mode hides errors
   ```bash
   flutter run --profile
   ```

2. **Hot Reload is Your Friend**: Press `r` frequently during development

3. **View Logs**: Add `-v` flag for verbose output
   ```bash
   flutter run -v
   ```

4. **Test Different Devices**: Build multiple device targets
   ```bash
   flutter run -d all  # Run on all devices
   ```

5. **Use DevTools**: Great for debugging
   ```bash
   flutter pub global activate devtools
   devtools
   ```

## 🎓 Next Steps

1. ✅ Run the app successfully
2. 📱 Test on physical device if possible
3. 🔄 Explore the codebase in `lib/screens/`
4. 🎨 Customize colors in `lib/theme/app_theme.dart`
5. 🚀 Build for production when ready

## ❓ Need Help?

- 🔍 Check logs: `flutter run -v`
- 📋 Run diagnostics: `flutter doctor -v`
- 📚 Read docs: https://flutter.dev
- 🐛 Debug with DevTools: See tip #5 above

---

**Ready to get started?** Run `flutter run` now! 🚀
