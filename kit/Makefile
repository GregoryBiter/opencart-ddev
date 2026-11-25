# =============================================================================
#  OpenCart + DDEV — быстрый локальный запуск существующего сайта (opencart-ddev)
# =============================================================================
# Имя проекта = имя папки (сайт будет https://<имя>.ddev.site)
PROJECT_NAME ?= $(notdir $(CURDIR))
PHP_VERSION  ?= 7.4
DB_TYPE      ?= mariadb
DB_VERSION   ?= 10.11
# Файл дампа: если не задан — ищется единственный *.sql / *.sql.gz / *.zip в корне
DB_FILE      ?=
EXPORT_FILE  ?= dump-$(shell date +%Y%m%d-%H%M).sql.gz

.DEFAULT_GOAL := help
.PHONY: help setup init start stop restart poweroff destroy status open admin ssh logs mail \
        xdebug-on xdebug-off php db-import db-export db-cli config ocmod cache cache-all permissions

help: ## Список команд
	@echo "OpenCart + DDEV ($(PROJECT_NAME), PHP $(PHP_VERSION))"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36mmake %-12s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Переменные: PHP_VERSION=$(PHP_VERSION) DB_TYPE=$(DB_TYPE) DB_VERSION=$(DB_VERSION) DB_FILE=<дамп>"

# --- Первый запуск ------------------------------------------------------------

setup: init db-import config ocmod ## Всё сразу: DDEV + импорт дампа + конфиги + модификации
	@echo
	@echo "✓ Сайт готов: https://$(PROJECT_NAME).ddev.site  (make open / make admin)"

init: ## Создать .ddev/config.yaml (если его нет) и запустить контейнеры
	@if [ -f .ddev/config.yaml ]; then \
		echo "DDEV уже настроен (.ddev/config.yaml) — просто запускаю."; \
	else \
		ddev config --project-name=$(PROJECT_NAME) --project-type=php --docroot=. \
			--webserver-type=apache-fpm --php-version=$(PHP_VERSION) \
			--database=$(DB_TYPE):$(DB_VERSION) --upload-dirs=image; \
	fi
	ddev start

# --- Жизненный цикл -----------------------------------------------------------

start: ## Запустить окружение
	ddev start

stop: ## Остановить проект (освободить ОЗУ)
	ddev stop

restart: ## Перезапустить (нужно после правок в .ddev/)
	ddev restart

poweroff: ## Остановить ВСЕ проекты DDEV
	ddev poweroff

destroy: ## Удалить контейнеры и БД проекта (файлы сайта остаются)
	ddev delete -O

status: ## Состояние, URL и доступы
	ddev describe

# --- Доступ и отладка ---------------------------------------------------------

open: ## Открыть витрину в браузере
	ddev launch

admin: ## Открыть админку в браузере
	@dir=$$(ddev exec 'source .ddev/opencart/lib.sh && oc_admin_dir' </dev/null 2>/dev/null | tr -d '\r'); \
	ddev launch "/$${dir:-admin}/"

ssh: ## Консоль web-контейнера
	ddev ssh

logs: ## Логи веб-сервера и PHP (Ctrl+C для выхода)
	ddev logs -f

mail: ## Открыть Mailpit (перехваченные письма сайта)
	ddev launch -m

xdebug-on: ## Включить Xdebug
	ddev xdebug on

xdebug-off: ## Выключить Xdebug
	ddev xdebug off

php: ## Сменить версию PHP: make php PHP_VERSION=8.1
	ddev config --php-version=$(PHP_VERSION)
	ddev restart

# --- База данных --------------------------------------------------------------

db-import: ## Импорт дампа (DB_FILE=site.sql.gz, по умолчанию — найденный в корне)
	@file="$(DB_FILE)"; \
	if [ -z "$$file" ]; then \
		files=$$(ls -1 *.sql *.sql.gz *.sql.zip 2>/dev/null); \
		count=$$(printf '%s\n' "$$files" | grep -c . || true); \
		if [ "$$count" = 1 ]; then file="$$files"; \
		elif [ "$$count" = 0 ]; then echo "Дамп не найден. Положите *.sql / *.sql.gz в корень или укажите DB_FILE=..."; exit 1; \
		else echo "Найдено несколько дампов, укажите нужный: make db-import DB_FILE=..."; echo "$$files"; exit 1; fi; \
	fi; \
	[ -f "$$file" ] || { echo "Файл $$file не найден"; exit 1; }; \
	echo "Импорт $$file ..."; \
	ddev import-db --file="$$file"

db-export: ## Бэкап БД (EXPORT_FILE=..., по умолчанию dump-<дата>.sql.gz)
	ddev export-db --file=$(EXPORT_FILE)
	@echo "✓ База сохранена в $(EXPORT_FILE)"

db-cli: ## Консоль MySQL
	ddev mysql

# --- OpenCart -----------------------------------------------------------------

config: ## Сгенерировать config.php и admin/config.php под DDEV (старые → *.bak)
	ddev oc-config

ocmod: ## Пересобрать OCMOD-модификации (кнопка «Обновить» в админке)
	ddev oc-ocmod

cache: ## Очистить кэш и пересобрать модификации
	ddev oc-cache

cache-all: ## То же + кэш изображений (image/cache)
	ddev oc-cache --images

permissions: ## Права на запись для image/ и system/storage/
	chmod -R u+rwX,g+rwX image/ system/storage/
	@echo "✓ Права обновлены"
