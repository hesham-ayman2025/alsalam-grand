# Al Salam Grand OS — Cloud Build Kit v2

## الهدف
واجهة الفندق تبقى هي الـ Home الوحيدة للشاشة بعد التشغيل، من غير Android Studio على جهازك، ومن غير تفليش صورة system كاملة.

## القرار التقني (ليه غيّرنا Stage F)
| | Stage F القديم | الـ Kit ده |
|---|---|---|
| طريقة التعديل | بناء `system.img` كامل 1.36GB وكتابته على القسم | تعديل **ملفين فقط** داخل `/system` |
| لو فشل | محتاج UART/eMMC | رجوع بأمر واحد (إعادة تسمية ملف) |
| بيمس boot/recovery/MBOOT | لا | لا |
| محتاج system_original.img في السحابة | أيوه (1.36GB) | لأ |

اللي بيحصل: نضيف `/system/priv-app/AlSalamGrandHome/AlSalamGrandHome.apk`، ونعيد تسمية `Philipslauncher.apk` إلى `.alsalam-bak` (مش بنحذفه).

## الخطوات
### 1) البناء السحابي (مرة واحدة)
1. GitHub → New repository → اسمه `alsalam-grand-rom` → **Private**.
2. Add file → Upload files → اسحب **كل محتويات** فولدر الـ Kit (لازم يظهر `.github/workflows/build_rom.yml`).
3. تبويب **Actions** → *Al Salam Grand OS - Cloud ROM Lab Build* → **Run workflow**.
4. بعد ما يخلص (✅ أخضر) → Artifacts → نزّل `alsalam-build-N` وفكّه.
   - لو طلع ❌ ابعتلي نص الخطأ بتاع الخطوة الحمرا.

الناتج: `AlSalamGrand-Home.apk` + 3 ملفات zip موقّعة + `SHA256SUMS.txt`.

### 2) سلم الاختبار (كل خطوة ليها رجوع)
ضع الـ APK جنب ملفات `windows\`.

| # | الملف | بيعمل إيه | الرجوع |
|---|---|---|---|
| 0 | `BACKUP_REMAINING_PARTITIONS.bat` | يسحب باقي الأقسام ويقارن | — (قراءة فقط) |
| 1 | `S1_INSTALL_APK_TEST.bat` | يثبّت الـ Home كتطبيق عادي | زر HOME |
| 2 | `S2_DISABLE_PHILIPS_LAUNCHER_TEST.bat` | يعطّل Philips Launcher (مش يحذفه) | `S2_ENABLE_PHILIPS_LAUNCHER.bat` |
| 3 | `S3_INSTALL_TO_SYSTEM_VIA_ADB.bat` | يثبّت الـ Home في `/system` | `S3_ROLLBACK_VIA_ADB.bat` |

**اختبر في الخطوة 2 على الريموت الحقيقي:** HOME، MENU، SOURCE/INPUT، الصوت، Power/Standby، إعادة التشغيل. دي اللي هتكشف لو خدمات MStar بتعتمد على Philips Launcher.
**لا تروح للخطوة 3 قبل ما الخطوة 2 تنجح يوم كامل بدون مشاكل.**

### 3) الـ zips الموقّعة (احتياطي عبر Recovery)
- `AlSalam_00_NOOP_TEST.zip` يطبع تشخيص ولا يكتب أي حاجة.
- `AlSalam_01_INSTALL_HOME.zip` / `AlSalam_02_ROLLBACK.zip` نفس تأثير S3.
- التشغيل: `adb reboot recovery` ثم `adb sideload الملف.zip` (محتاج اتصال USB-adb مع الـ Recovery، **لسه ما اتأكدش إنه شغال على الشاشة دي**). جرّب الـ NOOP الأول.

## اللي اتحقق منه فعلًا (على الملفات اللي بعتّها)
- مفتاح الـ Recovery (`n0inv=0xc926ad21`, `N[0]=1795090719`) = شهادة `otacerts.zip` (AOSP testkey).
- Recovery بيحمّل `update-binary` من داخل الـ zip، وفيه busybox 1.19.2 (unzip/cp/mv/rm/sha256sum...).
- `/system` بيتركّب بدون `verify` (مفيش dm-verity)، و`SECURITY=OFF`.
- سكريبت التحديث اتجرّب على شجرة ملفات وهمية: noop/install/install-تاني/rollback/موديل غلط ✅.
- بنية التوقيع (footer + PKCS#7) اتفحصت بـ OpenSSL ومحاكي للـ verifier ✅.

## اللي لسه ما اتجرّبش (مهم)
- بناء Gradle نفسه (مفيش SDK عندي) — الـ workflow هو اللي هيثبت.
- قبول الـ Recovery الحقيقي للتوقيع (اختبره بالـ NOOP).
- سلوك MStar بدون Philips Launcher (الخطوة 2).
- HDMI/Source الحقيقي: الكود بيعرض الصفحة بس، **مفيش تبديل مدخل فعلي** عبر MStar بعد.
- ربط الواجهة بالسيرفر المركزي (`alsalamd`) وتشغيله تلقائيًا.

## ملاحظات على الكود (Stage E)
1. `channels.json` فيه **بيانات دخول IPTV** داخل الـ APK → أي حد معاه ADB root على الشاشة يطلعها. المستودع Private، وبعدين ننقل القنوات للسيرفر بتوكن لكل جهاز.
2. `HomeActivity.onResume` بيعيد بناء الواجهة كلها وفك الصور كل مرة → ثقيل على 1GB RAM. هنصلحه بعد أول قياس حقيقي.
3. رمز الإدارة (211211) للاختبار فقط ومش بيقفل إعدادات Android.
4. الـ Recovery بيثق في AOSP testkey العامة → أي حد يوصل للـ Recovery بالـ USB يقدر يفلّش. التأمين النهائي بيحتاج استبدال المفتاح (تعديل قسم recovery) — مرحلة لاحقة بعد ما الأساس يثبت.
5. الـ ADB على الشبكة (5555) مفتوح بـ root → اقفله أو اعزله قبل تسليم الغرف.
