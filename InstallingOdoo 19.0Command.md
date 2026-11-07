<div dir="rtl" align="right">

# دليل تثبيت Odoo 19 باستخدام Docker Compose

**Odoo 19 · PostgreSQL 18 · Docker Compose · دعم Traefik اختياري**

دليل تشغيل نسخة واحدة أو عدة نسخ مستقلة من Odoo 19 على Ubuntu/Linux.
يمكن استخدام Windows عبر WSL 2 مع تكامل Docker.

</div>

---

## المحتويات

1. [المتطلبات](#المتطلبات)
2. [التثبيت السريع](#التثبيت-السريع)
3. [الإعدادات وكلمات المرور](#الإعدادات-وكلمات-المرور)
4. [تشغيل نسخ متعددة](#تشغيل-نسخ-متعددة)
5. [Traefik وHTTPS](#traefik-وhttps)
6. [إدارة الحاويات](#إدارة-الحاويات)
7. [النسخ الاحتياطي والاستعادة](#النسخ-الاحتياطي-والاستعادة)
8. [استكشاف الأخطاء](#استكشاف-الأخطاء)

## المتطلبات

- Docker Engine.
- Docker Compose v2 (`docker compose`).
- OpenSSL لإنشاء كلمات مرور عشوائية عند استخدام سكربت التثبيت.
- المنفذان `10019` و`20019` متاحان، أو تحديد منافذ بديلة في `.env`.

تحقق من Docker:

```bash
docker --version
docker compose version
docker run --rm hello-world
```

## التثبيت السريع

نزّل المشروع أو انتقل إلى مجلده، ثم نفّذ:

```bash
cp .env.example .env
chmod 600 .env
chmod +x entrypoint.sh scripts/install-odoo19.sh
./scripts/install-odoo19.sh
```

ينشئ السكربت كلمات مرور عشوائية منفصلة إذا تُركت خانات كلمات المرور فارغة في
`.env`، ثم ينزّل الصور ويشغّل PostgreSQL 18 وOdoo 19.

افتح:

```text
http://localhost:10019
```

تحقق من الحاويات والسجلات:

```bash
docker compose ps
docker compose logs -f
```

## الإعدادات وكلمات المرور

عدّل ملف `.env` قبل التثبيت لتحديد:

| المتغير | القيمة الافتراضية | الاستخدام |
|---|---|---|
| `ODOO_HTTP_PORT` | `10019` | منفذ الويب |
| `ODOO_CHAT_PORT` | `20019` | منفذ المحادثة المباشرة |
| `POSTGRES_USER` | `odoo19` | مستخدم PostgreSQL |
| `POSTGRES_PASSWORD` | يُنشأ تلقائياً | كلمة مرور PostgreSQL |
| `ODOO_ADMIN_PASSWORD` | تُنشأ تلقائياً | كلمة مرور إدارة قواعد البيانات في Odoo |

كلمة مرور إدارة قواعد البيانات ليست كلمة مرور حساب مدير Odoo. أنشئ حساب
المدير داخل قاعدة البيانات عند فتح النظام لأول مرة. لا ترفع `.env` إلى Git
ولا تستخدم كلمات مرور تجريبية على خادم متاح للإنترنت.

مسار إعداد Odoo هو `etc/odoo.conf`، وتضاف الإضافات المخصصة داخل `addons/`.

## تشغيل نسخ متعددة

ينشئ `run.sh` مجلداً مستقلاً لكل نسخة مع منافذ وحاويات وشبكات وأحجام بيانات
منفصلة:

```bash
bash run.sh --destination odoo-live --port 10019 --chat 20019
bash run.sh --destination odoo-test --port 11019 --chat 21019
```

يجب أن يكون مجلد الوجهة غير موجود مسبقاً. يتطلب السكربت Git وDocker وDocker
Compose v2 وOpenSSL.

## Traefik وHTTPS

يتطلب هذا الخيار Traefik يعمل مسبقاً، وشبكة Docker خارجية مشتركة معه، ومدخل
`websecure` ومحلل شهادات `letsencrypt`.

1. حدّد `ODOO_DOMAIN` و`DOCKER_PROXY_NETWORK` واسمًا فريدًا في
   `ODOO_ROUTER_NAME` داخل `.env`.
2. تأكد من وجود الشبكة الخارجية وربط Traefik بها.
3. إذا كنت تنتقل من إعداد HTTP، أوقف الحاويات دون حذف البيانات:

   ```bash
   docker compose down
   ```

4. شغّل إعداد Traefik:

   ```bash
   docker compose -f docker-compose.traefik.yml up -d
   ```

لا ينشر إعداد Traefik منافذ Odoo أو PostgreSQL على المضيف. يتولى Traefik
توجيه الويب واتصالات `/websocket`.

## إدارة الحاويات

```bash
docker compose ps
docker compose logs -f odoo19
docker compose restart
docker compose stop
docker compose down
```

تحذير: `docker compose down -v` يحذف حجم بيانات Odoo.

## النسخ الاحتياطي والاستعادة

لإنشاء نسخة احتياطية من قواعد البيانات ومجلد المرفقات:

```bash
./scripts/backup.sh
./scripts/health-check.sh
```

يحفظ السكربت النسخة داخل مجلد `backups/` ضمن المشروع ويحتفظ بآخر خمس نسخ.
احتفظ بنسخة آمنة من ملف `.env` والإضافات المخصصة أيضًا، واختبر الاستعادة قبل
الاعتماد على النسخ الاحتياطية. لا تستخدم `docker compose down -v`؛ فهو يحذف
حجم بيانات Odoo.

## استكشاف الأخطاء

### Odoo لا يتصل بقاعدة البيانات

```bash
docker compose ps
docker compose logs db
docker compose logs odoo19
```

ينتظر Odoo نجاح فحص جاهزية PostgreSQL قبل بدء التشغيل.

### المنفذ مستخدم

غيّر `ODOO_HTTP_PORT` أو `ODOO_CHAT_PORT` في `.env` ثم أعد إنشاء الحاوية:

```bash
docker compose up -d
```

### تغييرات الإعداد لا تظهر

```bash
docker compose up -d --force-recreate odoo19
```

### لا يعمل توجيه Traefik

تحقق من اسم النطاق، واسم الشبكة الخارجية، واسم محلل الشهادات، وسجلات Traefik.
