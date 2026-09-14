[readme](./README.md) / [TROUBLESHOOTING](./TROUBLESHOOTING.md)

# Scenario #1

#### 502 error after deploy

در شرایطی که بعد از دیپلوی ارور ۵۰۲ دریافت شد، ابتدا لازم است مطمئن شویم که دیپلویمنت و سرویس های مربوط به ایپلیکیشن به طور کامل و بدون مشکل اجرا و اعمال شده است. برای اینکار وضعیت دیپلویمنت را بررسی می‌کنیم

`kubectl -n django-app get deployment --selector app=django`

انتظار داریم که چیزی شبیه به این را ببینیم:

```
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
django   1/1     1            0           2s
```

همچنین برای سرویس ها این دستور را اجرا میکنیم:
`kubectl -n django-app get svc --selector app=django`

خروجی مورد انتظار:

```
NAME     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
django   ClusterIP   <private_ip>     <none>        8000/TCP   16m
```

در صورتی که مشکلی در ایجاد سرویس وجود داشته باشد میتوانیم با دستور زیر آن را بیشتر بررسی کنیم. این دستور جزئیات این سرویس را خروجی میدهد و میتوانیم دیپلویمنت متصل و جزئیات بیشتر آن را بررسی کنیم
`kubectl -n django-app get svc django -oyaml`

از این خروجی میتوانیم وضعیت پاد های موجود را ببینیم. سپس می‌توانیم برای بررسی بیشتر لیست پاد های مربوط به این دیپلویمنت را دریافت کنیم

`kubectl -n django-app get pods --selector app=django`

انتظار می‌رود که خروجی شبیه به این باشد:

```
NAME                     READY   STATUS      RESTARTS        AGE
django-996546c7f-c9l5c   1/1     Running     2 (3m27s ago)   3m30s
django-migrate-hd97r     0/1     Completed   3               3m30s
```

در صورتی که پادی در وضعیت ارور یا پندینگ باشد (شبیه خروجی زیر) نیاز است که پاد را بیشتر بررسی کنیم

```
NAME                     READY   STATUS      RESTARTS        AGE
django-996546c7f-c9l5c   0/1     Error       2 (3m27s ago)   3m30s
django-migrate-hd97r     0/1     Completed   3               3m30s
```

با دستور زیر میتوانیم ایونت های مربوط به پاد را دریافت کنیم
\*\* اسم پاد ها را با مقدار واقعی روی کلاستر جایگزین کنید.
`kubectl -n django-app describe pod django-996546c7f-c9l5c`

از طریق ایونت ها می‌توانیم وضعیت پول کردن ایمیج و بررخی دیگر از ایونت هایی که منجر به خطا شده اند (مثل OOMKilled) را دریافت و مشاهده کنیم.

در بعضی از مواقع، پاد ها بدون مشکل شروع به اجرا می‌کنند ولی در حین استارت و راه اندازی دچار مشکل می‌شوند و پاد ری‌استارت می‌شود. دلیل این موضوع میتواند مسائلی مثل مشکل logical، کمبود ریسورس، سلامت و اتصال به دپندنسی ها و مشکلات دیگر نرم افزاری باشد که نیاز به بررسی بیشتر دارد. برای این کار میتوانیم لاگ های پاد مورد نظر را با دستورات زیر مشاهده کنیم:

`kubectl -n django-app logs django-996546c7f-c9l5c`
`kubectl -n django-app logs django-996546c7f-c9l5c --previuos` (در صورت خطا و ریست شدن، برای مشاهده‌ی لاگ های قبل از ریست کاربرد دارد)

همچنین درصورتی که پاد در حال اجرا باشد میتوانیم با دستور زیر کامند هایی برای حل مشکل اجرا کنیم
`kubectl -n django-app exec -it django-996546c7f-c9l5c -- bash`
``

برای مشاهده‌ی ریسورس مصرفی هر پاد میتوانیم از دستور زیر استفاده کنیم
`kubectl -n django-app top pods`
kubectl top: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_top/

در صورتی که مشکل مربوط به ریسورس ها بود میتوانیم مقدار درخواست این اپ برای cpu و memory را افزایش و دیپلویمنت ها را جایگزین کنیم.

درصورتی که همچنان سرنخی برای مشکل ندارید لاگ های بیشتری اضافه کنید و در متریک ها و لاگ ها دنبال مشکل بگردید و همچنین رول های فایروال را برای اطمینان از دسترسی های نود ها و کلاستر بررسی کنید.

# Scenario #2

#### db connection increased and caused a general slow down in application flows

در این مواقع ابتدا نیاز است مشکل کندی اپ را بررسی و تایید کنیم. برای اینکار نیاز است سرعت اپ، لاگ ارور ها و زمانی که این حادثه شروع شده است را پیدا کنیم.

برای مشاهده‌ی کانکشن های دیتابیس پستگرس میتوانیم کوئری زیر را اجرا کنیم. برای اجرای این کوئری نیاز است یک شل از اپ پستگرس دریافت کنیم
`kubectl -n django-app exec -it postgres-0 -- bash`
یک کانکشن به دیتابیس مدنظر خود ایجاد کنید:
`postgres@postgres-0:/$ psql -U change_me -d exchange`
کوئری را اجرا کنید

```
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state;

SHOW max_connections;
```

از خروجی این کوئری میتوان دریافت که کانکشن ها ناگهانی زیاد شده اند و یا نزدیک به لیمیت کانکشن هستند یا خیر.

همچنین با کوئری زیر میتوانید ببینید که کانکشن ها از کجا متصل هستند:

```
SELECT application_name, client_addr, state, count(*)
FROM pg_stat_activity
GROUP BY application_name, client_addr, state
ORDER BY count(*) DESC;
```

درصورتی که مشکل مشخصی را نیافتید، مصرف ریسورس های اپ پستگرس و ارور های خود کانتینر را بررسی کنید. سعی کنید با افزایش ریسورس ها مشکل را حل کنید.
ریسورس های مورد نیاز برای بررسی: cpu, memory, disk I/O

ممکن است گاهی کوئری های طولانی یا سنگین از سمت اپلیکیشن باعث کندی دیتابیس شوند. با ابزار هایی مثل
`pgHero`
میتوانید کوئری ها و عملکرد کلی دیتابیس postgres خود را نظارت کنید
