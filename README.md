# Beget S3 MCP Server & AI CLI

![Version](https://img.shields.io/badge/version-0.1.0-blue) ![License](https://img.shields.io/badge/license-MIT-green)

Beget S3 Object Storage через MCP и CLI: Claude Code, Cursor и Codex помогают выполнять бэкап и работать с файлами, а AI-агент получает ограниченный доступ и подтверждение опасных действий.

## English

A single Go binary for Beget Object Storage: a stdio MCP server, streaming CLI and installable agent skill. Read-only MCP access is the default; independent write/delete/admin levels, bucket/prefix scope, human approval and confined local file access protect data. Large files use streaming file operations and multipart uploads according to the profile. See the [full English guide](README.en.md).

## Быстрый старт

Возьми бинарь своей платформы из Releases, когда версия будет опубликована, либо собери с Go 1.27.2:

```bash
bash scripts/go.sh go build -o beget-s3 ./cmd/beget-s3
./beget-s3 version
./beget-s3 auth set
./beget-s3 auth status
./beget-s3 ls --json
```

auth set спрашивает key ID и secret без эха; без TTY читает две строки stdin. Не передавай секрет в argv. Файл ~/.config/beget-s3/credentials создаётся атомарно с 0600; более широкие права отклоняются.

Приоритет: флаги > env > файл. Переменные: BEGET_S3_ACCESS_KEY_ID, BEGET_S3_SECRET_ACCESS_KEY, BEGET_S3_POOL (ru1), BEGET_S3_ENDPOINT. HTTP требует BEGET_S3_ALLOW_INSECURE=1.

После публикации образ: ghcr.io/stufently/beget-s3-mcp-ai-cli:0.1.0; локальная сборка: docker build -t beget-s3 . Образ запускает MCP от uid 65532, содержит CA-сертификаты. Передай креды через приватное окружение/файл.

## Возможности

Бакет сначала создайте в панели Beget: S3 API создания/удаления и чтения настроек бакета выключен. CORS и публичная политика настраиваются в панели. Presign MCP-инструменты выключены: срок 7 дней описан для панели, внешний SigV4 GET/PUT не подтверждён. Используйте FILE_ROOT для больших файлов; возможности API проверяйте по [ресерчу](docs/research/beget-s3.md).

- Потоковые object CRUD, copy, multipart и presigned URL в пределах профиля.
- Версии, теги, CORS, политика и Object Lock configuration регистрируются при наличии поддержки.
- Ограниченные сканы, диагностика, JSON, установка MCP и встроенного skill.

## Подключение к Claude Code, Cursor, Codex

```bash
beget-s3 mcp install --client cursor --dry-run
beget-s3 mcp install --client cursor
beget-s3 mcp install --client claude-desktop
beget-s3 mcp install --client codex
beget-s3 mcp install --client claude-code --scope project
beget-s3 mcp install --client claude-code --scope user
```

Последняя команда только печатает claude mcp add. Путь бинаря абсолютный; ключи в конфиг не пишутся. Cursor: ~/.cursor/mcp.json, Claude Code project: ./.mcp.json; Desktop — каталог конфигурации своей ОС. JSON сохраняет чужие ключи, .bak и идемпотентность.

Codex: ~/.codex/config.toml. Существующая таблица требует --force; заменяется только блок между # >>> beget-s3 (managed) / # <<< beget-s3 (managed). Таблица без маркеров не заменяется даже с --force; остальные байты TOML целы.

Уровни включаются независимо: beget-s3 mcp --allow-write --allow-delete --allow-admin либо BEGET_S3_ALLOW=write,delete,admin. Флаги доступны и в mcp install. FILE_ROOT включается через BEGET_S3_FILE_ROOT.

## Инструменты MCP

| Level | Tools |
|---|---|
| read | s3_list_buckets, s3_list_objects, s3_head_object, s3_get_object, s3_preview_object, s3_list_multipart_uploads, s3_list_parts, s3_largest_objects, s3_prefix_usage, s3_unfinished_uploads |
| read + FILE_ROOT | s3_download_file |
| write | s3_put_object, s3_create_folder, s3_copy_object, s3_multipart_create, s3_multipart_complete |
| write + FILE_ROOT | s3_upload_file |
| delete | s3_delete_object, s3_delete_objects, s3_multipart_abort |

Ресурсы: `beget-s3://config`, `beget-s3://capabilities`, `beget-s3://pools`. Неподдерживаемые возможности исключают инструменты.

Списки — до 1000 элементов с continuation_token; версии/multipart имеют второй маркер. Inline get/put — 262144 байт, preview — 65536; большие файлы идут через FILE_ROOT/multipart, presign в этом профиле отключён. Ответ содержит structuredContent и JSON-текст; текст свыше 256 КиБ заменяется краткой сводкой. Ошибки: code/message/retryable; 429/503 SDK повторяет адаптивно.

Аналитика сканирует максимум max_scan (по умолчанию 10000); partial/token отмечают неполный результат. Prefix usage выдаёт страницы агрегатов через next_result_offset. Это не биллинг.

## CLI

```bash
beget-s3 cp ./archive.tar s3://backups/daily/archive.tar --part-size 5242880 --overwrite --yes
beget-s3 ls backups/daily/ --max-keys 100 --json
beget-s3 stat backups/daily/archive.tar
beget-s3 cp s3://backups/daily/archive.tar ./restored.tar
beget-s3 cp ./directory s3://backups/tree/ --recursive --overwrite --yes
beget-s3 cp s3://backups/tree/ ./restored-directory --recursive
beget-s3 cp s3://backups/daily/archive.tar s3://backups/copy.tar --overwrite --yes
beget-s3 cat backups/daily/notes.txt
beget-s3 du backups/daily/ --max-scan 10000 --json
beget-s3 rm backups/moved.tar --yes
beget-s3 doctor --json
beget-s3 compat --markdown
```

cp принимает обычные локальные пути и S3 URI s3://bucket/key либо beget-s3://bucket/key. Большие загрузки используют manager/multipart, --recursive копирует каталоги/префиксы. Перезапись требует --overwrite и подтверждения; выгрузка атомарна. rm/rb/mv без --yes на не-TTY дают код 2; на TTY спрашивают. --json общий, ошибки — stderr и ненулевой код.

doctor проверяет источник/права кредов, DNS/TLS, часы по Date и ListBuckets: >5 минут — предупреждение, >15 — ошибка.

## Skill для AI-агентов

```bash
beget-s3 skill install
beget-s3 skill install --target ./agent-skills/beget-s3
```

По умолчанию ~/.claude/skills/beget-s3. Идемпотентно устанавливает SKILL.md и шесть references: backup/restore, share, least privilege, cost hygiene, migration, incident response. Триггеры: «beget s3», «бакет Beget», «загрузи в s3», «presigned», «бэкап в s3».

## Безопасность

Если `conditional_writes:false`, запись без перезаписи отказывает до S3-запросов: HEAD не даёт атомарной защиты. Для согласованной записи используй `--overwrite --yes` в CLI либо `overwrite:true, confirm:true` в MCP, сохраняя политику подтверждения. Если `conditional_delete:false`, `mv` и `s3_move_object` отключены.



MCP по умолчанию регистрирует только read; неподдерживаемые возможности и отсутствующие уровни исключают инструмент.

BEGET_S3_DESTRUCTIVE_POLICY: confirm использует elicitation при поддержке клиента, иначе нужен confirm:true после согласия человека; elicit требует elicitation и не допускает обхода confirm:true; block всегда запрещает, allow выполняет без гейта. Отказ предшествует любым S3-запросам. Гейт покрывает удаления, move, presigned PUT, политику/Object Lock, suspension versioning и перезаписи.

При conditional_writes:true операции put/copy/move/multipart complete/upload file используют overwrite:false, HEAD цели и If-None-Match: *; при false запись по умолчанию отказывает. overwrite:true требует тот же гейт.

Скоуп: BEGET_S3_ALLOWED_BUCKETS=backups и BEGET_S3_ALLOWED_PREFIXES=backups/daily/. Префикс учитывает границу сегмента; daily-evil не подходит. Сегменты '..' отклоняются. Частичный скоуп запрещает целый бакет и широкие списки даже при наличии его в ALLOWED_BUCKETS. Copy/move проверяет источник и цель.

Файловые MCP-инструменты используют os.Root: только относительные пути внутри FILE_ROOT; '..', абсолютные пути и симлинки наружу отклоняются. На каждый вызов одна JSON-строка в stderr; BEGET_S3_AUDIT_FILE дополнительно пишет в 0600. Секреты и X-Amz-Signature/Credential/Security-Token редактируются в логах/ошибках. Полная подписанная ссылка — только результат операции. Ограничивай также права самого S3-ключа.

s3_download_file по умолчанию публикует скачанный файл без замены существующего, в том числе созданного во время скачивания. Для замены передай overwrite:true: применяется разрушительная политика с подтверждением через форму либо confirm:true после согласия человека.

## Пулы и классы хранения Beget

Пулы, эндпоинты и классы — в [таблице совместимости](docs/compat.md); каждый факт, цены и ошибки с первоисточниками — в [ресерче](docs/research/beget-s3.md). Пул по умолчанию: `ru1`; регион SigV4 равен выбранному пулу. В профиле `verified:false`: проверка на versitygw не подтверждает API облака. Неподтверждённые сведения помечены **[предположение]**; цены в профиле не являются калькулятором биллинга.

Lifecycle, ACL, bucket tagging и object retention могут поддерживаться облаком, но эта версия не предоставляет инструментов для их настройки; данные профиля описывают совместимость S3 API.

## FAQ

**Что такое MCP-сервер?** Программа предоставляет агентам инструменты и ресурсы через Model Context Protocol; здесь stdio.

**Как подключить MCP-сервер к Claude Code?** Сохрани ключи auth set, затем используй project install либо напечатанную user-команду.

**Безопасно ли давать агенту доступ к S3?** Ограничь ключи, скоуп и уровни; сохрани confirm/block и одобряй разрушительные эффекты осознанно.

**Чем это отличается от aws-cli и rclone?** Бинарь объединяет MCP, гейт, аудит, аналитику, skill и CLI; aws-cli/rclone остаются самостоятельными средствами передачи/автоматизации.

**Какие возможности поддерживаются?** См. capabilities и [compat](docs/compat.md). Инструменты регистрируются по профилю; lifecycle, ACL, bucket tagging и object retention эта версия не настраивает.


## Другие провайдеры

Семейство: Selectel, Yandex Cloud, VK Cloud, Cloud.ru, Timeweb Cloud, MWS, Beget. Все используют [общий kit](https://github.com/stufently/s3-mcp-ai-cli-kit).

## Лицензия

[MIT](LICENSE). [Проверенные факты и предположения](docs/research/beget-s3.md).

Проверки в Docker: bash scripts/go.sh go test -race ./..., bash scripts/conformance.sh, bash scripts/mcp_smoke.sh, bash scripts/mutation_gate.sh, bash scripts/check_docs.sh. Conformance использует versitygw v1.8.0 и тестовые ключи.

Общие MCP/CLI, защиты и проверки поставляет [s3-mcp-ai-cli-kit v0.1.0](https://github.com/stufently/s3-mcp-ai-cli-kit/tree/v0.1.0); в этом репозитории остаются встроенный профиль, тонкий main и документы Beget.
