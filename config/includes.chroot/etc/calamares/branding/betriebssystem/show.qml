import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            Image {
                anchors.centerIn: parent
                source: "logo.png"
                fillMode: Image.PreserveAspectFit
                width: parent.width * 0.25
            }
        }
    }

    function onActivate() {}
    function onLeave() {}
}
