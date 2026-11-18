/* PolarisOS — installer slideshow (Calamares, slideshowAPI 2)
 * Text-only slides on the PolarisOS colours, so no extra images are needed.
 */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 15000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    function onActivate() { }
    function onLeave() { }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#060C26"
            Column {
                anchors.centerIn: parent
                spacing: 18
                width: parent.width * 0.8
                Image {
                    source: "logo.png"
                    width: 96; height: 96
                    fillMode: Image.PreserveAspectFit
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("Welcome to PolarisOS")
                    color: "#FFFFFF"; font.pixelSize: 26; font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("A lightweight and secure system based on Debian. The installation will finish in a few minutes.")
                    color: "#B8C4D8"; font.pixelSize: 15
                    wrapMode: Text.WordWrap; width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0A1E3F"
            Column {
                anchors.centerIn: parent
                spacing: 18
                width: parent.width * 0.8
                Text {
                    text: qsTr("Secure by default")
                    color: "#FFFFFF"; font.pixelSize: 24; font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("Firewall enabled, AppArmor, Secure Boot and automatic security updates from Debian keep your system protected without extra work.")
                    color: "#B8C4D8"; font.pixelSize: 15
                    wrapMode: Text.WordWrap; width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0E2E54"
            Column {
                anchors.centerIn: parent
                spacing: 18
                width: parent.width * 0.8
                Text {
                    text: qsTr("Thousands of applications")
                    color: "#FFFFFF"; font.pixelSize: 24; font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("Open Synaptic to install software from the full Debian archive, with tens of thousands of free packages.")
                    color: "#B8C4D8"; font.pixelSize: 15
                    wrapMode: Text.WordWrap; width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#060C26"
            Column {
                anchors.centerIn: parent
                spacing: 18
                width: parent.width * 0.8
                Text {
                    text: qsTr("Light on resources")
                    color: "#FFFFFF"; font.pixelSize: 24; font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("The Xfce desktop, compressed memory (zram) and earlyoom keep PolarisOS fast even on computers with 2 GB of RAM.")
                    color: "#B8C4D8"; font.pixelSize: 15
                    wrapMode: Text.WordWrap; width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
