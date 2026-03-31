import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    width: 640
    height: 480
    color: "#1e1e2e"

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        onLoginSucceeded: {
            errorMessage.color = "#a6e3a1"
            errorMessage.text = textConstants.loginSucceeded
        }
        onLoginFailed: {
            errorMessage.color = "#f38ba8"
            errorMessage.text = textConstants.loginFailed
            password.text = ""
            password.focus = true
        }
    }

    // Fill all screens with the background color
    Repeater {
        model: screenModel
        Rectangle {
            x: geometry.x; y: geometry.y
            width: geometry.width; height: geometry.height
            color: "#1e1e2e"
        }
    }

    // Primary screen
    Item {
        property variant geometry: screenModel.geometry(screenModel.primary)
        x: geometry.x; y: geometry.y
        width: geometry.width; height: geometry.height

        // ── TOP ZONE: Clock ──────────────────────────────────────
        Column {
            id: clockZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.10
            spacing: 6

            Text {
                id: timeLabel
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#cdd6f4"
                font.pixelSize: 72
                font.weight: Font.Light
                text: Qt.formatTime(new Date(), "hh:mm")
            }

            Text {
                id: dateLabel
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#585b70"
                font.pixelSize: 16
                text: Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                var now = new Date()
                timeLabel.text = Qt.formatTime(now, "hh:mm")
                dateLabel.text = Qt.formatDate(now, "dddd, d MMMM yyyy")
            }
        }

        // ── CENTER ZONE: Login card ───────────────────────────────
        Rectangle {
            id: loginCard
            anchors.centerIn: parent
            width: 340
            height: cardColumn.implicitHeight + 48
            color: "#313244"
            radius: 8

            Column {
                id: cardColumn
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 16

                // Hostname welcome
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#cdd6f4"
                    font.pixelSize: 15
                    font.bold: true
                    text: sddm.hostName
                }

                // Username
                Column {
                    width: parent.width
                    spacing: 4
                    Text {
                        color: "#585b70"
                        text: textConstants.userName
                        font.pixelSize: 11
                        font.bold: true
                    }
                    TextBox {
                        id: name
                        width: parent.width
                        height: 36
                        text: userModel.lastUser
                        font.pixelSize: 14
                        color: "#313244"
                        textColor: "#cdd6f4"
                        borderColor: "#45475a"
                        focusColor: "#89b4fa"
                        hoverColor: "#585b70"
                        KeyNavigation.backtab: rebootButton
                        KeyNavigation.tab: password
                        Keys.onPressed: {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                sddm.login(name.text, password.text, session.index)
                                event.accepted = true
                            }
                        }
                    }
                }

                // Password
                Column {
                    width: parent.width
                    spacing: 4
                    Text {
                        color: "#585b70"
                        text: textConstants.password
                        font.pixelSize: 11
                        font.bold: true
                    }
                    PasswordBox {
                        id: password
                        width: parent.width
                        height: 36
                        font.pixelSize: 14
                        color: "#313244"
                        textColor: "#cdd6f4"
                        borderColor: "#45475a"
                        focusColor: "#89b4fa"
                        hoverColor: "#585b70"
                        tooltipBG: "#1e1e2e"
                        KeyNavigation.backtab: name
                        KeyNavigation.tab: loginButton
                        Keys.onPressed: {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                sddm.login(name.text, password.text, session.index)
                                event.accepted = true
                            }
                        }
                    }
                }

                // Error / status
                Text {
                    id: errorMessage
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: textConstants.prompt
                    color: "#585b70"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                // Login button
                Button {
                    id: loginButton
                    text: textConstants.login
                    width: parent.width
                    height: 36
                    font.pixelSize: 14
                    color: "#89b4fa"
                    onClicked: sddm.login(name.text, password.text, session.index)
                    KeyNavigation.backtab: password
                    KeyNavigation.tab: session
                }

                // Session + Layout row
                Row {
                    width: parent.width
                    spacing: 8

                    Column {
                        width: (parent.width - 8) / 2
                        spacing: 4
                        Text {
                            color: "#585b70"
                            text: textConstants.session
                            font.pixelSize: 11
                            font.bold: true
                        }
                        ComboBox {
                            id: session
                            width: parent.width
                            height: 32
                            font.pixelSize: 13
                            model: sessionModel
                            index: sessionModel.lastIndex
                            arrowIcon: "angle-down.png"
                            color: "#313244"
                            menuColor: "#313244"
                            textColor: "#cdd6f4"
                            borderColor: "#45475a"
                            focusColor: "#89b4fa"
                            hoverColor: "#45475a"
                            arrowColor: "#313244"
                            KeyNavigation.backtab: loginButton
                            KeyNavigation.tab: layoutBox
                        }
                    }

                    Column {
                        width: (parent.width - 8) / 2
                        spacing: 4
                        Text {
                            color: "#585b70"
                            text: textConstants.layout
                            font.pixelSize: 11
                            font.bold: true
                        }
                        LayoutBox {
                            id: layoutBox
                            width: parent.width
                            height: 32
                            font.pixelSize: 13
                            arrowIcon: "angle-down.png"
                            color: "#313244"
                            menuColor: "#313244"
                            textColor: "#cdd6f4"
                            borderColor: "#45475a"
                            focusColor: "#89b4fa"
                            hoverColor: "#45475a"
                            arrowColor: "#313244"
                            rowDelegate: Rectangle {
                                color: "transparent"
                                Image {
                                    id: flagImg
                                    source: "/usr/share/sddm/flags/%1.png".arg(modelItem ? modelItem.modelData.shortName : "zz")
                                    anchors.margins: 4
                                    fillMode: Image.PreserveAspectFit
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                }
                                Text {
                                    anchors.margins: 4
                                    anchors.left: flagImg.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelItem ? modelItem.modelData.shortName : "zz"
                                    font.pixelSize: 13
                                    color: "#cdd6f4"
                                }
                            }
                            KeyNavigation.backtab: session
                            KeyNavigation.tab: shutdownButton
                        }
                    }
                }
            }
        }

        // ── BOTTOM ZONE: Power buttons ────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.06
            spacing: 16

            Button {
                id: shutdownButton
                text: textConstants.shutdown
                height: 30
                font.pixelSize: 12
                color: "#45475a"
                textColor: "#cdd6f4"
                onClicked: sddm.powerOff()
                KeyNavigation.backtab: layoutBox
                KeyNavigation.tab: rebootButton
            }

            Button {
                id: rebootButton
                text: textConstants.reboot
                height: 30
                font.pixelSize: 12
                color: "#45475a"
                textColor: "#cdd6f4"
                onClicked: sddm.reboot()
                KeyNavigation.backtab: shutdownButton
                KeyNavigation.tab: name
            }
        }
    }

    Component.onCompleted: {
        if (name.text == "")
            name.focus = true
        else
            password.focus = true
    }
}
