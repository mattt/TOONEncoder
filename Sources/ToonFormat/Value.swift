import Foundation

/// An intermediate representation for TOON values during encoding and decoding.
enum Value: Equatable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case date(Date)
    case url(URL)
    case data(Data)
    case array([Value])
    case object([String: Value], keyOrder: [String])

    // MARK: - Type Checks

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var isPrimitive: Bool {
        switch self {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            return true
        case .array, .object:
            return false
        }
    }

    var isArray: Bool {
        if case .array = self { return true }
        return false
    }

    var isObject: Bool {
        if case .object = self { return true }
        return false
    }

    // MARK: - Value Accessors

    var boolValue: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }

    var intValue: Int64? {
        if case let .int(v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case let .double(v) = self { return v }
        // Also allow int to double conversion
        if case let .int(v) = self { return Double(v) }
        return nil
    }

    var stringValue: String? {
        if case let .string(v) = self { return v }
        return nil
    }

    var arrayValue: [Value]? {
        if case let .array(v) = self { return v }
        return nil
    }

    var objectValue: (values: [String: Value], keyOrder: [String])? {
        if case let .object(values, keyOrder) = self { return (values, keyOrder) }
        return nil
    }

    var typeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "bool"
        case .int: return "int"
        case .double: return "double"
        case .string: return "string"
        case .date: return "date"
        case .url: return "url"
        case .data: return "data"
        case .array: return "array"
        case .object: return "object"
        }
    }

    // MARK: - Array Type Checks

    var isArrayOfPrimitives: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isPrimitive }
    }

    var isArrayOfArrays: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isArray }
    }

    var isArrayOfObjects: Bool {
        guard let array = arrayValue else { return false }
        return array.allSatisfy { $0.isObject }
    }

    // MARK: - Factory

    /// Creates a `Value` from an arbitrary value.
    static func from(_ value: Any) -> Value {
        if value is NSNull {
            return .null
        }

        if let boolValue = value as? Bool {
            return .bool(boolValue)
        }

        if let intValue = value as? Int {
            return .int(Int64(intValue))
        }
        if let int8Value = value as? Int8 {
            return .int(Int64(int8Value))
        }
        if let int16Value = value as? Int16 {
            return .int(Int64(int16Value))
        }
        if let int32Value = value as? Int32 {
            return .int(Int64(int32Value))
        }
        if let int64Value = value as? Int64 {
            return .int(int64Value)
        }

        if let uintValue = value as? UInt {
            return .int(Int64(uintValue))
        }
        if let uint8Value = value as? UInt8 {
            return .int(Int64(uint8Value))
        }
        if let uint16Value = value as? UInt16 {
            return .int(Int64(uint16Value))
        }
        if let uint32Value = value as? UInt32 {
            return .int(Int64(uint32Value))
        }
        if let uint64Value = value as? UInt64 {
            if uint64Value <= Int64.max {
                return .int(Int64(uint64Value))
            } else {
                return .string(String(uint64Value))
            }
        }

        if let floatValue = value as? Float {
            return floatValue.isFinite ? .double(Double(floatValue)) : .null
        }
        if let doubleValue = value as? Double {
            return doubleValue.isFinite ? .double(doubleValue) : .null
        }

        if let stringValue = value as? String {
            return .string(stringValue)
        }

        if let dateValue = value as? Date {
            return .date(dateValue)
        }

        if let urlValue = value as? URL {
            return .url(urlValue)
        }

        if let dataValue = value as? Data {
            return .data(dataValue)
        }

        if let arrayValue = value as? [Any] {
            return .array(arrayValue.map(Value.from))
        }

        if let dictionaryValue = value as? [String: Any] {
            var object: [String: Value] = [:]
            var keyOrder: [String] = []
            for (key, value) in dictionaryValue {
                if !keyOrder.contains(key) {
                    keyOrder.append(key)
                }
                object[key] = Value.from(value)
            }
            return .object(object, keyOrder: keyOrder)
        }

        return .null
    }
}

// MARK: - Coding Key

struct IndexedCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
