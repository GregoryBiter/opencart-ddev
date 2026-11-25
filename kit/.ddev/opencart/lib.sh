#!/usr/bin/env bash
# Общие функции для команд opencart-ddev (выполняются внутри web-контейнера).

# Папка админки: явно заданная, admin/, либо любой каталог с controller/common/dashboard.php
# (админку на боевых сайтах часто переименовывают).
oc_admin_dir() {
    local wanted="${1:-${OC_ADMIN_DIR:-}}" d
    if [ -n "$wanted" ]; then
        if [ -d "/var/www/html/$wanted" ]; then echo "$wanted"; return 0; fi
        echo "Ошибка: папка админки '$wanted' не найдена." >&2; return 1
    fi
    if [ -f /var/www/html/admin/controller/common/dashboard.php ]; then echo admin; return 0; fi
    for d in /var/www/html/*/; do
        d="$(basename "$d")"
        [ "$d" = catalog ] && continue
        if [ -f "/var/www/html/$d/controller/common/dashboard.php" ]; then echo "$d"; return 0; fi
    done
    echo "Ошибка: не найдена папка админки. Укажите OC_ADMIN_DIR=<папка>." >&2
    return 1
}

# Очистка каталога без удаления index.html / .gitkeep
oc_clean_dir() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 1 \( -name index.html -o -name .gitkeep -o -name .htaccess \) -prune -o -type f -print0 | xargs -0r rm -f
    find "$dir" -mindepth 1 -type d -empty -delete
}
