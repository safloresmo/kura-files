import QtQuick
import QtQuick.Shapes
import Ryoku.Ui.Singletons

// Line icon drawn on a 24 unit grid, stroked in a theme colour.
Item {
    id: icon

    property string name: "file"
    property color color: Tokens.inkDim
    property real size: 18

    readonly property var paths: ({
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
            "eject": "M6 14l6-8 6 8zM6 18h12"
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
