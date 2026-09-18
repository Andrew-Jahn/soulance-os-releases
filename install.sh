#!/bin/sh
# Установка Soulance OS на Linux одной командой.
#
#   curl -fsSL https://soulance.ru/install.sh | sh
#
# Скачивает последнюю сборку, кладёт её в ~/.local/share, достаёт иконку из
# неё самой и заводит ярлык в меню приложений. Повторный запуск обновляет.
#
# Права root не нужны: всё ставится в домашнюю папку.
set -eu

REPO="Andrew-Jahn/soulance-os-releases"
NAME="Soulance OS"
BIN="soulanceapp"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
grn() { printf '\033[32m%s\033[0m\n' "$*"; }
dim() { printf '\033[2m%s\033[0m\n' "$*"; }

command -v curl >/dev/null 2>&1 || { red "Нужен curl."; exit 1; }

case "$(uname -m)" in
  x86_64|amd64) ARCH="x86_64" ;;
  *) red "Сборки под $(uname -m) пока нет — только x86_64."; exit 1 ;;
esac

echo "Ищу последнюю версию…"
# Адрес файла берём из описания релиза, а не собираем по шаблону: имя
# содержит версию, и шаблон устарел бы на следующем выпуске.
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o "https://[^\"]*${ARCH}\.AppImage" | head -n 1)
[ -n "$URL" ] || { red "Не нашёл сборку под $ARCH в последнем релизе."; exit 1; }

VERSION=$(printf '%s' "$URL" | sed -n 's/.*-\([0-9][0-9.]*\)-.*/\1/p')
echo "Версия: ${VERSION:-неизвестна}"

APPS="$HOME/.local/share/soulance-os"
TARGET="$APPS/$BIN.AppImage"
DESKTOP="$HOME/.local/share/applications/$BIN.desktop"
ICONS="$HOME/.local/share/icons/hicolor/512x512/apps"
mkdir -p "$APPS" "$ICONS" "$(dirname "$DESKTOP")"

# Запущенная копия держит файл, и запись поверх упала бы.
pkill -x "$BIN" 2>/dev/null || true

echo "Качаю…"
curl -fSL --progress-bar "$URL" -o "$TARGET.part"
mv "$TARGET.part" "$TARGET"
chmod +x "$TARGET"

# Иконку берём из самой сборки, чтобы меню и окно показывали одно и то же.
TMP=$(mktemp -d)
( cd "$TMP" && "$TARGET" --appimage-extract "usr/share/icons/hicolor/512x512/apps/*" >/dev/null 2>&1 ) || true
FOUND=$(find "$TMP" -name "$BIN.png" 2>/dev/null | head -n 1)
[ -n "$FOUND" ] && cp "$FOUND" "$ICONS/$BIN.png"
rm -rf "$TMP"

cat > "$DESKTOP" <<DESKTOP_ENTRY
[Desktop Entry]
Type=Application
Name=$NAME
Comment=Агент со знаниями компании
Exec="$TARGET" %U
Icon=$BIN
Terminal=false
StartupNotify=true
StartupWMClass=$BIN
Categories=Development;IDE;
MimeType=x-scheme-handler/$BIN;
DESKTOP_ENTRY

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

grn "$NAME ${VERSION:-} установлен."
echo "Запускай из меню приложений или командой:"
echo "  $TARGET"
dim "Обновления приложение проверяет само. Этот скрипт можно запустить"
dim "повторно, если захочешь поставить версию вручную."
