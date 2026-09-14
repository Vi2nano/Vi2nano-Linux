import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: "#0a0f14"

    property color accent: "#6ee7b7"
    property color textColor: "#e2e8f0"
    property color mutedColor: "#94a3b8"

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.82, 420)
        spacing: 16

        Text {
            width: parent.width
            text: "VI2NANO"
            color: root.accent
            font.family: "JetBrains Mono"
            font.pixelSize: 28
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            width: parent.width
            text: "Welcome back"
            color: root.textColor
            font.family: "JetBrains Mono"
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
        }

        TextField {
            id: userField
            width: parent.width
            text: userModel.lastUser
            placeholderText: "Username"
            color: root.textColor
            placeholderTextColor: root.mutedColor
            selectByMouse: true
            background: Rectangle {
                color: "#111923"
                border.color: userField.activeFocus ? root.accent : "#334155"
                border.width: 1
                radius: 8
            }
        }

        TextField {
            id: passwordField
            width: parent.width
            placeholderText: "Password"
            echoMode: TextInput.Password
            color: root.textColor
            placeholderTextColor: root.mutedColor
            selectByMouse: true
            onAccepted: loginButton.clicked()
            background: Rectangle {
                color: "#111923"
                border.color: passwordField.activeFocus ? root.accent : "#334155"
                border.width: 1
                radius: 8
            }
        }

        Button {
            id: loginButton
            width: parent.width
            text: "Sign in"
            onClicked: sddm.login(userField.text, passwordField.text, sessionModel.lastIndex)
            contentItem: Text {
                text: loginButton.text
                color: "#07110e"
                font.family: "JetBrains Mono"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: loginButton.down ? "#38bdf8" : root.accent
                radius: 8
            }
        }

        Text {
            id: errorText
            width: parent.width
            text: ""
            color: "#fda4af"
            font.family: "JetBrains Mono"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorText.text = "Login failed"
            passwordField.clear()
            passwordField.forceActiveFocus()
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}