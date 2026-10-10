# Beget S3 — официальный ресерч

Проверено 2026-10-10. Только официальные страницы Beget; без ключа, `verified:false`. **[предположение]** обозначает сведения, которые нельзя подтвердить по опубликованному контракту. [Руководство](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget).

## Подключение

Endpoint `https://s3.ru1.storage.beget.cloud`, регион `ru1`; Access key/Secret key выдаются на странице созданного бакета. Официальные инструкции S3cmd, Rclone, SDK явно задают `ru1`; общий пример JavaScript с `us-east-1` — пояснение AWS SDK, а не регион Beget. [Клиенты и SDK](https://beget.com/ru/kb/faq/cloud/podklyuchenie-k-obektnomu-hranilishchu-s3-pri-pomoshchi-klientov-aws-cli-s3cmd-cyberduck-sdk).

Path-style: `https://s3.ru1.storage.beget.cloud/bucket/key`; virtual-host: `https://bucket.s3.ru1.storage.beget.cloud/key`. Профиль использует path-style. Собственный домен с SSL настраивается в панели; signing для него не подтверждён **[предположение]**. [Адреса и домены](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget).

Подтверждён ListBuckets: инструкции `rclone lsd`/`mc ls` показывают список бакетов. Создание/удаление бакетов и их администрирование через сторонние S3-клиенты явно запрещены, используются панель либо отдельный Beget Cloud API/Terraform, которые не входят в kit. `bucket_create`, `bucket_delete`, `bucket_config` выключены. [Технические ограничения и примеры](https://beget.com/ru/kb/faq/cloud/podklyuchenie-k-obektnomu-hranilishchu-s3-pri-pomoshchi-klientov-aws-cli-s3cmd-cyberduck-sdk), [Terraform](https://beget.com/ru/kb/faq/cloud/terraform).

## Хранение и цены

Сервис на Ceph; три копии на независимых серверах в разных стойках. **[предположение]** распределение между независимыми зонами не подтверждено, `multi_az:false`. [Описание сервиса](https://beget.com/ru/cloud/storage), [Основа Ceph](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget).

Русская тарифная страница указывает 0,07 ₽ за 1 ГБ в день, оплату фактически занятого пространства, бесплатные GET/POST/PUT, трафик без лимита объёма с полосой 350 Мбит/с. **[предположение]** 2,1 ₽/ГБ·месяц в профиле — нормализация на 30 дней; размер биллингового ГБ, налоги, скидки и ставка конкретного аккаунта требуют проверки. [Тариф](https://beget.com/ru/cloud/storage).

Отдельный каталог S3 StorageClass не опубликован. **[предположение]** `STANDARD` — обозначение базового класса для справочных ресурсов kit, не обещание поддержки заголовка `x-amz-storage-class` или смены класса. Инструменты не отправляют этот идентификатор. [Сервис](https://beget.com/ru/cloud/storage), [SDK](https://beget.com/ru/kb/faq/cloud/podklyuchenie-k-obektnomu-hranilishchu-s3-pri-pomoshchi-klientov-aws-cli-s3cmd-cyberduck-sdk).

## Матрица возможностей

| Возможность S3 API | Профиль / подтверждение | Источник |
|---|---|---|
| Object CRUD, ListObjectsV2 | Примеры SDK: Put/Get/List/Delete/DeleteObjects | [SDK](https://beget.com/ru/kb/faq/cloud/podklyuchenie-k-obektnomu-hranilishchu-s3-pri-pomoshchi-klientov-aws-cli-s3cmd-cyberduck-sdk) |
| Multipart | Сегментированная загрузка документирована, максимум 10000 частей; true | [Лимиты](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget) |
| If-None-Match / If-Match | **[предположение]** атомарные условия PUT/Copy/Complete/Delete не подтверждены; conditional_writes/delete:false | [SDK](https://beget.com/ru/kb/faq/cloud/podklyuchenie-k-obektnomu-hranilishchu-s3-pri-pomoshchi-klientov-aws-cli-s3cmd-cyberduck-sdk) |
| Object/Bucket tags | **[предположение]** API не подтверждён; оба false | [Руководство](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget) |
| Lifecycle | **[предположение]** контракт не найден; false | [Руководство](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget) |
| ACL | Rclone предлагает private, но это не доказательство полного ACL API; **[предположение]**, false | [Rclone](https://beget.com/ru/kb/faq/cloud/podklyuchenie-k-obektnomu-hranilishchu-s3-pri-pomoshchi-klientov-aws-cli-s3cmd-cyberduck-sdk) |
| Versioning | **[предположение]** S3 версии не подтверждены; false. Маркетинговое «версионирование конфигурации» Terraform не является Object Versioning | [Сервис](https://beget.com/ru/cloud/storage) |
| Object Lock / retention | **[предположение]** API не найден; false | [Руководство](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget) |
| CORS, public policy | Есть в панели; S3 Get/Put CORS/Policy не подтверждены. **[предположение]** API-совместимость, false | [Настройки бакета](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget) |

Default writes отказывают до сети, явно разрешённый overwrite сохраняет подтверждение. Move отключён. Тестовые бакеты versitygw создаются самим harness, а запрет bucket API у клиента остаётся включённым.

## Presign

Панель создаёт ссылку скачивания со сроком **до 7 дней**. Это не устанавливает максимум внешней SigV4 подписи или поддержку presigned PUT. **[предположение]** значение 604800 в справочном поле профиля перенесено из панели как консервативная граница; `presign:false` исключает GET/PUT/part signing инструменты MCP до живой проверки. Не считать внешний API подтверждённым по одной панели. [Ссылка скачивания](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget).

## Лимиты и ошибки

Техническая документация: 100 бакетов (увеличение через поддержку), имя бакета до 50 символов; объект до 50 ТБ, загрузка за запрос до 5 ГБ, 10000 частей; ключ до 1024 UTF-8 символов; до 90 metadata заголовков, имя до 128 и значение до 1024 символов. 2000 запросов/сек на аккаунт и 2000 GET/HEAD/OPTIONS на бакет. **[предположение]** `5000000000` трактует 5 ГБ как десятичные байты; не подтверждает бинарную единицу. [Лимиты](https://beget.com/ru/kb/faq/cloud/podklyuchenie-k-obektnomu-hranilishchu-s3-pri-pomoshchi-klientov-aws-cli-s3cmd-cyberduck-sdk).

Тарифная страница пишет, что число бакетов не ограничено; рабочий консервативный ориентир — более конкретные 100 с увеличением по запросу. **[предположение]** актуальный предел аккаунта проверяется в панели; это не влияет на профиль, который не создаёт бакеты. [Тариф](https://beget.com/ru/cloud/storage), [Ограничения](https://beget.com/ru/kb/manual/obektnoe-hranilishche-s3-v-beget).

**[предположение]** HTTP-статусы/XML-коды для превышения RPS, размера, metadata, числа бакетов не опубликованы в найденных официальных инструкциях. Не переносим AWS/Ceph ошибки без подтверждения (включая 429/503/SlowDown). Нужен живой тест в безопасных пределах аккаунта. [Официальный контракт](https://beget.com/ru/kb/faq/cloud/podklyuchenie-k-obektnomu-hranilishchu-s3-pri-pomoshchi-klientov-aws-cli-s3cmd-cyberduck-sdk).

## Нужна живая проверка

Ключ владельца и заранее созданный в панели тестовый бакет. Проверить ru1/path/virtual-host, object CRUD/copy/multipart, условия записи/удаления, полный список доступных API, presigned GET/PUT и срок, классы/биллинг, квоты и точные HTTP/XML-коды. Расширять профиль только после доказательства; релиз v0.1.0 отложен.
