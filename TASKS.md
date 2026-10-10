# Статус

- Завершено: ресерч официальной документации и консервативный профиль.
- Завершено: README RU/EN, compat, Registry manifest, skill, Dockerfile, GoReleaser и переиспользуемый CI.
- Завершено в Docker: build/vet/race/lint, versitygw, MCP для 8 уровней, мутации 95/95 (100%), signal/hash self-tests, check_docs, actionlint, GoReleaser snapshot (6 архивов), сборка под uid владельца; runtime USER 65532.
- Доставка: коммит/push в main и проверка CI; описание/topics настроены.
- Общий модуль: v0.1.1 для независимого запрета console-only bucket API; прежний v0.1.0 сохранён.
- Предположения: API условий, тегов/lifecycle/versioning/lock/ACL, внешний presign, идентификатор класса STANDARD, месячная нормализация цены/единицы, multi-AZ и точные ошибки превышения. Источники — docs/research/beget-s3.md.
- Нужна живая проверка: эндпоинты/регионы, условные заголовки, классы/цены, presign, API и ошибки на реальном тестовом бакете с ключом владельца.
- Релиз v0.1.0 и публикация OCI/Registry отложены до живой проверки.
