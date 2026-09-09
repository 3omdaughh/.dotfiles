/*
 * wrench — an SDDM greeter theme
 *
 * Charcoal, monospace, mostly empty. The only ornament is a small LED
 * readout beside the username that changes with the authentication state.
 *
 * Everything visual is driven by theme.conf; see cfg() below.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root

    width: 1366
    height: 768
    color: cBase

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // ------------------------------------------------------------------
    // theme.conf plumbing
    // ------------------------------------------------------------------

    function cfg(key, fallback) {
        if (typeof config === "undefined" || config === null)
            return fallback
        var v = config[key]
        if (v === undefined || v === null || v === "")
            return fallback
        return v
    }

    function cfgNum(key, fallback) {
        var v = parseFloat(cfg(key, fallback))
        return isNaN(v) ? fallback : v
    }

    readonly property color cBase:        cfg("colorBase",        "#0a0a0b")
    readonly property color cSurface:     cfg("colorSurface",     "#111113")
    readonly property color cField:       cfg("colorField",       "#0c0c0e")
    readonly property color cBorder:      cfg("colorBorder",      "#242428")
    readonly property color cBorderHover: cfg("colorBorderHover", "#35353b")
    readonly property color cText:        cfg("colorText",        "#e4e4e1")
    readonly property color cMuted:       cfg("colorMuted",       "#6e6e77")
    readonly property color cDim:         cfg("colorDim",         "#43434a")
    readonly property color cAccent:      cfg("colorAccent",      "#d8bf55")
    readonly property color cAccentDim:   cfg("colorAccentDim",   "#7d6e33")
    readonly property color cError:       cfg("colorError",       "#b5564a")

    readonly property string mono: cfg("fontFamily", "monospace")

    // ------------------------------------------------------------------
    // Which screen carries the login form
    //
    // SDDM builds one greeter window per connected output and loads this
    // file into each, so by default every monitor shows its own login box.
    // `primaryScreen` is a per-window boolean, so each instance can decide
    // for itself: the primary screen keeps the form, the rest are left with
    // just the wallpaper. No external display manager is involved.
    //
    // Qt's idea of "primary" is not reliable on a laptop with an external
    // monitor attached at boot: it can land on the external head, leaving the
    // built-in panel with nothing but wallpaper. `loginOutput` in theme.conf
    // pins the form to a named output instead, and is ignored when that
    // output is not connected, so unplugging never leaves you formless.
    // ------------------------------------------------------------------
    readonly property bool isLoginScreen: {
        var want = cfg("loginOutput", "")
        if (want !== "") {
            // Honour the override only if that output is actually connected.
            // Otherwise unplugging it would leave every screen without a login
            // form, which locks you out of your own greeter.
            var all = Qt.application.screens
            var present = false
            if (all) {
                for (var i = 0; i < all.length; i++) {
                    if (all[i].name === want) {
                        present = true
                        break
                    }
                }
            }
            if (present)
                return Screen.name === want
        }
        return (typeof primaryScreen === "undefined") ? true : primaryScreen
    }

    // ------------------------------------------------------------------
    // session state
    // ------------------------------------------------------------------

    property bool busy: false
    property string message: ""
    property bool messageIsError: false
    property string hoverLabel: ""
    property var now: new Date()

    property string hostName: cfg("fallbackHost", "localhost")
    property string kernel: cfg("fallbackKernel", "Linux")

    // The mask. "." idle, "o" watching you type, "=" thinking, "x" refused,
    // "^" let you in.
    property string face: ". ."
    property color faceColor: cDim

    function setFace(f, c) { face = f; faceColor = c }

    // ------------------------------------------------------------------
    // runtime facts — /proc and /etc are world readable, so the greeter
    // can report the real kernel instead of a value baked in at install.
    // ------------------------------------------------------------------

    function readFile(path) {
        try {
            var x = new XMLHttpRequest()
            x.open("GET", "file://" + path, false)
            x.send(null)
            if (x.status === 200 || x.status === 0)
                return x.responseText
        } catch (e) { }
        return ""
    }

    Component.onCompleted: {
        var h = readFile("/etc/hostname").replace(/\s+$/, "")
        if (h.length > 0)
            hostName = h.split("\n")[0]

        var m = readFile("/proc/version").match(/^Linux version (\S+)/)
        if (m)
            kernel = "Linux " + m[1]

        // Only the screen actually showing the form should take the keyboard.
        if (isLoginScreen)
            passwordField.forceActiveFocus()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ------------------------------------------------------------------
    // login
    // ------------------------------------------------------------------

    function currentUser() {
        if (typeof userModel === "undefined")
            return ""
        return userBox.currentText
    }

    function doLogin() {
        if (busy)
            return
        root.message = ""
        root.busy = true
        setFace("= =", cAccentDim)
        sddm.login(currentUser(), passwordField.text, sessionBox.currentIndex)
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.busy = false
            root.messageIsError = false
            root.message = ""
            root.setFace("^ ^", root.cAccent)
        }

        function onLoginFailed() {
            root.busy = false
            root.messageIsError = true
            root.message = "authentication failed"
            root.setFace("x x", root.cError)
            passwordField.selectAll()
            passwordField.forceActiveFocus()
            shake.restart()
        }

        function onInformationMessage(message) {
            root.messageIsError = false
            root.message = message
        }
    }

    // ==================================================================
    // inline components
    // ==================================================================

    // Icons are drawn rather than shipped as SVG so their stroke can be
    // bound directly to a palette colour and animated on hover.
    component Glyph: Canvas {
        id: glyph

        property string kind: "power"
        property color stroke: root.cMuted

        width: 16
        height: 16
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        onStrokeChanged: requestPaint()
        onKindChanged: requestPaint()

        Behavior on stroke { ColorAnimation { duration: 130 } }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = stroke
            ctx.fillStyle = stroke
            ctx.lineWidth = 1.3
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            var w = width, h = height
            var cx = w / 2, cy = h / 2
            var r = w * 0.34

            if (kind === "power") {
                ctx.beginPath()
                ctx.arc(cx, cy + 0.8, r, -Math.PI * 0.36, Math.PI * 1.36)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(cx, cy - r - 1.6)
                ctx.lineTo(cx, cy - 0.6)
                ctx.stroke()

            } else if (kind === "restart") {
                var a0 = Math.PI * 0.42
                var a1 = Math.PI * 1.95
                ctx.beginPath()
                ctx.arc(cx, cy, r, a0, a1)
                ctx.stroke()
                // Arrowhead sits on the arc's end, aligned to the tangent, so
                // it reads as rotation rather than as a stray tick.
                var px = cx + r * Math.cos(a1)
                var py = cy + r * Math.sin(a1)
                var dx = -Math.sin(a1)
                var dy = Math.cos(a1)
                ctx.beginPath()
                ctx.moveTo(px + dx * 3.4, py + dy * 3.4)
                ctx.lineTo(px - dx * 1.3 - dy * 2.5, py - dy * 1.3 + dx * 2.5)
                ctx.lineTo(px - dx * 1.3 + dy * 2.5, py - dy * 1.3 - dx * 2.5)
                ctx.closePath()
                ctx.fill()

            } else if (kind === "suspend") {
                // Crescent: fill a disc, then punch a second disc out of it.
                // Opposite-winding subpaths are not reliable here, so erase
                // with destination-out instead.
                ctx.save()
                ctx.beginPath()
                ctx.arc(cx - 0.8, cy, r + 0.4, 0, Math.PI * 2)
                ctx.fill()
                ctx.globalCompositeOperation = "destination-out"
                ctx.beginPath()
                ctx.arc(cx + r * 0.70, cy - r * 0.50, r + 0.1, 0, Math.PI * 2)
                ctx.fill()
                ctx.restore()

            } else if (kind === "eye" || kind === "eyeoff") {
                ctx.beginPath()
                ctx.moveTo(cx - w * 0.42, cy)
                ctx.quadraticCurveTo(cx, cy - h * 0.36, cx + w * 0.42, cy)
                ctx.quadraticCurveTo(cx, cy + h * 0.36, cx - w * 0.42, cy)
                ctx.stroke()
                // The pupil is dropped when struck through, otherwise the two
                // shapes merge into a blob at 16px.
                if (kind === "eye") {
                    ctx.beginPath()
                    ctx.arc(cx, cy, w * 0.11, 0, Math.PI * 2)
                    ctx.stroke()
                } else {
                    ctx.beginPath()
                    ctx.moveTo(cx - w * 0.34, cy + h * 0.30)
                    ctx.lineTo(cx + w * 0.34, cy - h * 0.30)
                    ctx.stroke()
                }

            } else if (kind === "options") {
                // Sliders, not a cogwheel: at 16px a cog degenerates into a
                // sun and reads as a brightness control.
                ctx.beginPath()
                ctx.moveTo(cx - w * 0.36, cy - h * 0.17)
                ctx.lineTo(cx + w * 0.36, cy - h * 0.17)
                ctx.moveTo(cx - w * 0.36, cy + h * 0.17)
                ctx.lineTo(cx + w * 0.36, cy + h * 0.17)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(cx - w * 0.11, cy - h * 0.17, 2.0, 0, Math.PI * 2)
                ctx.fill()
                ctx.beginPath()
                ctx.arc(cx + w * 0.13, cy + h * 0.17, 2.0, 0, Math.PI * 2)
                ctx.fill()

            } else if (kind === "chevron") {
                ctx.beginPath()
                ctx.moveTo(cx - 3.2, cy - 1.6)
                ctx.lineTo(cx, cy + 1.8)
                ctx.lineTo(cx + 3.2, cy - 1.6)
                ctx.stroke()

            } else if (kind === "arrow") {
                ctx.beginPath()
                ctx.moveTo(cx - 4, cy)
                ctx.lineTo(cx + 3.6, cy)
                ctx.moveTo(cx + 0.6, cy - 3)
                ctx.lineTo(cx + 3.8, cy)
                ctx.lineTo(cx + 0.6, cy + 3)
                ctx.stroke()
            }
        }
    }

    component IconButton: Rectangle {
        id: iconButton

        property string kind: "power"
        property string label: ""
        property bool active: false
        property int diameter: 30

        signal activated()

        width: diameter
        height: diameter
        radius: 3
        color: hover.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        border.width: 1
        border.color: hover.hovered ? root.cBorderHover : "transparent"

        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }

        Glyph {
            anchors.centerIn: parent
            kind: iconButton.kind
            stroke: (iconButton.active || hover.hovered) ? root.cAccent : root.cMuted
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered)
                    root.hoverLabel = iconButton.label
                else if (root.hoverLabel === iconButton.label)
                    root.hoverLabel = ""
            }
        }

        TapHandler {
            onTapped: iconButton.activated()
        }
    }

    component Hairline: Rectangle {
        height: 1
        color: root.cBorder
    }

    // A popup that looks like the rest of the theme rather than like the
    // Qt Basic style.
    component Sheet: Popup {
        padding: 6
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.cSurface
            border.width: 1
            border.color: root.cBorder
            radius: 3
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110 }
                NumberAnimation { property: "y"; from: 4; duration: 140; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 }
        }
    }

    component SheetRow: Rectangle {
        id: sheetRow

        property string text: ""
        property bool selected: false

        signal activated()

        width: parent ? parent.width : 160
        height: 24
        radius: 2
        color: rowHover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 3
            radius: 1.5
            color: root.cAccent
            opacity: sheetRow.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: sheetRow.text
            elide: Text.ElideRight
            color: sheetRow.selected ? root.cText : root.cMuted
            font.family: root.mono
            font.pixelSize: 11
        }

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: sheetRow.activated() }
    }

    // ==================================================================
    // background
    // ==================================================================

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl(root.cfg("background", "assets/background.png"))
        fillMode: Image.PreserveAspectCrop
        opacity: root.cfgNum("backgroundOpacity", 0.42)
        asynchronous: true
        smooth: true
        mipmap: true
    }

    // Sink the skyline into the floor and take the edge off the star field.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.00; color: Qt.rgba(0.039, 0.039, 0.043, 0.45) }
            GradientStop { position: 0.42; color: Qt.rgba(0.039, 0.039, 0.043, 0.20) }
            GradientStop { position: 1.00; color: Qt.rgba(0.039, 0.039, 0.043, 0.72) }
        }
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl(root.cfg("grain", "assets/grain.png"))
        fillMode: Image.Tile
        opacity: root.cfgNum("grainOpacity", 0.05)
        asynchronous: true
    }

    // ==================================================================
    // corners
    // ==================================================================

    Column {
        id: sysInfo
        visible: root.isLoginScreen
        x: 34
        y: 30
        spacing: 4

        Row {
            spacing: 8
            Rectangle {
                width: 4
                height: 4
                radius: 1
                color: root.cAccent
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.hostName
                color: root.cText
                font.family: root.mono
                font.pixelSize: 12
                font.letterSpacing: 0.5
            }
        }

        Text {
            x: 12
            text: root.kernel
            color: root.cMuted
            font.family: root.mono
            font.pixelSize: 11
        }

        Text {
            x: 12
            text: root.cfg("arch", "x86_64") + "  ·  wayland"
            color: root.cDim
            font.family: root.mono
            font.pixelSize: 11
        }
    }

    Column {
        visible: root.isLoginScreen
        y: 30
        anchors.right: parent.right
        anchors.rightMargin: 34
        spacing: 2

        Text {
            anchors.right: parent.right
            text: Qt.formatTime(root.now, "HH:mm")
            color: root.cText
            font.family: root.mono
            font.pixelSize: 26
            font.letterSpacing: 1.5
        }

        Text {
            anchors.right: parent.right
            text: Qt.formatDate(root.now, "ddd dd MMM").toLowerCase()
            color: root.cMuted
            font.family: root.mono
            font.pixelSize: 11
            font.letterSpacing: 0.6
        }
    }

    // bottom left — input state
    Row {
        visible: root.isLoginScreen
        x: 34
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 14

        Text {
            text: {
                if (typeof keyboard === "undefined" || keyboard.layouts.length === 0)
                    return "us"
                return keyboard.layouts[keyboard.currentLayout].shortName.toLowerCase()
            }
            color: root.cDim
            font.family: root.mono
            font.pixelSize: 11
        }

        Text {
            text: "caps"
            color: root.cAccent
            font.family: root.mono
            font.pixelSize: 11
            opacity: (typeof keyboard !== "undefined" && keyboard.capsLock) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    // bottom right — power
    Row {
        visible: root.isLoginScreen
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        spacing: 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 10
            text: root.hoverLabel
            color: root.cDim
            font.family: root.mono
            font.pixelSize: 11
            opacity: root.hoverLabel === "" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 130 } }
        }

        IconButton {
            kind: "suspend"
            label: "suspend"
            visible: typeof sddm === "undefined" || sddm.canSuspend
            onActivated: sddm.suspend()
        }

        IconButton {
            kind: "restart"
            label: "restart"
            visible: typeof sddm === "undefined" || sddm.canReboot
            onActivated: sddm.reboot()
        }

        IconButton {
            kind: "power"
            label: "shut down"
            visible: typeof sddm === "undefined" || sddm.canPowerOff
            onActivated: sddm.powerOff()
        }
    }

    // ==================================================================
    // login panel
    // ==================================================================

    Item {
        id: panelAnchor

        visible: root.isLoginScreen
        width: root.cfgNum("panelWidth", 352)
        height: panel.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.cfgNum("panelOffsetY", -52)

        opacity: 0
        transform: Translate { id: slide; x: 0; y: 10 }

        Component.onCompleted: intro.start()

        ParallelAnimation {
            id: intro
            NumberAnimation { target: panelAnchor; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: slide; property: "y"; to: 0; duration: 340; easing.type: Easing.OutCubic }
        }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: slide; property: "x"; to: -3; duration: 45 }
            NumberAnimation { target: slide; property: "x"; to: 3; duration: 70 }
            NumberAnimation { target: slide; property: "x"; to: -2; duration: 60 }
            NumberAnimation { target: slide; property: "x"; to: 0; duration: 55 }
        }

        // barely-there lift off the wallpaper
        Rectangle {
            anchors.fill: panel
            anchors.margins: -6
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.28)
        }

        Rectangle {
            id: panel

            width: parent.width
            height: column.implicitHeight + 44
            radius: 3
            color: Qt.rgba(0.067, 0.067, 0.075, 0.94)
            border.width: 1
            border.color: root.cBorder

            // 1px inner top highlight, the way a raised GTK surface reads
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                color: Qt.rgba(1, 1, 1, 0.035)
            }

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: 22
                spacing: 0

                // ---------------- header: avatar, user, mask ----------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: root.cField
                            border.width: 1
                            border.color: root.cBorder
                        }

                        // The configured avatar belongs to one account; anyone
                        // else gets an initial so the face is never wrong.
                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            anchors.margins: 1
                            source: Qt.resolvedUrl(root.cfg("avatar", "assets/avatar.png"))
                            visible: root.currentUser() === root.cfg("avatarUser", "")
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !avatarImage.visible
                            text: root.currentUser().length > 0
                                  ? root.currentUser().charAt(0).toLowerCase()
                                  : "?"
                            color: root.cMuted
                            font.family: root.mono
                            font.pixelSize: 18
                        }

                        HoverHandler {
                            id: avatarHover
                            enabled: typeof userModel !== "undefined" && userModel.count > 1
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            enabled: avatarHover.enabled
                            onTapped: userSheet.open()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: root.currentUser()
                                color: root.cText
                                font.family: root.mono
                                font.pixelSize: 14
                                font.letterSpacing: 0.3
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // the mask
                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 15
                                radius: 2
                                color: root.cField
                                border.width: 1
                                border.color: root.cBorder

                                Text {
                                    anchors.centerIn: parent
                                    text: root.face
                                    color: root.faceColor
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    font.letterSpacing: 0.5
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: typeof userModel !== "undefined" && userModel.count > 1
                                      ? "switch user"
                                      : "local account"
                                color: root.cDim
                                font.family: root.mono
                                font.pixelSize: 10
                            }

                            Glyph {
                                visible: typeof userModel !== "undefined" && userModel.count > 1
                                width: 12
                                height: 12
                                kind: "chevron"
                                stroke: root.cDim
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                Hairline {
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                }

                // ---------------- password ----------------
                TextField {
                    id: passwordField

                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    Layout.preferredHeight: 34

                    echoMode: revealPassword.active ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 0
                    placeholderText: "password"
                    placeholderTextColor: root.cDim
                    selectByMouse: true
                    enabled: !root.busy

                    color: root.cText
                    selectionColor: root.cAccentDim
                    selectedTextColor: root.cText
                    font.family: root.mono
                    font.pixelSize: 13

                    leftPadding: 12
                    rightPadding: 38
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter

                    background: Rectangle {
                        color: root.cField
                        radius: 2
                        border.width: 1
                        border.color: passwordField.activeFocus ? root.cAccent : root.cBorder
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                    }

                    onActiveFocusChanged: {
                        if (activeFocus && !root.busy)
                            root.setFace("o o", root.cAccentDim)
                        else if (!root.busy && !root.messageIsError)
                            root.setFace(". .", root.cDim)
                    }

                    onTextChanged: {
                        if (root.messageIsError) {
                            root.messageIsError = false
                            root.message = ""
                            root.setFace("o o", root.cAccentDim)
                        }
                    }

                    Keys.onReturnPressed: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()

                    IconButton {
                        id: revealPassword
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        diameter: 28
                        kind: active ? "eye" : "eyeoff"
                        label: ""
                        onActivated: active = !active
                    }
                }

                // ---------------- log in ----------------
                Button {
                    id: loginButton

                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.preferredHeight: 32

                    enabled: !root.busy && passwordField.text.length > 0
                    onClicked: root.doLogin()

                    background: Rectangle {
                        radius: 2
                        color: loginButton.hovered && loginButton.enabled
                               ? Qt.rgba(0.847, 0.749, 0.333, 0.07)
                               : "transparent"
                        border.width: 1
                        border.color: !loginButton.enabled
                                      ? root.cBorder
                                      : (loginButton.hovered || loginButton.activeFocus ? root.cAccent : root.cBorderHover)
                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }
                    }

                    contentItem: Text {
                        text: root.busy ? "authenticating" : "log in"
                        color: !loginButton.enabled
                               ? root.cDim
                               : (loginButton.hovered ? root.cAccent : root.cText)
                        font.family: root.mono
                        font.pixelSize: 12
                        font.letterSpacing: 0.8
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                }

                // Height is reserved whether or not there is a message, so
                // the panel never resizes under the pointer.
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 9
                    Layout.preferredHeight: 13
                    text: root.message
                    color: root.messageIsError ? root.cError : root.cMuted
                    font.family: root.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    opacity: root.message === "" ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                }

                Hairline {
                    Layout.fillWidth: true
                    Layout.topMargin: 13
                }

                // ---------------- session + options ----------------
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 11
                    spacing: 8

                    ComboBox {
                        id: sessionBox

                        Layout.fillWidth: true
                        Layout.preferredHeight: 26

                        model: typeof sessionModel !== "undefined" ? sessionModel : null
                        textRole: "name"
                        currentIndex: typeof sessionModel !== "undefined" ? sessionModel.lastIndex : 0

                        leftPadding: 8
                        rightPadding: 22

                        background: Rectangle {
                            radius: 2
                            color: sessionBox.hovered ? Qt.rgba(1, 1, 1, 0.035) : "transparent"
                            border.width: 1
                            border.color: sessionBox.hovered ? root.cBorderHover : root.cBorder
                            Behavior on color { ColorAnimation { duration: 130 } }
                            Behavior on border.color { ColorAnimation { duration: 130 } }
                        }

                        contentItem: Text {
                            text: sessionBox.displayText
                            color: sessionBox.hovered ? root.cText : root.cMuted
                            font.family: root.mono
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }

                        indicator: Glyph {
                            x: sessionBox.width - width - 7
                            y: (sessionBox.height - height) / 2
                            width: 12
                            height: 12
                            kind: "chevron"
                            stroke: sessionBox.hovered ? root.cMuted : root.cDim
                        }

                        delegate: SheetRow {
                            required property int index
                            required property var model
                            width: sessionBox.width - 12
                            text: model.name
                            selected: sessionBox.currentIndex === index
                            onActivated: {
                                sessionBox.currentIndex = index
                                sessionBox.popup.close()
                            }
                        }

                        popup: Sheet {
                            y: sessionBox.height + 4
                            width: sessionBox.width
                            implicitHeight: Math.min(contentItem.implicitHeight + 12, 190)

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: sessionBox.popup.visible ? sessionBox.delegateModel : null
                                spacing: 1
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollIndicator.vertical: ScrollIndicator { }
                            }
                        }
                    }

                    IconButton {
                        id: optionsButton
                        kind: "options"
                        label: ""
                        diameter: 26
                        active: optionsSheet.opened
                        onActivated: optionsSheet.opened ? optionsSheet.close() : optionsSheet.open()

                        Sheet {
                            id: optionsSheet
                            x: optionsButton.width - width
                            y: -height - 6
                            width: 176

                            contentItem: Column {
                                spacing: 2

                                Text {
                                    leftPadding: 6
                                    bottomPadding: 3
                                    text: "keyboard layout"
                                    color: root.cDim
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    font.letterSpacing: 0.5
                                }

                                Repeater {
                                    model: typeof keyboard !== "undefined" ? keyboard.layouts : []
                                    delegate: SheetRow {
                                        required property int index
                                        required property var modelData
                                        width: 164
                                        text: modelData.shortName + "  —  " + modelData.longName
                                        selected: keyboard.currentLayout === index
                                        onActivated: {
                                            keyboard.currentLayout = index
                                            optionsSheet.close()
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 164
                                    height: 1
                                    color: root.cBorder
                                }

                                Text {
                                    leftPadding: 6
                                    topPadding: 4
                                    text: "num lock  " + ((typeof keyboard !== "undefined" && keyboard.numLock) ? "on" : "off")
                                    color: root.cDim
                                    font.family: root.mono
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- user picker ----------------
            Sheet {
                id: userSheet
                x: 22
                y: 60
                width: 200

                contentItem: Column {
                    spacing: 2

                    Text {
                        leftPadding: 6
                        bottomPadding: 3
                        text: "accounts"
                        color: root.cDim
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.5
                    }

                    Repeater {
                        model: typeof userModel !== "undefined" ? userModel : null
                        delegate: SheetRow {
                            required property int index
                            required property var model
                            width: 188
                            text: model.name
                            selected: userBox.currentIndex === index
                            onActivated: {
                                userBox.currentIndex = index
                                userSheet.close()
                                passwordField.clear()
                                passwordField.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }
    }

    // Backing store for the selected account. Kept off-screen because the
    // visible header is hand-built, but ComboBox gives correct role lookup.
    ComboBox {
        id: userBox
        visible: false
        model: typeof userModel !== "undefined" ? userModel : null
        textRole: "name"
        currentIndex: typeof userModel !== "undefined" ? userModel.lastIndex : 0
    }
}
