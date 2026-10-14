import Foundation

final class FixtureLoader {
    static func loadFixtures() -> [(topic: String, payload: String)] {
        let bundle = Bundle.module
        let fixtureFiles = ["system", "battery", "battery_history", "solarcharger", "solarcharger_history", "vebus"]
        
        var messages: [(topic: String, payload: String)] = []

        for filename in fixtureFiles {
            guard let url = bundle.url(forResource: filename, withExtension: "json", subdirectory: "Fixtures") else {
                continue
            }

            guard let data = try? Data(contentsOf: url) else {
                continue
            }

            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let messagesDict = json["messages"] as? [[String: Any]] else {
                continue
            }

            for message in messagesDict {
                guard let topic = message["topic"] as? String,
                      let payload = message["payload"] as? [String: Any] else {
                    continue
                }

                let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [])
                if let payloadData = payloadData, let payloadString = String(data: payloadData, encoding: .utf8) {
                    messages.append((topic: topic, payload: payloadString))
                }
            }
        }

        return messages
    }
}
