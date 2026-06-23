#!/usr/bin/env bash
#
# Migración de la PC de la tienda (Fedora) a la versión AppImage con
# auto-actualización. Ejecutar UNA sola vez. Conserva todos los datos
# (usa la misma base de datos que la versión .rpm anterior).
#
# Uso rápido en la laptop:
#   bash <(curl -fsSL https://raw.githubusercontent.com/diegomty/PuntoVenta-releases/main/migrar-tienda.sh)
#
set -uo pipefail

REPO="diegomty/PuntoVenta-releases"
DEST_DIR="$HOME/Aplicaciones"
APPIMAGE_PATH="$DEST_DIR/PuntoVenta.AppImage"
ICON_PATH="$HOME/.local/share/icons/puntoventa.png"
DESKTOP_FILE="$HOME/.local/share/applications/puntoventa.desktop"

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$1"; }
die()  { printf '\n\033[1;31m[error]\033[0m %s\n' "$1" >&2; exit 1; }

say "Migrando 'Punto de Venta' a la versión con auto-actualización…"

# 1. Asegurar FUSE (Fedora lo necesita para ejecutar AppImage)
if ! rpm -q fuse-libs >/dev/null 2>&1; then
  warn "Falta FUSE; intentando instalarlo (puede pedir tu contraseña)…"
  sudo dnf install -y fuse fuse-libs \
    || warn "No se pudo instalar FUSE solo. Si la app no abre, corre: sudo dnf install fuse fuse-libs"
fi

# 2. Descargar el AppImage más reciente publicado
say "Buscando la última versión publicada…"
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -oE 'https://[^"]+\.AppImage' | head -1)
[ -n "$URL" ] || die "No se encontró el AppImage del release. Revisa tu conexión a internet."

mkdir -p "$DEST_DIR"
say "Descargando AppImage…"
curl -fL --progress-bar -o "$APPIMAGE_PATH" "$URL" || die "Falló la descarga."
chmod +x "$APPIMAGE_PATH"

# 3. Extraer el ícono de la app (no requiere FUSE)
say "Preparando el ícono…"
TMP=$(mktemp -d)
( cd "$TMP" && "$APPIMAGE_PATH" --appimage-extract >/dev/null 2>&1 ) || true
mkdir -p "$(dirname "$ICON_PATH")"
ICON_SRC=$(find "$TMP/squashfs-root" -name '*.png' 2>/dev/null | sort -r | head -1)
[ -n "$ICON_SRC" ] && cp "$ICON_SRC" "$ICON_PATH"
rm -rf "$TMP"

# 4. Crear el acceso directo (aparece en el menú de aplicaciones)
say "Creando acceso directo…"
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Punto de Venta
Comment=Sistema de punto de venta
Exec=$APPIMAGE_PATH
Icon=${ICON_PATH:-utilities-terminal}
Terminal=false
Categories=Office;
EOF
chmod +x "$DESKTOP_FILE"
update-desktop-database "$(dirname "$DESKTOP_FILE")" >/dev/null 2>&1 || true

# 5. Copia opcional al Escritorio (si existe)
for d in "$HOME/Escritorio" "$HOME/Desktop"; do
  if [ -d "$d" ]; then
    cp "$DESKTOP_FILE" "$d/puntoventa.desktop" 2>/dev/null && chmod +x "$d/puntoventa.desktop" 2>/dev/null
    gio set "$d/puntoventa.desktop" metadata::trusted true 2>/dev/null || true
  fi
done

say "¡Listo! 🎉"
cat <<FIN
   • Busca 'Punto de Venta' en el menú de aplicaciones (o en el escritorio).
   • Tus productos, ventas y clientes siguen intactos (misma base de datos).
   • De aquí en adelante la app se actualiza sola al abrirla.

Para abrirla ahora mismo:
   $APPIMAGE_PATH
FIN
