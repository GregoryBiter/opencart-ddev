#!/usr/bin/env bash
# Установка opencart-ddev в существующий сайт OpenCart.
#
# Без клонирования (из корня сайта):
#   curl -fsSL https://raw.githubusercontent.com/GregoryBiter/opencart-ddev/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- /path/to/site --force
#
# Из клона репозитория:
#   ./install.sh [/path/to/site] [--force]
#
#   /path/to/site — папка сайта (по умолчанию текущая)
#   --force       — ставить даже если папка не похожа на OpenCart
#
# Переменные окружения:
#   OC_DDEV_REPO    — репозиторий GitHub (по умолчанию GregoryBiter/opencart-ddev)
#   OC_DDEV_REF     — ветка или тег (по умолчанию main)
#   OC_DDEV_ARCHIVE — прямая ссылка на .tar.gz с китом (перекрывает REPO/REF)
#
# Что копируется в сайт:
#   Makefile                         — команды make (старый Makefile → Makefile.bak)
#   .ddev/commands/web/oc-*          — команды ddev oc-config / oc-ocmod / oc-cache
#   .ddev/opencart/                  — служебные скрипты
#   .ddev/web-build/Dockerfile.ioncube, .ddev/php/opencart.ini
# .ddev/config.yaml не создаётся здесь — его делает `make init` (ddev config).

set -euo pipefail

# Всё в функции: при обрыве загрузки (curl | bash) не выполнится часть скрипта
main() {

    MARK="opencart-ddev"
    OC_DDEV_REPO="${OC_DDEV_REPO:-GregoryBiter/opencart-ddev}"
    OC_DDEV_REF="${OC_DDEV_REF:-main}"
    OC_DDEV_ARCHIVE="${OC_DDEV_ARCHIVE:-https://github.com/${OC_DDEV_REPO}/archive/${OC_DDEV_REF}.tar.gz}"

    TARGET="."
    FORCE=0
    for arg in "$@"; do
        case "$arg" in
            --force) FORCE=1 ;;
            -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null || true; exit 0 ;;
            -*) echo "Неизвестный параметр: $arg" >&2; exit 1 ;;
            *) TARGET="$arg" ;;
        esac
    done

    if [ ! -d "$TARGET" ]; then
        echo "Ошибка: папка $TARGET не найдена." >&2
        exit 1
    fi
    TARGET="$(cd "$TARGET" && pwd)"

    if [ "$FORCE" != 1 ] && { [ ! -d "$TARGET/catalog" ] || [ ! -d "$TARGET/system" ]; }; then
        echo "Ошибка: в $TARGET нет catalog/ и system/ — не похоже на OpenCart. Используйте --force." >&2
        exit 1
    fi

    # --- Откуда брать кит: рядом со скриптом (клон) или скачать архив (curl | bash) ---
    KIT_DIR=""
    SCRIPT_PATH="${BASH_SOURCE[0]:-}"
    if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
        CANDIDATE="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)/kit"
        [ -d "$CANDIDATE" ] && KIT_DIR="$CANDIDATE"
    fi

    if [ -z "$KIT_DIR" ]; then
        command -v curl >/dev/null 2>&1 || { echo "Ошибка: нужен curl." >&2; exit 1; }
        command -v tar  >/dev/null 2>&1 || { echo "Ошибка: нужен tar." >&2; exit 1; }
        TMP_DIR="$(mktemp -d)"
        trap 'rm -rf "$TMP_DIR"' EXIT
        echo "Загрузка кита: $OC_DDEV_ARCHIVE"
        if ! curl -fsSL "$OC_DDEV_ARCHIVE" | tar -xz -C "$TMP_DIR" --strip-components=1 2>/dev/null; then
            echo "Ошибка: не удалось скачать $OC_DDEV_ARCHIVE" >&2
            echo "Проверьте, что репозиторий публичный и ветка/тег '$OC_DDEV_REF' существует." >&2
            exit 1
        fi
        KIT_DIR="$TMP_DIR/kit"
        if [ ! -d "$KIT_DIR" ]; then
            echo "Ошибка: в архиве нет папки kit/." >&2
            exit 1
        fi
    fi

    if ! command -v ddev >/dev/null 2>&1; then
        echo "⚠ ddev не установлен: https://docs.ddev.com/en/stable/users/install/ddev-installation/"
    fi

    echo "Установка opencart-ddev в $TARGET"

    # --- .ddev: файлы кита (перезаписываются при обновлении, config.yaml не трогаем) ---
    mkdir -p "$TARGET/.ddev"
    cp -R "$KIT_DIR/.ddev/." "$TARGET/.ddev/"
    chmod +x "$TARGET"/.ddev/commands/web/oc-* "$TARGET/.ddev/opencart/lib.sh"
    echo "✓ .ddev/ (команды oc-config, oc-ocmod, oc-cache, ionCube, php.ini)"

    # --- Makefile ---
    if [ ! -f "$TARGET/Makefile" ]; then
        cp "$KIT_DIR/Makefile" "$TARGET/Makefile"
        echo "✓ Makefile"
    elif cmp -s "$KIT_DIR/Makefile" "$TARGET/Makefile"; then
        echo "✓ Makefile уже актуален"
    elif grep -q "$MARK" "$TARGET/Makefile"; then
        cp "$KIT_DIR/Makefile" "$TARGET/Makefile"
        echo "✓ Makefile обновлён"
    else
        cp -p "$TARGET/Makefile" "$TARGET/Makefile.bak"
        cp "$KIT_DIR/Makefile" "$TARGET/Makefile"
        echo "✓ Makefile (ваш прежний сохранён в Makefile.bak)"
    fi

    # --- .gitignore ---
    GI="$TARGET/.gitignore"
    if ! grep -qs "# >>> $MARK" "$GI"; then
        [ -s "$GI" ] && [ -n "$(tail -c1 "$GI")" ] && echo >> "$GI"
        cat >> "$GI" <<EOF

# >>> $MARK
# Бэкапы конфигов, созданные make config
/config.php.bak
/admin/config.php.bak
# Дампы БД (содержат данные клиентов)
/*.sql
/*.sql.gz
/*.sql.zip
# <<< $MARK
EOF
        echo "✓ .gitignore дополнен"
    fi

    cat <<EOF

Готово. Дальше:
  cd "$TARGET"
  # положите дамп базы (*.sql или *.sql.gz) в корень сайта
  make setup            # DDEV + импорт дампа + конфиги + модификации
  make open             # https://$(basename "$TARGET" | tr '[:upper:]_' '[:lower:]-').ddev.site

Все команды: make help
EOF
}

main "$@"
