import QtQuick
import QtQuick.Shapes

// Line icon drawn on a 24 unit grid, stroked in a theme colour.
Item {
    id: icon

    property string name: "file"
    property color color: Tokens.inkDim
    property real size: 18

    readonly property var paths: ({
            "grid": "M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z",
            "rows": "M4 6h16M4 12h16M4 18h16",
            "eye": "M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12zM12 9.5a2.5 2.5 0 1 1 0 5a2.5 2.5 0 1 1 0-5z",
            "command": "M9 9V6.5A2.5 2.5 0 1 0 6.5 9H9zM9 9h6M9 9v6M15 9V6.5A2.5 2.5 0 1 1 17.5 9H15zM15 9v6M15 15H9M15 15v2.5a2.5 2.5 0 1 0 2.5-2.5H15zM9 15v2.5A2.5 2.5 0 1 1 6.5 15H9z",
            "folder": "M3 7.5V18a1.5 1.5 0 0 0 1.5 1.5h15A1.5 1.5 0 0 0 21 18V9a1.5 1.5 0 0 0-1.5-1.5h-7L10 5H4.5A1.5 1.5 0 0 0 3 6.5z",
            "home": "M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z",
            "desktop": "M4.5 5h15a1.5 1.5 0 0 1 1.5 1.5v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 15.5v-9A1.5 1.5 0 0 1 4.5 5zM9 20h6M12 17v3",
            "file": "M7 3h7l4 4v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM14 3v4h4",
            "doc": "M7 3h7l4 4v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM14 3v4h4M9 12h6M9 16h6",
            "download": "M12 4v11M7 11l5 5 5-5M5 20h14",
            "music": "M9 18V6l10-2v12M9 18a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0zM19 16a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0z",
            "image": "M4.5 5h15a1.5 1.5 0 0 1 1.5 1.5v11a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5v-11A1.5 1.5 0 0 1 4.5 5zM3 16l5-5 4 4 3-3 6 6",
            "video": "M4.5 6h10A1.5 1.5 0 0 1 16 7.5v9a1.5 1.5 0 0 1-1.5 1.5h-10A1.5 1.5 0 0 1 3 16.5v-9A1.5 1.5 0 0 1 4.5 6zM16 10l5-3v10l-5-3",
            "trash": "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6",
            "disk": "M4.5 13h15a1.5 1.5 0 0 1 1.5 1.5v3a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5v-3A1.5 1.5 0 0 1 4.5 13zM5 13l2-7h10l2 7",
            "usb": "M8.5 9h7A1.5 1.5 0 0 1 17 10.5v9a1.5 1.5 0 0 1-1.5 1.5h-7A1.5 1.5 0 0 1 7 19.5v-9A1.5 1.5 0 0 1 8.5 9zM9 9V3h6v6",
            "archive": "M7 3h7l4 4v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM11 5v2M11 9v2M11 13v2",
            "code": "M8 8l-4 4 4 4M16 8l4 4-4 4M13 6l-2 12",
            "script": "M5 6l5 6-5 6M12 18h7",
            "config": "M4 7h10M18 7h2M4 12h4M12 12h8M4 17h12M14 5v4M8 10v4M16 15v4",
            "package": "M3.5 8h17v11.5h-17zM3.5 8l2.5-4h12l2.5 4M12 4v8M9.5 12h5",
            "model": "M12 3l8 4.5v9L12 21l-8-4.5v-9zM4 7.5l8 4.5 8-4.5M12 12v9",
            "print": "M12 4l8 4-8 4-8-4zM4 12l8 4 8-4M4 16l8 4 8-4",
            "board": "M4 5h16v14H4zM9.5 9.5a1 1 0 1 1-2 0a1 1 0 1 1 2 0zM8.5 10.5v3l3 2.5h4.5M16.5 9.5a1 1 0 1 1-2 0a1 1 0 1 1 2 0z",
            "chip": "M8 8h8v8H8zM10 4v4M14 4v4M10 16v4M14 16v4M4 10h4M4 14h4M16 10h4M16 14h4",
            "draft": "M4 20V6l14 14zM8 16v-3l3 3z",
            "vector": "M4 18C8 4 16 4 20 18M4 18h.01M20 18h.01M8 8h8M8 8h.01M16 8h.01",
            "wave": "M3 12h2M7 8v8M11 5v14M15 9v6M19 11v2",
            "subtitle": "M3 6h18v12H3zM7 14h4M13 14h4M7 10h2M11 10h6",
            "list": "M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01",
            "web": "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0zM3.5 12h17M12 3.5c3 3 3 14 0 17M12 3.5c-3 3-3 14 0 17",
            "shader": "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0zM7 14c3 3 8 3 10-1M9 8h.01",
            "notebook": "M7 3h11v18H7zM4 7h3M4 12h3M4 17h3M10.5 8h4",
            "diff": "M8 5v6M5 8h6M13 16h6M17 4L7 20",
            "lib": "M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z",
            "book": "M6 3h12v18H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM4 17.5A1.5 1.5 0 0 1 5.5 16H18",
            "sheet": "M4 5h16v14H4zM4 10h16M4 15h16M10 5v14",
            "slides": "M3 5h18v11H3zM12 16v4M8 20h8M8 12l3-3 2 2 3-3",
            "log": "M5 4h14v16H5zM8 8h8M8 12h8M8 16h4",
            "mail": "M3 6h18v12H3zM3 7l9 6 9-6",
            "calendar": "M4 6h16v14H4zM4 10h16M8 3v4M16 3v4",
            "contact": "M16 8a4 4 0 1 1-8 0a4 4 0 1 1 8 0zM4 21c0-4 3.6-6 8-6s8 2 8 6",
            "map": "M9 4l-6 2v14l6-2 6 2 6-2V4l-6 2zM9 4v14M15 6v14",
            "link": "M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1",
            "game": "M7 8h10a4 4 0 0 1 4 4v3a2.5 2.5 0 0 1-4.6 1.3L15 14H9l-1.4 2.3A2.5 2.5 0 0 1 3 15v-3a4 4 0 0 1 4-4zM8 10.5v3M6.5 12h3M15.5 11h.01M17.5 13h.01",
            "lock": "M6 11h12v9H6zM9 11V8a3 3 0 0 1 6 0v3",
            "container": "M4 12h4v4H4zM9 12h4v4H9zM14 12h4v4h-4zM9 7h4v4H9zM3 18c3 3 14 3 18-3",
            "git": "M6 6v12M18 6v4c0 3-6 2-6 6M6 6h.01M6 18h.01M18 6h.01M12 16h.01",
            "seal": "M17 9a5 5 0 1 1-10 0a5 5 0 1 1 10 0zM9 13.5L7.5 21l4.5-2.5 4.5 2.5-1.5-7.5",
            "info": "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0zM12 11v5M12 8h.01",
            "disc": "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0zM14 12a2 2 0 1 1-4 0a2 2 0 1 1 4 0z",
            "pdf": "M7 3h7l4 4v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM14 3v4h4M9.5 11.5h5v6l-2.5-2-2.5 2z",
            "data": "M5 6c0-1.7 3.1-3 7-3s7 1.3 7 3-3.1 3-7 3-7-1.3-7-3zM5 6v12c0 1.7 3.1 3 7 3s7-1.3 7-3V6M5 12c0 1.7 3.1 3 7 3s7-1.3 7-3",
            "font": "M6 19l6-14 6 14M8.5 14h7",
            "key": "M14.5 9.5a4 4 0 1 1-8 0a4 4 0 1 1 8 0zM13 12.5l6 6M16.5 16l2-2",
            "eject": "M6 14l6-8 6 8zM6 18h12",
            "clock": "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0zM12 7v5l3 2",
            "network": "M20.5 12a8.5 8.5 0 1 1-17 0a8.5 8.5 0 1 1 17 0zM3.5 12h17M12 3.5c3 3 3 14 0 17M12 3.5c-3 3-3 14 0 17"
        })

    width: size
    height: size

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: icon.color
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.paths[icon.name] || icon.paths.file }
        }
    }
}
