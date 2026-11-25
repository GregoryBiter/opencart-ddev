# opencart-ddev

Быстрый локальный запуск **уже существующего** сайта OpenCart 3 / ocStore в [DDEV](https://ddev.com).
Не установщик с нуля: берёт файлы сайта + дамп базы и за одну команду поднимает рабочую копию.

## Что умеет

- `make setup` — DDEV-окружение + импорт дампа + `config.php`/`admin/config.php` + пересборка OCMOD.
- Генерация конфигов под DDEV с **автоопределением префикса таблиц** и **переименованной админки**; старые конфиги сохраняются в `*.bak`.
- Пересборка OCMOD-модификаций из консоли (`make ocmod`) — без входа в админку.
- `make cache` чистит кэш **и сразу пересобирает модификации** (многие темы без них падают).
- **ionCube Loader** ставится автоматически (зашифрованные темы и модули).
- PHP 7.4 по умолчанию, MariaDB 10.11, Apache, Mailpit для писем, Xdebug по команде.

## Требования

- [DDEV](https://docs.ddev.com/en/stable/users/install/ddev-installation/) и Docker
- `make`, `bash`

## Установка в сайт

Одной командой, без клонирования — из корня сайта:

```bash
curl -fsSL https://raw.githubusercontent.com/GregoryBiter/opencart-ddev/main/install.sh | bash
```

Указать папку сайта или поставить в папку, не похожую на OpenCart:

```bash
curl -fsSL https://raw.githubusercontent.com/GregoryBiter/opencart-ddev/main/install.sh | bash -s -- /path/to/site --force
```

Конкретная версия (ветка или тег): `... | OC_DDEV_REF=v1.0.0 bash`.
Свой форк: `... | OC_DDEV_REPO=user/opencart-ddev bash`.

Или из клона:

```bash
git clone https://github.com/GregoryBiter/opencart-ddev.git ~/opencart-ddev
~/opencart-ddev/install.sh /path/to/site
```

Скрипт копирует в сайт `Makefile` и файлы в `.ddev/`, дописывает `.gitignore`.
Существующий `Makefile` сохраняется как `Makefile.bak`. Повторный запуск обновляет кит до текущей версии.

## Первый запуск

```bash
cd /path/to/site
# положите дамп (*.sql / *.sql.gz) в корень сайта
make setup
make open
```

Сайт будет доступен по `https://<имя-папки>.ddev.site`.

Параметры можно переопределить:

```bash
make setup PHP_VERSION=8.1 DB_TYPE=mysql DB_VERSION=8.0 DB_FILE=backup.sql.gz
```

`PHP_VERSION`, `DB_TYPE`, `DB_VERSION`, `PROJECT_NAME` влияют только на первый `make init`, пока нет `.ddev/config.yaml`.
Сменить PHP позже: `make php PHP_VERSION=8.1`.

## Команды

| Команда | Что делает |
|---|---|
| `make setup` | Всё сразу: init + db-import + config + ocmod |
| `make init` | Создать `.ddev/config.yaml` (если нет) и запустить |
| `make start` / `stop` / `restart` | Управление окружением |
| `make poweroff` | Остановить все проекты DDEV |
| `make destroy` | Удалить контейнеры и БД (файлы сайта остаются) |
| `make status` | URL, порты, доступы |
| `make open` / `admin` / `mail` | Витрина / админка / Mailpit в браузере |
| `make ssh` / `logs` / `db-cli` | Консоль контейнера / логи / MySQL |
| `make db-import [DB_FILE=…]` | Импорт дампа (по умолчанию единственный `*.sql*` в корне) |
| `make db-export [EXPORT_FILE=…]` | Бэкап базы в `dump-<дата>.sql.gz` |
| `make config` | Сгенерировать конфиги OpenCart под DDEV |
| `make ocmod` | Пересобрать OCMOD-модификации |
| `make cache` / `cache-all` | Очистить кэш (+ `image/cache`) и пересобрать модификации |
| `make php PHP_VERSION=…` | Сменить версию PHP |
| `make xdebug-on` / `xdebug-off` | Xdebug |
| `make permissions` | Права на `image/` и `system/storage/` |

То же доступно напрямую через DDEV: `ddev oc-config`, `ddev oc-ocmod`, `ddev oc-cache`.

### Параметры `make config`

```bash
ddev oc-config --prefix=oc_ --admin=admin_secret --url=https://shop.ddev.site
```

По умолчанию префикс берётся из базы (самый короткий `X`, для которого есть `Xsetting`, `Xproduct`, `Xsession`),
папка админки — `admin/` или любая папка с `controller/common/dashboard.php`, URL — основной URL DDEV.
Если база ещё пустая, ставится `oc_` — после импорта запустите `make config` ещё раз.

## Что лежит в ките

```text
kit/
├── Makefile
└── .ddev/
    ├── commands/web/oc-config     # генерация config.php / admin/config.php
    ├── commands/web/oc-ocmod      # пересборка модификаций
    ├── commands/web/oc-cache      # очистка кэша + пересборка
    ├── opencart/lib.sh            # общие функции
    ├── opencart/ocmod-refresh.php # CLI-аналог кнопки «Обновить» в Модификациях
    ├── php/opencart.ini           # memory_limit, upload, max_input_vars…
    └── web-build/Dockerfile.ioncube
```

Все команды выполняются **внутри** web-контейнера, поэтому пути в конфигах — `/var/www/html/...`.
Инструменты, запускаемые на хосте и читающие `config.php` (например `ocm`), с такими путями работать не будут —
запускайте их через `ddev exec`.

## Коммитить ли `.ddev` в репозиторий сайта

Да. Внутри `.ddev/.gitignore` (его создаёт DDEV) уже исключены сгенерированные файлы.
Личные настройки (порты и т.п.) кладите в `.ddev/config.local.yaml` — он не коммитится.
