# Публикация с минимальными действиями владельца

## С телефона

1. Открыть подключённый репозиторий [FORTIS-LABYRINTH](https://github.com/deadllypleasee-hub/FORTIS-LABYRINTH). Код, коммиты и сборки подготавливаются автоматически; вручную создавать исходники не нужно.
2. После загрузки кода открыть вкладку **Actions → Check and build → последний успешный запуск → Artifacts**. Скачать пакет Places. Для работы Actions репозиторий должен разрешать запуск workflow.
3. Подготовить Roblox Experience и доступ доверенного исполнителя к её редактированию, если своего компьютера нет. Не передавать пароль или cookie аккаунта. Roblox Studio на Android не поддерживается.
4. После создания двух Places открыть **Actions → Check and build → Run workflow**. В поля `hub_place_id` и `dungeon_place_id` вставить их Place IDs и запустить сборку. Скачать новый артефакт и передать исполнителю для публикации. Параметры применяются к этой сборке и исходникам её ZIP, без коммита IDs в репозиторий. При следующей сборке для публикации указать оба IDs снова. Можно также передать оба ID разработчику для постоянной настройки в GitHub.

## Один раз в Roblox Studio на Windows/macOS

1. Открыть `FORTIS-Hub.rbxlx` и опубликовать как стартовый Place Experience **FORTIS: LABYRINTH**.
2. Добавить второй Place в ту же Experience; открыть `FORTIS-Dungeon.rbxlx` и опубликовать в этот Place. Не создавать две отдельные Experience.
3. Получить **Place IDs**, а не Universe ID. Запустить сборку с обоими ID через форму Actions, как описано выше. Опубликовать её `FORTIS-Hub.rbxlx` и `FORTIS-Dungeon.rbxlx` в те же Places.
4. Настроить доступ к Experience для закрытого теста. Запустить HUB обычным Roblox-клиентом, затем войти в портал. Studio не выполняет настоящие TeleportService-переходы; в Studio используется локальный Preview.
5. Проверить [studio-checklist.md](studio-checklist.md) до публичного открытия.

Не включать Studio API Services ради прототипа: Studio по умолчанию использует временные профили и не трогает production DataStore. Опубликованные серверы используют DataStore и MemoryStore своего Experience. Для отдельных интеграционных тестов нужен отдельный тестовый Experience с его данными.

## Что уже подготовлено

`default.project.json` собирает Preview со встроенным HUB и отдельными SOLO-этажами в одном сервере. `hub.project.json` и `dungeon.project.json` задают роль Place через ReplicatedStorage.PlaceKind. В production Dungeon пускает только игрока с серверным билетом из HUB в выделенный ReserveServerAsync-сервер. Билет не содержит профиль, монеты или клиентский seed; seed берётся сервером из MemoryStore.

При телепорте сначала завершается сохранение и снимается блокировка профиля. TeleportInitFailed восстанавливает доступ и позволяет повторить переход. Прямой вход в Dungeon без билета отклоняется. Настройки доступа к Places дополнительно проверяются владельцем в Creator Dashboard.

В этой среде нет Roblox Studio и подключённых полномочий Roblox Open Cloud. Публикация или реальные телепорты здесь не выполнялись.
