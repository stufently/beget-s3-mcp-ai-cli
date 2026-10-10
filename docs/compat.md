# Beget S3 compatibility

Generated from the embedded provider profile.

| Feature | Supported |
|---|---|
| acl | false |
| bucket_config | false |
| bucket_create | false |
| bucket_delete | false |
| bucket_policy | false |
| bucket_tagging | false |
| conditional_delete | false |
| conditional_writes | false |
| cors | false |
| lifecycle | false |
| multipart | true |
| object_lock_config | false |
| object_retention | false |
| object_tagging | false |
| presign | false |
| versioning | false |

| Pool | Endpoint | Location | Multi-AZ | Classes |
|---|---|---|---|---|
| ru1 | https://s3.ru1.storage.beget.cloud | Россия | false | STANDARD |

| Class | Name | RUB/GB/month (from) | Verified | Checked |
|---|---|---|---|---|
| STANDARD | Базовое хранилище | 2.10 | false | 2026-10-10 |

Presign maximum: 604800 seconds; verified: false. Панель Beget создаёт ссылки максимум на 7 дней; потолок внешнего SigV4 GET/PUT не установлен, инструменты presign выключены. Bucket API — только панель; нужна живая проверка.
