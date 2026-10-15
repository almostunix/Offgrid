//
// SplitMix64.swift
//
// Deterministic random number generator for fuzz testing.
// Based on SplitMix64 algorithm by Sebastiano Vigna.
//

import Foundation

/// Deterministic random number generator based on SplitMix64 algorithm
public struct SplitMix64 {
    private var state: UInt64

    /// Initialize with a seed value
    /// - Parameter seed: The seed value for the generator
    public init(seed: UInt64) {
        self.state = seed
    }

    /// Generate the next random UInt64
    /// - Returns: A random UInt64 value
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9   // wrapping multiply: SplitMix64 relies on overflow
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Generate a random UInt8
    /// - Returns: A random UInt8 value
    public mutating func nextUInt8() -> UInt8 {
        return UInt8(next() >> 56)
    }

    /// Generate a random Int in the specified range
    /// - Parameters:
    ///   - min: The minimum value (inclusive)
    ///   - max: The maximum value (inclusive)
    /// - Returns: A random Int in the range [min, max]
    public mutating func nextInt(min: Int, max: Int) -> Int {
        let range = UInt64(max - min + 1)
        let random = next() % range
        return Int(min) + Int(random)
    }

    /// Generate a random Bool
    /// - Returns: A random Boolean value
    public mutating func nextBool() -> Bool {
        return next() % 2 == 0
    }

    /// Generate a random string of specified length
    /// - Parameters:
    ///   - length: The length of the string
    ///   - allowEmpty: Whether to allow empty strings
    /// - Returns: A random string
    public mutating func randomString(length: Int, allowEmpty: Bool = true) -> String {
        let actualLength: Int
        if allowEmpty && nextBool() {
            actualLength = 0
        } else {
            actualLength = nextInt(min: 0, max: length)
        }

        var result = ""
        for _ in 0..<actualLength {
            let value = nextUInt8()
            // Only use printable ASCII characters
            let char: Character
            if value < 32 || value > 126 {
                // Map non-printable characters to printable range
                char = Character(UnicodeScalar(32 + (value % 95)))
            } else {
                char = Character(UnicodeScalar(value))
            }
            result.append(char)
        }
        return result
    }

    /// Generate a random topic string for fuzzing
    /// - Returns: A random topic string that may be valid or malformed
    public mutating func randomTopic() -> String {
        let shouldStartWithN = nextBool()
        let shouldHaveWildcards = nextBool()
        let shouldHaveEmptySegments = nextBool()

        var parts: [String] = []

        // First part: should be "N" or something else
        if shouldStartWithN {
            parts.append("N")
        } else {
            parts.append(randomString(length: 5, allowEmpty: true))
        }

        // Second part: portal ID (may be empty)
        if shouldHaveEmptySegments && nextBool() {
            parts.append("")
        } else {
            parts.append(randomString(length: 20, allowEmpty: false))
        }

        // Third part: service (may be empty)
        if shouldHaveEmptySegments && nextBool() {
            parts.append("")
        } else {
            parts.append(randomString(length: 20, allowEmpty: false))
        }

        // Fourth part: instance (may be empty)
        if parts.count >= 3 && nextBool() {
            if shouldHaveEmptySegments && nextBool() {
                parts.append("")
            } else {
                parts.append(randomString(length: 10, allowEmpty: false))
            }
        }

        // Additional path parts
        let pathCount = nextInt(min: 0, max: 10)
        for _ in 0..<pathCount {
            if shouldHaveEmptySegments && nextBool() {
                parts.append("")
            } else {
                parts.append(randomString(length: 20, allowEmpty: false))
            }
        }

        // Add wildcards if enabled
        if shouldHaveWildcards {
            let wildcardPos = nextInt(min: 0, max: parts.count)
            if wildcardPos < parts.count {
                if nextBool() {
                    parts[wildcardPos] = "+"
                } else {
                    parts[wildcardPos] = "#"
                }
            }
        }

        return parts.joined(separator: "/")
    }

    /// Generate a random JSON payload that may be valid or malformed
    /// - Returns: A random JSON payload as Data
    public mutating func randomJSONPayload() -> Data {
        let shouldBeValid = nextBool()
        let shouldHaveValueKey = shouldBeValid && nextBool()

        var dict = [String: Any]()

        // Add "value" key with various types
        if shouldHaveValueKey {
            let valueType = nextInt(min: 0, max: 4)
            switch valueType {
            case 0:
                // Number
                let num = Double(next()) / Double(UInt64.max)
                dict["value"] = num
            case 1:
                // String
                dict["value"] = randomString(length: 50, allowEmpty: true)
            case 2:
                // Null
                dict["value"] = NSNull()
            case 3:
                // Array
                let arrayCount = nextInt(min: 0, max: 10)
                var array = [Any]()
                for _ in 0..<arrayCount {
                    let elemType = nextInt(min: 0, max: 3)
                    switch elemType {
                    case 0:
                        array.append(Double(next()) / Double(UInt64.max))
                    case 1:
                        array.append(randomString(length: 20, allowEmpty: true))
                    case 2:
                        array.append(NSNull())
                    case 3:
                        // Nested array
                        let nestedCount = nextInt(min: 0, max: 5)
                        var nested = [Any]()
                        for _ in 0..<nestedCount {
                            nested.append(Double(next()) / Double(UInt64.max))
                        }
                        array.append(nested)
                    default:
                        break
                    }
                }
                dict["value"] = array
            default:
                break
            }
        }

        // Add random other keys
        let otherKeysCount = nextInt(min: 0, max: 5)
        for i in 0..<otherKeysCount {
            let key = "key" + String(i)
            let valueType = nextInt(min: 0, max: 3)
            switch valueType {
            case 0:
                dict[key] = randomString(length: 20, allowEmpty: true)
            case 1:
                dict[key] = Double(next()) / Double(UInt64.max)
            case 2:
                dict[key] = NSNull()
            case 3:
                dict[key] = [randomString(length: 10, allowEmpty: true): randomString(length: 10, allowEmpty: true)]
            default:
                break
            }
        }

        // For invalid JSON, add malformed structures
        if !shouldBeValid {
            let malformationType = nextInt(min: 0, max: 3)
            switch malformationType {
            case 0:
                // Add a dictionary as a value (valid JSON but not supported by our parser)
                dict["value"] = ["nested": "dict"]
            case 1:
                // Add invalid JSON string
                dict["value"] = "not a valid JSON value"
            case 2:
                // Add boolean (not supported by our parser)
                dict["value"] = nextBool()
            case 3:
                // Add mixed array with unsupported types
                dict["value"] = [1, "test", NSNull(), [2, 3]]
            default:
                break
            }
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            return jsonData
        } catch {
            // If serialization fails, return empty data
            return Data()
        }
    }

    /// Generate a truncated version of the given data
    /// - Parameter data: The original data
    /// - Returns: A truncated version of the data
    public mutating func truncatedData(from data: Data) -> Data {
        guard !data.isEmpty else { return data }

        let truncateAt = nextInt(min: 0, max: data.count)
        return data.prefix(truncateAt)
    }

    /// Generate a corrupted version of the given data
    /// - Parameter data: The original data
    /// - Returns: A corrupted version of the data
    public mutating func corruptedData(from data: Data) -> Data {
        guard !data.isEmpty else { return data }

        var corrupted = data
        let corruptPos = nextInt(min: 0, max: corrupted.count - 1)
        let originalByte = corrupted[corruptPos]
        var newByte = originalByte

        // Flip some bits
        let bitPos = nextInt(min: 0, max: 7)
        newByte ^= (1 << bitPos)

        corrupted[corruptPos] = newByte
        return corrupted
    }
}
