//
// DeviceDescription.swift
//
// Parser for UPnP device description XML from Victron GX devices.
//

import Foundation

struct DeviceDescription {
    var friendlyName: String
    var manufacturer: String
    var modelName: String
    var serialNumber: String
    var vrmPortalId: String?
    var mqttOnLan: MqttOnLan?
    var venusVersion: String?
}

class DeviceDescriptionParser: NSObject, XMLParserDelegate {
    /// Victron's namespace for the ve:X_* fields (simple-upnpd.skeleton.xml).
    static let venusNamespace = "urn:schemas-victronenergy-com:venusinfo-1"
    private var deviceDepth = 0   // 1 inside the root <device>; nested devices are ignored
    private var currentElement: String?
    private var currentValue: String?
    private var currentNamespace: String?
    private var parsedDescription: DeviceDescription?

    static func parse(_ data: Data) -> DeviceDescription? {
        let parser = DeviceDescriptionParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.shouldProcessNamespaces = true

        if xmlParser.parse() {
            return parser.parsedDescription
        } else {
            return nil
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "device" { deviceDepth += 1 }
        currentElement = elementName
        currentNamespace = namespaceURI
        currentValue = nil
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue = (currentValue ?? "") + string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "device" { deviceDepth -= 1 }
        guard deviceDepth == 1, let currentElement = currentElement, let currentValue = currentValue, !currentValue.isEmpty else {
            self.currentElement = nil
            self.currentValue = nil
            return
        }

        // Handle Victron-specific elements with ve: namespace
        if currentNamespace == DeviceDescriptionParser.venusNamespace {
            switch currentElement {
            case "X_VrmPortalId":
                parsedDescription?.vrmPortalId = currentValue
            case "X_MqttOnLan":
                if let mqttValue = Int(currentValue) {
                    parsedDescription?.mqttOnLan = MqttOnLan(rawValue: mqttValue)
                }
            case "X_VenusVersion":
                parsedDescription?.venusVersion = currentValue
            default:
                break
            }
        } else {
            // Handle standard UPnP elements
            switch currentElement {
            case "friendlyName":
                parsedDescription?.friendlyName = currentValue
            case "manufacturer":
                parsedDescription?.manufacturer = currentValue
            case "modelName":
                parsedDescription?.modelName = currentValue
            case "serialNumber":
                parsedDescription?.serialNumber = currentValue
            default:
                break
            }
        }

        self.currentElement = nil
        self.currentValue = nil
    }

    func parserDidStartDocument(_ parser: XMLParser) {
        parsedDescription = DeviceDescription(
            friendlyName: "",
            manufacturer: "",
            modelName: "",
            serialNumber: "",
            vrmPortalId: nil,
            mqttOnLan: nil,
            venusVersion: nil
        )
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parsedDescription = nil
    }
}