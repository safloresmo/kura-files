# Kura Files 庫

Gestor de archivos de escritorio para Linux: interfaz en QML sobre Quickshell y un motor en Rust sin dependencias.

![Kura Files](docs/captura.png)

## Qué hace

- Lista, lista compacta, cuadrícula y galería, con miniaturas y vista rápida.
- Pestañas, doble panel, marcadores, recientes y papelera con restaurar.
- Copiar, mover, renombrar (también en lote), duplicar, enlazar, comprimir y extraer, con deshacer y rehacer. Nunca sobrescribe.
- Búsqueda por nombre y dentro del contenido, filtro por tipo y orden por nombre, tamaño, fecha o tipo.
- Más de 900 extensiones reconocidas, con icono, color y etiqueta.
- Discos y servidores de red (SFTP y otros por GVFS).
- Envío de archivos por Tailscale y LocalSend.
- Paleta de comandos (Ctrl+K) y hoja de atajos (F1).

## Requisitos

Quickshell con los módulos de interfaz del escritorio, Rust para compilar el motor, y `gio`, `bsdtar` y `sha256sum` en el sistema.

## Uso

```sh
bin/archivos compilar      # compila el motor
bin/archivos [carpeta]     # abre la ventana
bin/archivos ayuda         # el resto de órdenes
bin/archivos pruebas       # pruebas del motor y de la ventana
```
