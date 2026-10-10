# Kura Files 庫

Gestor de archivos de escritorio para Linux: interfaz en QML sobre Quickshell y un motor en Rust sin dependencias.

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

Quickshell con los módulos de interfaz del escritorio, Rust para compilar el motor, y `gio`, `bsdtar` y `sha256sum` en el sistema. Los dos servicios usan Python con PyGObject.

## Uso

```sh
bin/archivos compilar      # compila el motor
bin/archivos [carpeta]     # abre la ventana
bin/archivos ayuda         # el resto de órdenes
bin/archivos pruebas       # pruebas del motor y de la ventana
```
