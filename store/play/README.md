# رفع Monetizer على Google Play

خطوة بخطوة، بالترتيب. كل النصوص اللي محتاج تنسخها موجودة هنا.

| الحاجة | القيمة |
|---|---|
| اسم التطبيق | Monetizer |
| Package name | `com.monetizer.app` (مش بيتغيّر بعد أول رفع) |
| الإصدار | `1.0.0` (versionCode 1) |
| targetSdk / minSdk | 36 / 24 (أندرويد 7 فما فوق) |
| الفئة | Business |
| سياسة الخصوصية | https://fundflow-stg.up.railway.app/privacy |
| الموقع / الدعم | https://fundflow-stg.up.railway.app/support |
| طلب حذف البيانات | https://fundflow-stg.up.railway.app/delete-account |
| الأيقونة 512 | `store/play/icon-512.png` |
| Feature graphic | `store/play/feature-graphic-1024x500.png` |

---

## 0. قبل ما تبدأ

- [ ] **ارفع الباك إند والويب** على Railway، وافتح اللينكين دول وتأكد إنهم شغالين:
  - https://fundflow-stg.up.railway.app/privacy
  - https://fundflow-stg.up.railway.app/support
- [ ] **حساب تجريبي للمراجعين** على الإنتاج: عميل وشركة ومستخدم، وفيهم شوية بيانات (عهدة ومصروفات وطلب). المراجع هيدخل بيه.
- [ ] **إيميل دعم** يظهر للناس في صفحة الستور (جوجل بتطلبه).

## 1. حساب المطوّر

1. ادخل https://play.google.com/console وسجّل، وادفع 25 دولار مرة واحدة.
2. اختار نوع الحساب:
   - **Organization (شركة):** محتاج رقم D-U-N-S، ومفيش شرط الـ 14 يوم.
   - **Personal (شخصي):** أسرع في التسجيل، لكن قبل النشر للعامة لازم **Closed test بـ 12 شخص على الأقل لمدة 14 يوم متواصلين**.
3. تأكيد الهوية بيطلب بطاقة أو باسبور، وممكن ياخد من يوم لكام يوم.

## 2. مفتاح الرفع والبناء (على جهازك)

```bash
cd /home/ussef/fundflow-mob
scripts/create-upload-key.sh
flutter build appbundle --release
```

- السكريبت بيعمل `~/keys/monetizer-upload.jks` وملف `android/key.properties`، وهيطلب منك الباسورد. **خد نسخة من الـ jks والباسورد** في مكان آمن.
- الملف اللي هترفعه: `build/app/outputs/bundle/release/app-release.aab` (حوالي 50MB).
- النسخة دي بتكلّم سيرفر الإنتاج لوحدها، ومش محتاج تحط `--dart-define`.
- **كل رفع جديد** لازم ترفع الرقم اللي بعد `+` في `pubspec.yaml` (`1.0.0+2`، `+3`...)، وإلا Play هيرفضه.

## 3. إنشاء التطبيق

Play Console → **Create app**:
- App name: `Monetizer`
- Default language: **Arabic – ar**
- App or game: **App**
- Free or paid: **Free**
- وافق على الإقرارات.

## 4. App content (Policy → App content)

كل بند هنا لازم يتملي قبل أي نشر.

### Privacy policy
`https://fundflow-stg.up.railway.app/privacy`

### App access
- اختار: **All or some functionality is restricted**.
- Add instructions:
  - Name: `Demo account`
  - Username / Password: بيانات الحساب التجريبي.
  - Any other information:
    ```
    Customer code: <كود العميل>
    Monetizer is a B2B app. Accounts are created by each company's administrator; there is no self sign-up. Enter the customer code, username and password above on the login screen.
    ```

### Ads
**No, my app does not contain ads.**

### Content rating
- Email، وبعدها Category: **All Other App Types**.
- كل الأسئلة (عنف، جنس، ألفاظ، مخدرات، قمار...): **No**.
- "Does the app allow users to interact or exchange content?": **No**. المستخدمين بيشوفوا بيانات شركتهم بس، ومفيش تواصل مفتوح بين الناس.
- "Does the app share the user's current location?": **No**.
- "Does the app allow purchases of digital goods?": **No**.
- النتيجة المتوقعة: **Everyone / 3+**.

### Target audience
- Age groups: **18 and over** بس.
- "Could your app unintentionally appeal to children?": **No**.

### News app
**No**.

### Data safety
**نظرة عامة:**
- Does your app collect or share any of the required user data types? **Yes**
- Is all of the user data collected by your app encrypted in transit? **Yes**
- Which of the following methods of account creation does your app support? **My app does not allow users to create an account** (الحسابات بيعملها أدمن الشركة)
- Do you provide a way for users to request that their data is deleted? **Yes**، ولو طلب لينك:
  `https://fundflow-stg.up.railway.app/delete-account`

**أنواع البيانات.** لكل نوع: Collected = Yes، Shared = **No**، Processed ephemerally = **No**:

| القسم | النوع | مطلوب ولا اختياري | الغرض |
|---|---|---|---|
| Personal info | **Name** | Required | App functionality, Account management |
| Personal info | **User IDs** (اسم الدخول وكود الموظف) | Required | App functionality, Account management |
| Financial info | **Other financial info** (العهد والمصروفات) | Required | App functionality |
| Photos and videos | **Photos** (صور الفواتير والإيصالات) | Optional | App functionality |
| App info and performance | — | — | لا تختار حاجة |
| Device or other IDs | **Device or other IDs** (معرّف التثبيت ورمز الإشعارات) | Required | App functionality, Security |

لا تختار: Location، Contacts، Messages، Audio، Health، Web browsing، Calendar، Files. التطبيق ما بيجمعهمش.

### Advertising ID
**No**. التطبيق ما بيستخدمش Advertising ID، ومفيش صلاحية `AD_ID` في البناء.

### Financial features
اختار: **My app doesn't provide any financial features**. ده نظام داخلي للشركات بيسجّل العهد والمصروفات؛ مش بنك ولا قروض ولا محفظة ولا تداول.

### Government apps
**No**.

### Health
**My app doesn't have any health features**.

## 5. صفحة الستور (Grow → Store presence → Main store listing)

### App name (30 حرف)
```
Monetizer
```

### Short description (80 حرف)
```
إدارة العهد والمصروفات والمشروعات لشركتك من موبايلك
```

### Full description (4000 حرف)
```
Monetizer نظام متكامل لإدارة العهد والمصروفات والمشروعات لشركات المقاولات والشركات متعددة الفروع، والتطبيق ده بيوصلك بحساب شركتك من أي مكان.

العهد والمصروفات
• تابع رصيد عهدتك وكل حركة عليها لحظة بلحظة.
• سجّل المصروف وصوّر الفاتورة أو الإيصال من الكاميرا مباشرة.
• اطلب عهدة جديدة أو حوّل جزء من عهدتك لزميل، وتابع حالة الطلب.

الموافقات
• الطلبات اللي محتاجة موافقتك بتوصلك في مكان واحد مع إشعار فوري.
• وافق أو ارفض مع ذكر السبب، والطلب بيكمل دورته أوتوماتيك.

المشروعات ومراكز التكلفة
• ملف كامل لكل مركز تكلفة: العقد، والمستخلصات، والمقاولين، والمصروفات الفعلية.
• مستخلصات المقاولين ونسب الإنجاز.

المشتريات والمخازن
• طلبات الشراء وأوامر الشراء والاستلام في المخازن.
• الخامات ووحدات القياس.

العملاء والمعاينات
• العملاء المحتملين والمعاينات والمتابعات والاجتماعات مع تذكير بمواعيدها.

الأمان
• كل الاتصالات مشفرة.
• دخول ببصمة الإصبع أو Face ID على الجهاز المربوط بحسابك.
• كل مستخدم يشوف بس اللي صلاحياته تسمح بيه.

ملحوظة: التطبيق للشركات المشتركة في Monetizer. حسابك بيعمله مدير النظام في شركتك، ولو نسيت كلمة المرور تواصل معاه أو مع الدعم الفني.
```

### Graphics
- App icon: `store/play/icon-512.png`
- Feature graphic: `store/play/feature-graphic-1024x500.png`
- Phone screenshots: من 2 لـ 8 صور. شوف الجزء 7.

### Store settings (Grow → Store presence → Store settings)
- App category: **Business**
- Email: إيميل الدعم
- Website: `https://fundflow-stg.up.railway.app`

## 6. أول رفع: Internal testing

1. Test and release → Testing → **Internal testing** → Create new release.
2. أول مرة Play هيسألك عن **Play App Signing**: اختار **Use Google-generated key** (الافتراضي). جوجل بتحتفظ بمفتاح التطبيق، وأنت معاك مفتاح الرفع بس.
3. ارفع `app-release.aab`.
4. Release name: `1.0.0 (1)`
5. Release notes:
   ```
   <ar>
   أول إصدار من Monetizer: العهد والمصروفات، والموافقات، والمشروعات، والمشتريات، والعملاء.
   </ar>
   ```
6. Testers: اعمل قائمة إيميلات (لحد 100)، وابعتلهم لينك الاشتراك. بينزّلوا من Play Store عادي خلال دقايق، ومن غير مراجعة.

## 7. صور الشاشة

- المطلوب: 2 لـ 8 صور، طولية، أقل ضلع 320 وأكبر ضلع 3840 بكسل. المقاس المفضّل 1080×1920 أو 1080×2400.
- نسخة الـ release بتمنع تصوير الشاشة، فصوّر من نسخة debug متوصّلة بالإنتاج:
  ```bash
  flutter run --dart-define=API_BASE_URL=https://fundflow-production-bb03d785.up.railway.app
  ```
- ادخل بالحساب التجريبي (مش بيانات عميل حقيقي)، وصوّر:
  1. شاشة الدخول
  2. لوحة المتابعة
  3. العهدة ومصروفاتها
  4. تسجيل مصروف مع صورة فاتورة
  5. الموافقات
  6. ملف مركز التكلفة
  7. المشتريات أو المعاينات

## 8. النشر للعامة (Production)

- **حساب Organization:** بعد ما تجرّب على Internal testing، روح Production → Create new release → ارفع نفس الـ aab (أو اعمل Promote) → Send for review.
- **حساب Personal:**
  1. Testing → **Closed testing** → ارفع الـ aab وضيف **12 مختبر على الأقل** بإيميلات Gmail.
  2. لازم يفضلوا مشتركين **14 يوم متواصلين** وبيستخدموا التطبيق.
  3. بعدها Dashboard → **Apply for production**، وجاوب الأسئلة عن الاختبار.
- المراجعة غالباً من ساعات لـ 3 أيام، وأول تطبيق على حساب جديد ممكن ياخد لحد 7 أيام.

## 9. التحديثات بعد كده

1. ارفع الرقم اللي بعد `+` في `pubspec.yaml`، ومعاه الإصدار لو فيه تغيير كبير (`1.0.1+2`).
2. `flutter build appbundle --release`
3. Production (أو Internal) → Create new release → ارفع → Release notes → Review.

## مشاكل معروفة

| الرسالة | الحل |
|---|---|
| `Release signing requires android/key.properties` | شغّل `scripts/create-upload-key.sh` الأول |
| Version code 1 has already been used | ارفع الرقم اللي بعد `+` في `pubspec.yaml` |
| The Android App Bundle was signed with the wrong key | لازم نفس مفتاح الرفع اللي استخدمته أول مرة، فرجّع الـ jks من النسخة الاحتياطية |
| Your app is not compliant with the account deletion policy | ابعت لينك `/delete-account` في Data safety |
