import Foundation

/// An encoder that converts Swift values to TOON format
///
/// This encoder conforms to the TOON (Token-Oriented Object Notation) specification version 3.0.
/// For more information, see: https://github.com/toon-format/spec
public final class TOONEncoder {

    /// The TOON specification version this encoder conforms to
    public static let specVersion = "3.0"

    /// Number of spaces per indentation level
    public var indent: Int = 2

    /// Delimiter to use for array values and tabular rows
    public var delimiter: Delimiter = .comma

    /// Optional marker to prefix array lengths in headers
    public var lengthMarker: LengthMarker = .none

    /// Key folding mode for collapsing single-key object chains into dotted paths
    ///
    /// When enabled, single-key nested objects like `{ a: { b: { c: 1 } } }`
    /// are collapsed into `a.b.c: 1`. Only applies when all segments are valid identifiers.
    ///
    /// Example with `.safe`:
    /// ```toon
    /// user.profile.name: John
    /// user.profile.age: 30
    /// ```
    public var keyFolding: KeyFolding = .disabled

    /// Maximum number of segments to include in a folded path when `keyFolding` is `.safe`.
    ///
    /// Controls how many nested single-key objects are collapsed into a dotted path.
    /// - Default is `Int.max` (unlimited folding depth)
    /// - Values less than 2 have no practical folding effect
    ///
    /// Example with `flattenDepth = 2`:
    /// - Input: `{ a: { b: { c: { d: 1 } } } }`
    /// - Output: `a.b:` followed by nested `c:` and `d: 1`
    ///
    /// Example with `flattenDepth = Int.max` (default):
    /// - Input: `{ a: { b: { c: 1 } } }`
    /// - Output: `a.b.c: 1`
    public var flattenDepth: Int = .max

    /// Key folding mode
    public enum KeyFolding: Hashable, Sendable {
        /// No key folding
        case disabled

        /// Safe key folding: only fold when all segments are valid identifiers
        case safe
    }

    /// Delimiter character used to separate array values and tabular row cells
    ///
    /// The delimiter determines how multiple values are separated in inline arrays
    /// and tabular data rows.
    ///
    /// Example with `.comma`:
    /// ```toon
    /// tags[3]: reading,gaming,coding
    /// ```
    ///
    /// Example with `.tab`:
    /// ```toon
    /// items[2	]{sku	name}:
    ///   A1	Widget
    ///   B2	Gadget
    /// ```
    ///
    /// Example with `.pipe`:
    /// ```toon
    /// items[2|]{sku|name}:
    ///   A1|Widget
    ///   B2|Gadget
    /// ```
    public enum Delimiter: String, CaseIterable, Hashable, Sendable {
        /// Comma separator: `,`
        case comma = ","

        /// Tab separator: `\t`
        case tab = "\t"

        /// Pipe separator: `|`
        case pipe = "|"
    }

    /// Marker character to prefix array lengths in headers
    ///
    /// Length markers appear before array counts in brackets to provide
    /// additional clarity about array sizing.
    ///
    /// Example with `.none`:
    /// ```toon
    /// tags[3]: reading,gaming,coding
    /// ```
    ///
    /// Example with `.hash`:
    /// ```toon
    /// tags[#3]: reading,gaming,coding
    /// ```
    public enum LengthMarker: CaseIterable, Hashable, Sendable {
        /// No length marker
        case none

        /// Hash symbol prefix: `#`
        case hash
    }

    /// Creates a new TOON encoder with default configuration
    ///
    /// Default settings:
    /// - `indent`: 2 spaces
    /// - `delimiter`: `.comma`
    /// - `lengthMarker`: `.none`
    /// - `keyFolding`: `.disabled`
    /// - `flattenDepth`: `Int.max`
    public init() {}

    /// Encodes the given value to TOON format
    ///
    /// - Parameter value: An `Encodable` value to convert to TOON format
    /// - Returns: UTF-8 encoded data containing the TOON representation
    /// - Throws: An error if encoding fails
    ///
    /// This method handles special Foundation types (`Date`, `URL`, `Data`) as well as
    /// standard Swift types and custom `Encodable` types. Arrays of objects with consistent
    /// keys are automatically formatted as tabular data.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        // Handle special types before they encode themselves
        let mirror = Mirror(reflecting: value)
        let v: Value

        if mirror.subjectType == Date.self, let date = value as? Date {
            v = .date(date)
        } else if mirror.subjectType == URL.self, let url = value as? URL {
            v = .url(url)
        } else if mirror.subjectType == Data.self, let data = value as? Data {
            v = .data(data)
        } else {
            let encoder = Encoder(userInfo: [:])
            try value.encode(to: encoder)
            v = encoder.encodedValue
        }

        var output: [String] = []
        encodeValue(v, output: &output, depth: 0)

        let result = output.joined(separator: "\n")
        return result.data(using: .utf8) ?? Data()
    }

    // MARK: - Encoding Entry Point

    private func encodeValue(_ value: Value, output: inout [String], depth: Int) {
        switch value {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            // Special case for root-level primitives
            if depth == 0 {
                if let encoded = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: false) {
                    write(depth: depth, content: encoded, to: &output)
                }
            }

        case .array(let array):
            encodeArray(key: nil, array: array, output: &output, depth: depth)

        case .object(let values, let keyOrder):
            encodeObject(values, keyOrder: keyOrder, output: &output, depth: depth)
        }
    }

    // MARK: - Object Encoding

    private func encodeObject(
        _ values: [String: Value],
        keyOrder: [String],
        output: inout [String],
        depth: Int,
        allowFolding: Bool = true
    ) {
        for key in keyOrder {
            guard let value = values[key] else { continue }
            encodeKeyValuePair(
                key: key,
                value: value,
                output: &output,
                depth: depth,
                siblingKeys: keyOrder,
                allowFolding: allowFolding
            )
        }
    }

    /// Attempts to fold a key path by following single-key object chains
    /// Returns the folded path, final value, and whether we hit the depth limit, or nil if folding is not safe
    /// - Parameters:
    ///   - key: The starting key of the chain
    ///   - value: The value associated with the key
    ///   - siblingKeys: Other keys at the same object depth (for collision avoidance)
    private func tryFoldKeyPath(
        key: String,
        value: Value,
        siblingKeys: [String] = []
    ) -> (path: String, value: Value, hitDepthLimit: Bool)? {
        guard keyFolding == .safe else { return nil }

        // Values less than 2 have no practical folding effect
        guard flattenDepth >= 2 else { return nil }

        var pathComponents: [String] = [key]
        var currentValue = value
        var hitDepthLimit = false

        // Follow the chain of single-key objects, respecting flattenDepth limit
        while case .object(let nestedValues, let nestedKeyOrder) = currentValue,
            nestedKeyOrder.count == 1,
            let singleKey = nestedKeyOrder.first,
            let nextValue = nestedValues[singleKey]
        {
            // Stop if we've reached the flattenDepth limit
            guard pathComponents.count < flattenDepth else {
                hitDepthLimit = true
                break
            }

            // Validate that the key is a safe identifier
            guard singleKey.isValidIdentifierSegment else {
                break
            }

            pathComponents.append(singleKey)
            currentValue = nextValue
        }

        // Only fold if we found at least one nested level
        guard pathComponents.count > 1 else { return nil }

        // Validate all components are safe identifiers
        guard pathComponents.allSatisfy({ $0.isValidIdentifierSegment }) else {
            return nil
        }

        let foldedPath = pathComponents.joined(separator: ".")

        // Collision avoidance: folded key must not equal any existing sibling key
        if siblingKeys.contains(foldedPath) {
            return nil
        }

        return (path: foldedPath, value: currentValue, hitDepthLimit: hitDepthLimit)
    }

    private func encodeKeyValuePair(
        key: String,
        value: Value,
        output: inout [String],
        depth: Int,
        siblingKeys: [String] = [],
        allowFolding: Bool = true
    ) {
        // Try key folding if enabled and allowed
        if allowFolding,
            case let (path, value, hitDepthLimit)? = tryFoldKeyPath(key: key, value: value, siblingKeys: siblingKeys)
        {
            let encodedKey = encodeKey(path)

            switch value {
            case .null, .bool, .int, .double, .string, .date, .url, .data:
                if let encodedValue = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: true) {
                    write(depth: depth, content: "\(encodedKey): \(encodedValue)", to: &output)
                }

            case .array(let array):
                encodeArray(key: path, array: array, output: &output, depth: depth)

            case .object(let values, let keyOrder):
                if keyOrder.isEmpty {
                    write(depth: depth, content: "\(encodedKey):", to: &output)
                } else {
                    write(depth: depth, content: "\(encodedKey):", to: &output)
                    encodeObject(
                        values,
                        keyOrder: keyOrder,
                        output: &output,
                        depth: depth + 1,
                        allowFolding: !hitDepthLimit
                    )
                }
            }
            return
        }

        // Regular encoding without folding
        let encodedKey = encodeKey(key)

        switch value {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            if let encodedValue = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: true) {
                write(depth: depth, content: "\(encodedKey): \(encodedValue)", to: &output)
            }

        case .array(let array):
            encodeArray(key: key, array: array, output: &output, depth: depth)

        case .object(let values, let keyOrder):
            if keyOrder.isEmpty {
                write(depth: depth, content: "\(encodedKey):", to: &output)
            } else {
                write(depth: depth, content: "\(encodedKey):", to: &output)
                encodeObject(values, keyOrder: keyOrder, output: &output, depth: depth + 1)
            }
        }
    }

    private func encodeObjectAsListItem(
        values: [String: Value],
        keyOrder: [String],
        output: inout [String],
        depth: Int
    ) {
        if keyOrder.isEmpty {
            write(depth: depth, content: "-", to: &output)
            return
        }

        // First key-value on the same line as "- "
        let firstKey = keyOrder[0]
        let encodedKey = encodeKey(firstKey)
        let firstValue = values[firstKey]!

        switch firstValue {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            if let encodedValue = encodePrimitive(
                firstValue,
                delimiter: delimiter.rawValue,
                inObject: true
            ) {
                write(
                    depth: depth,
                    content: "- \(encodedKey): \(encodedValue)",
                    to: &output
                )
            }

        case .array(let array):
            if array.allSatisfy({ $0.isPrimitive }) {
                let formatted = formatInlineArray(values: array, key: firstKey)
                write(depth: depth, content: "- \(formatted)", to: &output)
            } else if array.allSatisfy({ $0.isObject }) {
                if let header = detectTabularHeader(array) {
                    let headerStr = formatHeader(
                        length: array.count,
                        key: firstKey,
                        fields: header,
                        delimiter: delimiter.rawValue,
                        lengthMarker: lengthMarker == .hash ? "#" : nil
                    )
                    write(
                        depth: depth,
                        content: "- \(headerStr)",
                        to: &output
                    )
                    writeTabularRows(rows: array, header: header, output: &output, depth: depth + 1)
                } else {
                    write(
                        depth: depth,
                        content: "- \(encodedKey)[\(array.count)]:",
                        to: &output
                    )
                    for item in array {
                        if let (values, keyOrder) = item.objectValue {
                            encodeObjectAsListItem(
                                values: values,
                                keyOrder: keyOrder,
                                output: &output,
                                depth: depth + 1
                            )
                        }
                    }
                }
            } else {
                write(
                    depth: depth,
                    content: "- \(encodedKey)[\(array.count)]:",
                    to: &output
                )
                for item in array {
                    switch item {
                    case .null, .bool, .int, .double, .string, .date, .url, .data:
                        if let encoded = encodePrimitive(
                            item,
                            delimiter: delimiter.rawValue,
                            inObject: false
                        ) {
                            write(
                                depth: depth + 1,
                                content: "- \(encoded)",
                                to: &output
                            )
                        }
                    case .array(let innerArray):
                        if innerArray.allSatisfy({ $0.isPrimitive }) {
                            let inline = formatInlineArray(values: innerArray, key: nil)
                            write(
                                depth: depth + 1,
                                content: "- \(inline)",
                                to: &output
                            )
                        }
                    case .object(let innerValues, let innerKeyOrder):
                        encodeObjectAsListItem(
                            values: innerValues,
                            keyOrder: innerKeyOrder,
                            output: &output,
                            depth: depth + 1
                        )
                    }
                }
            }

        case .object(let nestedValues, let nestedKeyOrder):
            if nestedKeyOrder.isEmpty {
                write(depth: depth, content: "- \(encodedKey):", to: &output)
            } else {
                write(depth: depth, content: "- \(encodedKey):", to: &output)
                encodeObject(nestedValues, keyOrder: nestedKeyOrder, output: &output, depth: depth + 2)
            }
        }

        // Remaining keys on indented lines
        for i in 1 ..< keyOrder.count {
            let key = keyOrder[i]
            guard let value = values[key] else { continue }
            encodeKeyValuePair(key: key, value: value, output: &output, depth: depth + 1, siblingKeys: keyOrder)
        }
    }

    // MARK: - Array Encoding

    private func encodeArray(key: String?, array: [Value], output: inout [String], depth: Int) {
        if array.isEmpty {
            let header = formatHeader(
                length: 0,
                key: key,
                delimiter: delimiter.rawValue,
                lengthMarker: lengthMarker == .hash ? "#" : nil
            )
            write(depth: depth, content: header, to: &output)
            return
        }

        // Primitive array
        if array.allSatisfy({ $0.isPrimitive }) {
            encodeInlinePrimitiveArray(key: key, values: array, output: &output, depth: depth)
            return
        }

        // Array of arrays (all primitives)
        if array.allSatisfy({ $0.isArray }) {
            let allPrimitiveArrays = array.allSatisfy { arrayValue in
                guard let innerArray = arrayValue.arrayValue else { return false }
                return innerArray.allSatisfy { $0.isPrimitive }
            }
            if allPrimitiveArrays {
                encodeArrayOfArraysAsListItems(
                    key: key,
                    values: array,
                    output: &output,
                    depth: depth
                )
                return
            }
        }

        // Array of objects
        if array.allSatisfy({ $0.isObject }) {
            if let header = detectTabularHeader(array) {
                encodeArrayOfObjectsAsTabular(
                    key: key,
                    rows: array,
                    header: header,
                    output: &output,
                    depth: depth
                )
            } else {
                encodeMixedArrayAsListItems(key: key, items: array, output: &output, depth: depth)
            }
            return
        }

        // Mixed array: fallback to expanded format
        encodeMixedArrayAsListItems(key: key, items: array, output: &output, depth: depth)
    }

    private func encodeInlinePrimitiveArray(
        key: String?,
        values: [Value],
        output: inout [String],
        depth: Int
    ) {
        let formatted = formatInlineArray(values: values, key: key)
        write(depth: depth, content: formatted, to: &output)
    }

    private func encodeArrayOfArraysAsListItems(
        key: String?,
        values: [Value],
        output: inout [String],
        depth: Int
    ) {
        let header = formatHeader(
            length: values.count,
            key: key,
            delimiter: delimiter.rawValue,
            lengthMarker: lengthMarker == .hash ? "#" : nil
        )
        write(depth: depth, content: header, to: &output)

        for arrayValue in values {
            guard let innerArray = arrayValue.arrayValue else { continue }
            let inline = formatInlineArray(values: innerArray, key: nil)
            write(depth: depth + 1, content: "- \(inline)", to: &output)
        }
    }

    private func encodeArrayOfObjectsAsTabular(
        key: String?,
        rows: [Value],
        header: [String],
        output: inout [String],
        depth: Int
    ) {
        let headerStr = formatHeader(
            length: rows.count,
            key: key,
            fields: header,
            delimiter: delimiter.rawValue,
            lengthMarker: lengthMarker == .hash ? "#" : nil
        )
        write(depth: depth, content: headerStr, to: &output)

        writeTabularRows(rows: rows, header: header, output: &output, depth: depth + 1)
    }

    private func encodeMixedArrayAsListItems(
        key: String?,
        items: [Value],
        output: inout [String],
        depth: Int
    ) {
        let header = formatHeader(
            length: items.count,
            key: key,
            delimiter: delimiter.rawValue,
            lengthMarker: lengthMarker == .hash ? "#" : nil
        )
        write(depth: depth, content: header, to: &output)

        for item in items {
            switch item {
            case .null, .bool, .int, .double, .string, .date, .url, .data:
                if let encoded = encodePrimitive(item, delimiter: delimiter.rawValue, inObject: false) {
                    write(depth: depth + 1, content: "- \(encoded)", to: &output)
                }

            case .array(let array):
                if array.allSatisfy({ $0.isPrimitive }) {
                    let inline = formatInlineArray(values: array, key: nil)
                    write(
                        depth: depth + 1,
                        content: "- \(inline)",
                        to: &output
                    )
                }

            case .object(let values, let keyOrder):
                encodeObjectAsListItem(
                    values: values,
                    keyOrder: keyOrder,
                    output: &output,
                    depth: depth + 1
                )
            }
        }
    }

    // MARK: - Tabular Encoding

    private func detectTabularHeader(_ rows: [Value]) -> [String]? {
        guard let (_, keyOrder) = rows.first?.objectValue else { return nil }
        if keyOrder.isEmpty { return nil }

        if isTabularArray(rows: rows, header: keyOrder) {
            return keyOrder
        }
        return nil
    }

    private func isTabularArray(rows: [Value], header: [String]) -> Bool {
        for rowValue in rows {
            guard let (values, keyOrder) = rowValue.objectValue else { return false }

            // All objects must have the same keys (but order can differ)
            if keyOrder.count != header.count {
                return false
            }

            // Check that all header keys exist in the row and all values are primitives
            for key in header {
                guard let value = values[key] else { return false }
                if !value.isPrimitive {
                    return false
                }
            }
        }

        return true
    }

    private func writeTabularRows(rows: [Value], header: [String], output: inout [String], depth: Int) {
        for rowValue in rows {
            guard let (values, _) = rowValue.objectValue else { continue }
            let rowValues = header.compactMap { key in values[key] }
            let joinedValue = joinEncodedValues(
                rowValues,
                delimiter: delimiter.rawValue
            )
            write(depth: depth, content: joinedValue, to: &output)
        }
    }

    // MARK: - Primitive Encoding

    private func encodePrimitive(_ value: Value, delimiter: String = ",", inObject: Bool = false)
        -> String?
    {
        switch value {
        case .null:
            return "null"
        case .bool(let boolValue):
            return String(boolValue)
        case .int(let intValue):
            return String(intValue)
        case .double(let doubleValue):
            // Check for non-finite numbers first
            if !doubleValue.isFinite {
                return "null"
            }

            // Format numbers in decimal form without scientific notation
            if doubleValue == 0.0 && doubleValue.sign == .minus {
                return "0"  // Convert -0 to 0
            }

            if let formatted = numberFormatter.string(from: NSNumber(value: doubleValue)) {
                return formatted
            }

            // Fallback to string representation
            return String(doubleValue)
        case .string(let stringValue):
            return encodeStringLiteral(stringValue, delimiter: delimiter)
        case .date(let date):
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = iso8601.string(from: date)
            return encodeStringLiteral(dateString, delimiter: delimiter)
        case .url(let url):
            return encodeStringLiteral(url.absoluteString, delimiter: delimiter)
        case .data(let data):
            let base64 = data.base64EncodedString()
            return encodeStringLiteral(base64, delimiter: delimiter)
        case .array, .object:
            return nil
        }
    }

    private func encodeStringLiteral(_ value: String, delimiter: String = ",")
        -> String
    {
        if value.isSafeUnquoted(delimiter: delimiter) {
            return value
        }

        return "\"\(value.escaped)\""
    }

    private func encodeKey(_ key: String) -> String {
        if key.isValidUnquotedKey {
            return key
        }

        return "\"\(key.escaped)\""
    }

    // MARK: - Formatting Helpers

    private func formatInlineArray(values: [Value], key: String?) -> String {
        let header = formatHeader(
            length: values.count,
            key: key,
            delimiter: delimiter.rawValue,
            lengthMarker: lengthMarker == .hash ? "#" : nil
        )
        let joinedValue = joinEncodedValues(values, delimiter: delimiter.rawValue)

        if values.isEmpty {
            return header
        }
        return "\(header) \(joinedValue)"
    }

    private func formatHeader(
        length: Int,
        key: String? = nil,
        fields: [String]? = nil,
        delimiter: String = ",",
        lengthMarker: String? = nil
    ) -> String {
        var header = ""

        if let key = key {
            header += encodeKey(key)
        }

        // Only include delimiter if it's not the default (comma)
        let delimiterSuffix = delimiter != "," ? delimiter : ""
        header += "[\(lengthMarker ?? "")\(length)\(delimiterSuffix)]"

        if let fields = fields {
            let quotedFields = fields.map { encodeKey($0) }
            header += "{\(quotedFields.joined(separator: delimiter))}"
        }

        header += ":"

        return header
    }

    private func joinEncodedValues(_ values: [Value], delimiter: String = ",")
        -> String
    {
        return values.compactMap { encodePrimitive($0, delimiter: delimiter) }.joined(separator: delimiter)
    }

    private func write(depth: Int, content: String, to output: inout [String]) {
        let indentation = String(repeating: String(repeating: " ", count: indent), count: depth)
        output.append(indentation + content)
    }
}

// MARK: -

extension TOONEncoder {
    /// Internal encoder implementation that conforms to the Encoder protocol
    private final class Encoder: Swift.Encoder {
        let codingPath: [any Swift.CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        fileprivate var storage: [Value]

        init(codingPath: [any Swift.CodingKey] = [], userInfo: [CodingUserInfoKey: Any] = [:]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.storage = []
        }

        func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
        where Key: Swift.CodingKey {
            let container = KeyedContainer<Key>(encoder: self, codingPath: codingPath)
            return KeyedEncodingContainer(container)
        }

        func unkeyedContainer() -> UnkeyedEncodingContainer {
            return UnkeyedContainer(encoder: self, codingPath: codingPath)
        }

        func singleValueContainer() -> SingleValueEncodingContainer {
            return SingleValueContainer(encoder: self, codingPath: codingPath)
        }

        var canEncodeNewValue: Bool {
            return storage.count == 0
        }

        func encode<T: Encodable>(_ value: T) throws {
            try value.encode(to: self)
        }

        var encodedValue: Value {
            if storage.count == 0 {
                // If no values in storage, return null as a fallback
                return .null
            }
            return storage.removeLast()
        }
    }
}

// MARK: - Keyed Encoding Container

extension TOONEncoder {
    private final class KeyedContainer<Key: Swift.CodingKey>: KeyedEncodingContainerProtocol {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        private var container: [String: Value] = [:]
        private var keyOrder: [String] = []  // Track insertion order

        init(encoder: Encoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        private func trackKey(_ key: String) {
            if !keyOrder.contains(key) {
                keyOrder.append(key)
            }
        }

        func encodeNil(forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .null
        }

        func encode(_ value: Bool, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .bool(value)
        }

        func encode(_ value: String, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .string(value)
        }

        func encode(_ value: Double, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .double(value)
        }

        func encode(_ value: Float, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .double(Double(value))
        }

        func encode(_ value: Int, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int8, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int16, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int32, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int64, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(value)
        }

        func encode(_ value: UInt, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt8, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt16, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt32, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt64, forKey key: Key) throws {
            trackKey(key.stringValue)
            if value <= Int64.max {
                container[key.stringValue] = .int(Int64(value))
            } else {
                container[key.stringValue] = .string(String(value))
            }
        }

        func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
            trackKey(key.stringValue)

            // Handle special types by checking the mirror of the value
            // We need to use the Mirror because Date, URL, and Data conform to Codable
            // and would otherwise encode themselves using their default implementations

            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                container[key.stringValue] = .date(date)
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                container[key.stringValue] = .url(url)
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                container[key.stringValue] = .data(data)
                return
            }

            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            try value.encode(to: nestedEncoder)
            container[key.stringValue] = nestedEncoder.encodedValue
        }

        func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: String?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
            -> KeyedEncodingContainer<NestedKey> where NestedKey: Swift.CodingKey
        {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            let container = KeyedContainer<NestedKey>(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
            return KeyedEncodingContainer(container)
        }

        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            return UnkeyedContainer(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
        }

        func superEncoder() -> Swift.Encoder {
            return encoder
        }

        func superEncoder(forKey key: Key) -> Swift.Encoder {
            return encoder
        }

        func finishEncoding() {
            encoder.storage.append(.object(container, keyOrder: keyOrder))
        }

        deinit {
            // Ensure the container is finished when it goes out of scope
            encoder.storage.append(.object(container, keyOrder: keyOrder))
        }
    }
}

// MARK: - Unkeyed Encoding Container

extension TOONEncoder {
    private final class UnkeyedContainer: UnkeyedEncodingContainer {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        private var container: [Value] = []

        init(encoder: Encoder, codingPath: [any Swift.CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        var count: Int {
            return container.count
        }

        func encodeNil() throws {
            container.append(.null)
        }

        func encode(_ value: Bool) throws {
            container.append(.bool(value))
        }

        func encode(_ value: String) throws {
            container.append(.string(value))
        }

        func encode(_ value: Double) throws {
            container.append(.double(value))
        }

        func encode(_ value: Float) throws {
            container.append(.double(Double(value)))
        }

        func encode(_ value: Int) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int8) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int16) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int32) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int64) throws {
            container.append(.int(value))
        }

        func encode(_ value: UInt) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt8) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt16) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt32) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt64) throws {
            if value <= Int64.max {
                container.append(.int(Int64(value)))
            } else {
                container.append(.string(String(value)))
            }
        }

        func encode<T: Encodable>(_ value: T) throws {
            // Handle special types
            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                container.append(.date(date))
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                container.append(.url(url))
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                container.append(.data(data))
                return
            }

            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            try value.encode(to: nestedEncoder)
            container.append(nestedEncoder.encodedValue)
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<
            NestedKey
        > where NestedKey: Swift.CodingKey {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            let container = KeyedContainer<NestedKey>(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
            return KeyedEncodingContainer(container)
        }

        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            return UnkeyedContainer(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
        }

        func superEncoder() -> Swift.Encoder {
            return encoder
        }

        func finishEncoding() {
            encoder.storage.append(.array(container))
        }

        deinit {
            // Ensure the container is finished when it goes out of scope
            encoder.storage.append(.array(container))
        }
    }
}

// MARK: - Single Value Encoding Container

extension TOONEncoder {
    private final class SingleValueContainer: SingleValueEncodingContainer {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        init(encoder: Encoder, codingPath: [any Swift.CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        func encodeNil() throws {
            encoder.storage.append(.null)
        }

        func encode(_ value: Bool) throws {
            encoder.storage.append(.bool(value))
        }

        func encode(_ value: String) throws {
            encoder.storage.append(.string(value))
        }

        func encode(_ value: Double) throws {
            encoder.storage.append(.double(value))
        }

        func encode(_ value: Float) throws {
            encoder.storage.append(.double(Double(value)))
        }

        func encode(_ value: Int) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int8) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int16) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int32) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int64) throws {
            encoder.storage.append(.int(value))
        }

        func encode(_ value: UInt) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt8) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt16) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt32) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt64) throws {
            if value <= Int64.max {
                encoder.storage.append(.int(Int64(value)))
            } else {
                encoder.storage.append(.string(String(value)))
            }
        }

        func encode<T: Encodable>(_ value: T) throws {
            // Handle special types
            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                encoder.storage.append(.date(date))
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                encoder.storage.append(.url(url))
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                encoder.storage.append(.data(data))
                return
            }

            let nestedEncoder = Encoder(codingPath: codingPath, userInfo: encoder.userInfo)
            try value.encode(to: nestedEncoder)
            encoder.storage.append(nestedEncoder.encodedValue)
        }

        deinit {
            // Single value containers don't need finishEncoding, they push values directly
        }
    }
}

/// Intermediate representation for TOON values during encoding
private enum Value: Equatable {
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

    /// Creates a value from any Encodable value
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

    var isObject: Bool {
        if case .object = self { return true }
        return false
    }

    var arrayValue: [Value]? {
        if case .array(let values) = self { return values }
        return nil
    }

    var objectValue: (values: [String: Value], keyOrder: [String])? {
        if case .object(let values, let keyOrder) = self { return (values, keyOrder) }
        return nil
    }

    var stringValue: String? {
        if case .string(let str) = self { return str }
        return nil
    }

    var intValue: Int64? {
        if case .int(let val) = self { return val }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let val) = self { return val }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let val) = self { return val }
        return nil
    }
}

// MARK: -

private struct IndexedCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// Shared number formatter that's used to avoid scientific notation
// and format numbers in canonical decimal form (no trailing zeros)
private let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 15
    formatter.minimumFractionDigits = 0  // Prevents trailing zeros
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

// MARK: -

private extension String {
    var escaped: String {
        return
            replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    var isNumericLike: Bool {
        // Match numbers like: 42, -3.14, 1e-6, 05, etc.
        return range(
            of: #"^-?\d+(?:\.\d+)?(?:e[+-]?\d+)?$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
            || range(of: #"^0\d+$"#, options: .regularExpression) != nil
    }

    var isPaddedWithWhitespace: Bool {
        return self != trimmingCharacters(in: .whitespaces)
    }

    func isSafeUnquoted(delimiter: String = ",") -> Bool {
        if isEmpty {
            return false
        }

        if isPaddedWithWhitespace {
            return false
        }

        if self == "true" || self == "false" || self == "null" {
            return false
        }

        if isNumericLike {
            return false
        }

        // Check for colon (always structural)
        if contains(":") {
            return false
        }

        // Check for quotes and backslash (always need escaping)
        if contains("\"") || contains("\\") {
            return false
        }

        // Check for brackets and braces (always structural)
        if range(of: #"[\[\]{}]"#, options: .regularExpression) != nil {
            return false
        }

        // Check for control characters (newline, carriage return, tab - always need quoting/escaping)
        if range(of: #"[\n\r\t]"#, options: .regularExpression) != nil {
            return false
        }

        // Check for the active delimiter
        if contains(delimiter) {
            return false
        }

        // Check for hyphen at start (list marker)
        if hasPrefix("-") {
            return false
        }

        return true
    }

    var isValidUnquotedKey: Bool {
        // Match pattern: starts with letter or underscore, followed by word characters or dots
        return range(of: #"^[A-Z_][\w.]*$"#, options: [.regularExpression, .caseInsensitive])
            != nil
    }

    var isValidIdentifierSegment: Bool {
        // Match pattern for a single identifier segment (no dots)
        // Must start with letter or underscore, followed by word characters
        return range(of: #"^[A-Z_]\w*$"#, options: [.regularExpression, .caseInsensitive])
            != nil
    }
}
