#!/usr/bin/env bash
# Установка opencart-ddev в существующий сайт OpenCart.
#
#   ./install.sh /path/to/site          — установить / обновить
#   ./install.sh /path/to/site --force  — ставить даже если папка не похожа на OpenCart
#
# Что копируется в сайт:
#   Makefile                         — команды make (старый Makefile → Makefile.bak)
#   .ddev/commands/web/oc-*          — команды ddev oc-config / oc-ocmod / oc-cache
#   .ddev/opencart/                  — служебные скрипты
#   .ddev/web-build/Dockerfile.ioncube, .ddev/php/opencart.ini
# .ddev/config.yaml не создаётся здесь — его делает `make init` (ddev config).

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kit"
MARK="opencart-ddev"

TARGET="${1:-}"
FORCE=0
[ "${2:-}" = "--force" ] && FORCE=1

if [ -z "$TARGET" ]; then
    echo "Использование: $0 /path/to/opencart-site [--force]" >&2
    exit 1
fi
if [ ! -d "$TARGET" ]; then
    echo "Ошибка: папка $TARGET не найдена." >&2
    exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

if [ ! -d "$KIT_DIR" ]; then
    echo "Ошибка: не найдена папка kit/ рядом с install.sh ($KIT_DIR)." >&2
    exit 1
fi

if [ "$FORCE" != 1 ] && { [ ! -d "$TARGET/catalog" ] || [ ! -d "$TARGET/system" ]; }; then
    echo "Ошибка: в $TARGET нет catalog/ и system/ — не похоже на OpenCart. Используйте --force." >&2
    exit 1
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
  cd $TARGET
  # положите дамп базы (*.sql или *.sql.gz) в корень сайта
  make setup            # DDEV + импорт дампа + конфиги + модификации
  make open             # https://$(basename "$TARGET" | tr '[:upper:]_' '[:lower:]-').ddev.site

Все команды: make help
EOF
