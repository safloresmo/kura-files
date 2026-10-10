# Kura Files 庫

Gestor de archivos de escritorio para Linux: interfaz en QML sobre Quickshell y un motor en Rust sin dependencias. Funciona en cualquier compositor Wayland.

![Kura Files](docs/captura.png)

## Qué hace

- Lista, lista compacta, cuadrícula y galería, con miniaturas y vista rápida.
- Pestañas, doble panel, marcadores, recientes y papelera con restaurar.
- Copiar, mover, renombrar (también en lote), duplicar, enlazar, comprimir y extraer, con deshacer y rehacer. Nunca sobrescribe.
- Búsqueda por nombre, dentro del contenido y en toda la carpeta personal con índice (hace falta `plocate`), filtro por tipo y orden por nombre, tamaño, fecha o tipo.
- Más de 900 extensiones reconocidas, con icono, color y etiqueta.
- Discos y servidores de red (SFTP y otros por GVFS).
- Envío de archivos por Tailscale y LocalSend.
- Paleta de comandos (Ctrl+K) y hoja de atajos (F1).
- Atiende «mostrar en carpeta» de otros programas (`bin/archivos-servicio`).
- Sirve de selector de archivos para otros programas a través del portal del escritorio (`bin/archivos-portal`).

## Acciones

El clic derecho ofrece los menús de servicio que entiende Dolphin (`kio/servicemenus`) y los que pongas en `~/.config/archivos/acciones/`. Uno propio es un archivo `.desktop`:

```ini
[Desktop Entry]
Type=Service
MimeType=image/*;
Actions=a-jpg;

[Desktop Action a-jpg]
Name=Convertir a JPG
Exec=magick %f %f.jpg
```

`%f` es el primer archivo, `%F` todos, `%d` su carpeta y `%n` su nombre.

También aparecen ahí los scripts de `~/.local/share/nautilus/scripts`, que reciben la selección como argumentos.

Un repositorio de scripts se instala entero desde la paleta de comandos, con «Instalar acciones desde un repositorio»: se clona en `~/.local/share/archivos/acciones/` y sus programas pasan al mismo menú. Desde ahí también se actualiza o se quita.

## Requisitos

Linux con [Quickshell](https://quickshell.org) (probado con la 0.3.1) en cualquier compositor Wayland: Hyprland, Niri, Sway, KDE u otro. No depende de ningún escritorio concreto.

- Para compilar el motor: Rust.
- En el sistema: `gio` (GLib y GVFS), `bsdtar`, `sha256sum`, `wl-clipboard` y `jq`.
- Opcionales: `plocate` para la búsqueda con índice, `git` para instalar acciones, `tailscale` y `localsend` para enviar archivos, y Python con PyGObject para los dos servicios.
- Tipografías: Space Grotesk y SpaceMono Nerd Font; si faltan, se usan las del sistema.

## Aspecto

Los colores siguen la paleta que el escritorio saca del fondo de pantalla, si publica una: la de pywal (`~/.cache/wal/colors.json`) o la propia de algunos escritorios. Sin ninguna, usa un tema oscuro propio.

Cualquier valor se puede fijar en `~/.config/archivos/tema.json`:

```json
{ "paper": "#0b1626", "ink": "#cfe0f5", "sun": "#6ea8ff", "ui": "Inter", "mono": "JetBrains Mono", "scale": 1.1 }
```

Las claves son `paper`, `paperLift`, `ink`, `inkDim`, `bone`, `inkOnBone`, `sun`, `ui`, `mono` y `scale`.

## Instalación

Primero, lo que necesita. Las listas de paquetes son orientativas: los nombres cambian entre versiones.

```sh
# Arch y derivadas
sudo pacman -S quickshell rust glib2 gvfs libarchive jq wl-clipboard python-gobject plocate

# Debian y Ubuntu (Quickshell no está empaquetado: se compila aparte)
sudo apt install cargo libglib2.0-bin gvfs gvfs-backends libarchive-tools jq wl-clipboard python3-gi plocate

# Fedora (Quickshell está en COPR)
sudo dnf install cargo glib2 gvfs bsdtar jq wl-clipboard python3-gobject plocate
```

Después:

```sh
git clone https://github.com/safloresmo/kura-files
cd kura-files
./instalar
```

`./instalar` compila el motor, pone la orden `archivos` en `~/.local/bin` y añade el lanzador. No escribe nada fuera de tu carpeta personal. Con `--servicios` añade «mostrar en carpeta» y el selector de archivos para otros programas; con `--por-defecto` lo deja como gestor de archivos; con `--quitar` lo deshace todo menos tus ajustes.

## Uso

```sh
archivos [carpeta]     # abre la ventana
archivos ayuda         # el resto de órdenes
archivos compilar      # vuelve a compilar el motor tras actualizar
archivos pruebas       # pruebas del motor y de la ventana
```

## Licencia

MIT. Consulta `LICENSE`.
