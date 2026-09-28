# 步步 Bùbù for iPhone

The Bùbù web app (`../chineseLearning/app`), wrapped as a native iOS app with Capacitor 8.
Everything is prepared on Windows; a Mac is only needed to build and install.

## What's in here
- `www/`: a copy of the web app, made by `npm run copy-web` (the service worker is switched off: the app ships every file itself)
- `ios/`: the Xcode project. It uses Swift Package Manager, so there's no CocoaPods to install.
- `assets/`: the source icon and launch screens (`npx capacitor-assets generate --ios` rebuilds them)
- `capacitor.config.json`: app id `com.bubu`, name 步步 Bùbù
- One plugin: `@capgo/capacitor-speech-recognition`, Apple's speech recogniser for speaking practice

## On Windows: after changing the web app
```
npm run sync
```
Then copy the folder to the Mac again (or use `bubu-ios-for-mac.zip`, see below).

## On the Mac: first time (about 20 minutes, most of it the Xcode download)
1. Install **Xcode** from the Mac App Store (free). Open it once and let it finish installing components.
2. Unzip `bubu-ios-for-mac.zip` anywhere, for example on the Desktop.
3. Open `ios/App/App.xcodeproj` in Xcode. Wait for "Resolving package graph" to finish (top bar); it downloads Capacitor.
4. **Signing:** click the blue **App** project at the top of the left sidebar → target **App** → **Signing & Capabilities** →
   tick *Automatically manage signing* → **Team**: *Add an Account…* and sign in with **your** Apple ID. Pick "(Personal Team)".
   If it says the bundle identifier isn't available, change it to something unique, such as `com.bubu.dev`.
5. **Your iPhone:** plug it into the Mac with a cable, unlock it and tap *Trust*.
   On the iPhone: **Settings → Privacy & Security → Developer Mode → On** (it restarts).
6. In Xcode's top bar, choose your iPhone as the run destination, then press **▶ Run**.
7. The first time, the iPhone blocks the app: **Settings → General → VPN & Device Management →** your Apple ID → **Trust**. Run again.

With a free Apple ID the app works for **7 days**, then needs step 6 again. The paid Apple Developer Program ($99/year) removes that limit
and adds TestFlight (install without a cable, invite testers) and the App Store.

## Later: TestFlight and the App Store
Needs the Apple Developer Program. In Xcode: **Product → Archive → Distribute App → TestFlight & App Store**.
