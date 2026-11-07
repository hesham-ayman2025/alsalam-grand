# Native ROM Home — Android 6 / MStar Mainz

*This is source code for a firmware-bundled HOME component, not a separately installed end-user app.*

- Native Android Views only (no WebView, Compose, Flutter or third-party UI library).
- `HOME` activity and 56-number IPTV player using Android `VideoView`, which must be tested on real MStar OMX.
- D-PAD focusable cards, CH+/CH-, numeric keys, OK to open channel list and Back/Home return.
- Arabic/English switch from home; hotel images, date/time and deliberately unset prayer values (no fake prayer schedule).
- Local PIN UI for administration; NOT a secure Android/Factory Settings lock.
- Per-device name and module toggles in local preferences.
- Dynamic sanitized public content JSON from configured `https://` URL, polled only while HomeActivity runs (every ~2 minutes). Not a full fleet management server.
- The menu image viewer displays a truthful "not uploaded" placeholder until real menu images are provided.
- HDMI and casting integration are placeholders pending proprietary MStar source-control API and casting receiver development.
- Optional YouTube launcher tries installed trusted compatible packages; does not bundle SmartTube or Google binaries.

Build with Android Gradle Plugin 8.5.2, JDK 17 and installed Android SDK 35, or adapt to a locally available Android build toolchain. The current environment has no Android SDK/D8/aapt2 and the code has NOT BEEN COMPILED, SIGNED, DEVICE TESTED OR FLASHED. Review compile issues before firmware integration. Do not assume automatic Home selection: Android 6 may already prefer stock launcher in userdata. The ROM needs a verified default HOME selection path and first-boot data policy. Preserve Philips fallback until recovery works.

A firmware builder eventually places the signed component at `/system/priv-app/AlSalamGrandHome/AlSalamGrandHome.apk`, within the ext4 system image. Although Android Home windows are packaged internally as APK files, the user never manually installs it. Do not claim platform signature rights unless signed with OEM platform keys; `android.uid.system` not used.
