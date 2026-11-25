# رفع Monetizer على App Store

كل الخانات بالترتيب اللي بتظهر بيه في App Store Connect، ومعاها النصوص اللي تنسخها.

| الحاجة | القيمة |
|---|---|
| Bundle ID | `com.monetizer.app` |
| Apple ID للتطبيق | `6839345338` |
| الأجهزة | iPhone بس (مفيش صور iPad) |
| الإصدار | `1.0.0`، ورقم البناء بيتحدد لوحده من Codemagic |
| سياسة الخصوصية | https://fundflow-stg.up.railway.app/privacy |
| الدعم | https://fundflow-stg.up.railway.app/support |
| الصور | `store/app-store/screenshots/` (7 صور 1290×2796، مقاس iPhone 6.9") |

---

## 1. TestFlight: جرّب الأول

1. التطبيق ← **TestFlight**. النسخة `1.0.0 (1)` بتظهر بعد 10–30 دقيقة من انتهاء Codemagic.
2. **Internal Testing** ← **+** ← اسم الجروب `Team` ← ضيف نفسك وفريقك (لازم يكونوا مستخدمين في App Store Connect) ← ضيف النسخة.
3. على الآيفون نزّل تطبيق **TestFlight**، وادخل بنفس الـ Apple ID ← **Install**.
4. جرّب: الدخول، والبصمة / Face ID، وتصوير فاتورة، والإشعارات، ولينكات الخصوصية والدعم.

**بيانات اختبار الـ Beta** (TestFlight ← **Test Information**)، علشان التقديم الخارجي من Codemagic ما يفشلش:
- **Beta App Description:** نفس الوصف المختصر اللي تحت.
- **Feedback Email:** إيميل الدعم.
- **Marketing URL:** `https://fundflow-stg.up.railway.app`
- **Privacy Policy URL:** لينك الخصوصية.
- **Beta App Review Information:** بيانات الحساب التجريبي، زي الجزء 6.

## 2. App Information (عام لكل الإصدارات)

| الخانة | تكتب |
|---|---|
| **Name** (30) | `Monetizer` |
| **Subtitle** (30) | `إدارة العهد والمصروفات` |
| **Category** | Primary: **Business**، Secondary: **Productivity** |
| **Content Rights** | **No**. التطبيق ما بيعرضش محتوى لطرف تالت |
| **Age Rating** | شوف الجزء 4 |

## 3. App Privacy

**Privacy Policy URL:** `https://fundflow-stg.up.railway.app/privacy`

**Data Collection** ← **Get Started** ← «Do you or your third-party partners collect data from this app?» ← **Yes**.

علّم على الأنواع دي بس:

| القسم | النوع |
|---|---|
| Contact Info | **Name** |
| Financial Info | **Other Financial Info** (العهد والمصروفات) |
| User Content | **Photos or Videos** (صور الفواتير) |
| Identifiers | **User ID** (اسم الدخول وكود الموظف)<br>**Device ID** (معرّف التثبيت ورمز الإشعارات) |

لكل نوع من الخمسة نفس الإجابات:
- **Purposes:** ✅ **App Functionality** بس. ما تختارش Analytics ولا Advertising ولا Product Personalization ولا Developer's Marketing.
- **Is this data linked to the user's identity?** **Yes**، لأنه مربوط بحساب المستخدم.
- **Is this data used for tracking?** **No**، مفيش تتبع بين التطبيقات ولا إعلانات.

ما تعلّمش على: Location، Health، Contacts، Browsing، Search، Usage Data، Diagnostics، Purchases، Sensitive Info. التطبيق ما بيجمعهمش.

بعدها **Publish**.

## 4. Age Rating

كل الأسئلة إجابتها **None** أو **No**:
- عنف، ورعب، ومحتوى جنسي، وألفاظ، ومخدرات، وقمار، ومسابقات: **None**.
- Unrestricted Web Access: **No**.
- User-Generated Content / Messaging: **No**.
- Medical / Treatment info: **None**.

النتيجة المتوقعة: **4+**.

## 5. Pricing and Availability

- **Price:** Free.
- **Availability:** كل البلاد، أو اختار البلاد اللي فيها عملاء (مصر، السعودية...).
- **App Distribution Methods:** Public.

## 6. صفحة الإصدار (iOS App ← 1.0 Prepare for Submission)

### Screenshots: iPhone 6.9" Display
ارفع الـ 7 صور بالترتيب من `store/app-store/screenshots/`:
`01-follow-up-board` ← `02-custody` ← `03-custody-request` ← `04-scm-document-workflow` ← `05-cost-center-file` ← `06-crm-inspection-dashboard` ← `07-login`

Apple بتصغّرها لوحدها للآيفونات الأصغر.

### Promotional Text (170)
```
تابع عهدتك ومصروفاتك وطلبات شركتك من موبايلك، ووافق على الطلبات أول ما توصلك.
```

### Description (4000)
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

### Keywords (100، مفصولة بفاصلة من غير مسافات)
```
عهدة,مصروفات,محاسبة,مقاولات,مشروعات,موافقات,خزنة,مشتريات,مخازن,مستخلصات,فواتير,شركات
```

### URLs
- **Support URL:** `https://fundflow-stg.up.railway.app/support`
- **Marketing URL:** `https://fundflow-stg.up.railway.app`

### Version / Copyright
- **Version:** `1.0.0`
- **Copyright:** `2026 Monetizer`

### Build
دوس **+ Add Build** واختار النسخة اللي اترفعت من Codemagic. **Export Compliance** مش هيسأل، لأن التطبيق معلن إنه ما بيستخدمش تشفير غير المعفي (`ITSAppUsesNonExemptEncryption = NO`).

### App Review Information
- **Sign-in required:** ✅
- **User name / Password:** الحساب التجريبي على الإنتاج.
- **Contact Information:** اسمك وموبايلك وإيميلك. Apple بتستخدمهم بس لو احتاجوا يكلموك.
- **Notes** (بالإنجليزي):
  ```
  Monetizer is a B2B app for companies. Accounts are created by each company's administrator, so there is no sign-up screen and no account creation inside the app.

  Sign in: enter Customer code "<كود العميل التجريبي>", then the username and password above, and tap "تسجيل الدخول" (Sign in). The app is in Arabic.

  If asked to link the device for fingerprint/Face ID sign-in, tap "دخول فقط" (Sign in only).

  The demo company contains sample custody, expenses and pending approvals so every screen has data. Camera and photo access are used only to attach invoice and receipt photos to expenses.

  Account deletion requests: https://fundflow-stg.up.railway.app/delete-account
  ```

### Version Release
- **Manually release this version**: بتنشره بنفسك بعد الموافقة. أو **Automatically** لو عايزه ينزل أول ما يتوافق عليه.

## 7. التقديم

**Add for Review** ← **Submit to App Review**. المراجعة غالباً من يوم لـ 3 أيام.

## أسباب رفض شائعة وتجنّبها

| السبب | إزاي نتجنبه |
|---|---|
| 2.1 الحساب التجريبي مش شغال | جرّبه بنفسك قبل التقديم، وما تغيّرش الباسورد أثناء المراجعة |
| 4.2 / تطبيق داخلي لشركة واحدة | الـ Notes بتوضح إنه B2B لأكتر من شركة بالاشتراك |
| 5.1.1 حذف الحساب | مفيش إنشاء حساب من التطبيق، ولينك `/delete-account` موجود |
| 2.3 الصور مش مطابقة | الصور من شاشات التطبيق الحقيقية |
| الدخول بالبصمة | اختياري، والـ Notes بتشرح تتخطاه إزاي |

## التحديثات الجاية

1. غيّر الإصدار في `pubspec.yaml` (مثلاً `1.0.1+1`). رقم البناء بيتحدد لوحده من Codemagic.
2. Push ← Codemagic ← **Start new build**.
3. App Store Connect ← **+ Version** ← نفس الخطوات مع **What's New**.
