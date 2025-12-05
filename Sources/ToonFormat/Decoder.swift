import Foundation

/// A decoder that converts TOON format data into Swift values.
///
/// This decoder conforms to the TOON (Token-Oriented Object Notation) specification version 3.0.
/// For more information, see https://github.com/toon-format/spec
public final class TOONDecoder {
    /// The path expansion mode for dotted keys.
    ///
    /// Use this property to control how the decoder interprets dotted keys
    /// like `a.b.c: value`. When you enable path expansion, the decoder
    /// converts dotted keys into nested objects. This is the inverse of
    /// ``TOONEncoder/keyFolding``.
    ///
    /// For example, with ``PathExpansion/safe`` or ``PathExpansion/automatic``,
    /// the following TOON input:
    ///
    /// ```toon
    /// user.profile.name: John
    /// ```
    ///
    /// Becomes equivalent to:
    ///
    /// ```toon
    /// user:
    ///   profile:
    ///     name: John
    /// ```
    public var expandPaths: PathExpansion = .automatic

    /// Limits for decoding to prevent resource exhaustion.
    ///
    /// Use this to protect against malicious or malformed input when parsing untrusted data.
    public var limits: DecodingLimits = .default

    /// Path expansion mode.
    ///
    /// Path expansion determines how dotted keys (e.g., `user.profile.name`) are interpreted
    /// during decoding. This enables a more compact representation of nested data structures.
    public enum PathExpansion: Hashable, Sendable {
        /// Automatic path expansion (default).
        ///
        /// Expands dotted keys when they match the target type's structure,
        /// falling back gracefully to literal string keys if expansion causes conflicts.
        ///
        /// This mode is ideal when you want the convenience of path expansion
        /// without risking decoding failures. If a dotted key like `a.b` would conflict
        /// with an existing key `a` that isn't an object, the decoder treats `a.b`
        /// as a literal key instead of throwing an error.
        ///
        /// Use this mode when decoding data that may contain a mix of dotted paths
        /// and literal keys with dots.
        case automatic

        /// No path expansion.
        ///
        /// Dotted keys are decoded as literal strings without any transformation.
        /// A key like `user.profile.name` remains a single key with that exact name,
        /// rather than being expanded into a nested `user` -> `profile` -> `name` structure.
        ///
        /// Use this mode when your data model uses dots in key names literally,
        /// or when you need complete control over key interpretation.
        case disabled

        /// Safe path expansion with collision detection.
        ///
        /// Expands dotted keys into nested objects, throwing ``TOONDecodingError/pathCollision(path:line:)``
        /// if expansion would conflict with existing keys.
        ///
        /// A collision occurs when a dotted path like `a.b.c` requires `a.b` to be an object,
        /// but `a.b` already exists as a non-object value (or vice versa).
        ///
        /// Use this mode when you want strict validation and prefer explicit errors
        /// over silent fallback behavior.
        case safe
    }

    /// Limits for decoding to prevent resource exhaustion.
    public struct DecodingLimits: Hashable, Sendable {
        /// Maximum input size in bytes.
        public var maxInputSize: Int

        /// Maximum nesting depth.
        public var maxDepth: Int

        /// Maximum number of keys in a single object.
        public var maxObjectKeys: Int

        /// Maximum array length.
        public var maxArrayLength: Int

        /// Default limits suitable for most use cases.
        ///
        /// - `maxInputSize`: 10 MB
        /// - `maxDepth`: 32 (prevents stack overflow from deep nesting)
        /// - `maxObjectKeys`: 10,000
        /// - `maxArrayLength`: 100,000
        public static let `default` = DecodingLimits(
            maxInputSize: 10 * 1024 * 1024,
            maxDepth: 32,
            maxObjectKeys: 10_000,
            maxArrayLength: 100_000
        )

        /// Decoding limits that impose no restrictions.
        ///
        /// - Warning: This configuration is unsafe for untrusted input
        ///   and should only be used with data from trusted sources.
        ///   Without limits, malicious input can cause excessive memory usage,
        ///   stack overflow from deep nesting, or denial-of-service attacks.
        ///
        /// Use this only when you have full control over the input data
        /// and need to decode arbitrarily large or complex TOON structures.
        ///
        /// For production use with external input, use ``default`` or
        /// ``init(maxInputSize:maxDepth:maxObjectKeys:maxArrayLength:)``
        /// with appropriate limits instead.
        public static let unlimited = DecodingLimits(
            maxInputSize: .max,
            maxDepth: .max,
            maxObjectKeys: .max,
            maxArrayLength: .max
        )

        public init(maxInputSize: Int, maxDepth: Int, maxObjectKeys: Int, maxArrayLength: Int) {
            self.maxInputSize = maxInputSize
            self.maxDepth = maxDepth
            self.maxObjectKeys = maxObjectKeys
            self.maxArrayLength = maxArrayLength
        }
    }

    /// Creates a new TOON decoder with default configuration.
    ///
    /// Default settings:
    /// - `expandPaths`: `.automatic`
    /// - `limits`: `.default`
    public init() {}

    /// Decodes TOON format data into the specified type.
    ///
    /// - Parameters:
    ///   - type: The type to decode into.
    ///   - data: UTF-8 encoded TOON data.
    /// - Returns: The decoded value.
    /// - Throws: ``TOONDecodingError`` if decoding fails.
    public func decode<T: Decodable>(_: T.Type, from data: Data) throws -> T {
        if data.count > limits.maxInputSize {
            throw TOONDecodingError.inputTooLarge(size: data.count, limit: limits.maxInputSize)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw TOONDecodingError.invalidFormat("Data is not valid UTF-8")
        }

        let parser = Parser(text: text, expandPaths: expandPaths, limits: limits)
        let value = try parser.parse()

        let decoder = Decoder(value: value, codingPath: [], userInfo: [:])
        return try T(from: decoder)
    }
}

// MARK: - Decoding Errors

/// Errors that can occur during TOON decoding.
public enum TOONDecodingError: Error, Equatable {
    /// The input data is not valid UTF-8 or has an invalid structure.
    case invalidFormat(String)

    /// Invalid indentation at the specified line.
    case invalidIndentation(line: Int, message: String)

    /// Invalid escape sequence in a string.
    case invalidEscapeSequence(String)

    /// Array element count doesn't match the declared length.
    case countMismatch(expected: Int, actual: Int, line: Int)

    /// Row field count doesn't match the header field count.
    case fieldCountMismatch(expected: Int, actual: Int, line: Int)

    /// Unexpected blank line inside an array or tabular block.
    case unexpectedBlankLine(line: Int)

    /// Invalid array header format.
    case invalidHeader(String)

    /// Type mismatch during decoding.
    case typeMismatch(expected: String, actual: String)

    /// Required key not found in the object.
    case keyNotFound(String)

    /// Data is corrupted or invalid.
    case dataCorrupted(String)

    /// Path expansion collision detected.
    case pathCollision(path: String, line: Int)

    /// Input size exceeds the limit.
    case inputTooLarge(size: Int, limit: Int)

    /// Nesting depth exceeds the limit.
    case depthLimitExceeded(depth: Int, limit: Int)

    /// Object has too many keys.
    case objectKeyLimitExceeded(count: Int, limit: Int)

    /// Array length exceeds the limit.
    case arrayLengthLimitExceeded(length: Int, limit: Int)
}

// MARK: - Parser

private final class Parser {
    private let lines: [String]
    private var indentSize: Int = 2
    private let expandPaths: TOONDecoder.PathExpansion
    private let limits: TOONDecoder.DecodingLimits
    private var currentLine: Int = 0
    private var indentDetected: Bool = false

    init(text: String, expandPaths: TOONDecoder.PathExpansion, limits: TOONDecoder.DecodingLimits) {
        // Split by LF, handling potential CR+LF
        lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        self.expandPaths = expandPaths
        self.limits = limits
    }

    func parse() throws -> Value {
        // Filter out empty lines for root detection, but keep track of original positions
        let nonEmptyLines = lines.enumerated().filter { !$0.element.isEmpty }

        if nonEmptyLines.isEmpty {
            // Empty document = empty object
            return .object([:], keyOrder: [])
        }

        // Detect root form
        let firstNonEmptyLine = nonEmptyLines[0].element
        let firstContent = trimIndentation(firstNonEmptyLine).content

        // Root array: first line is a valid array header WITHOUT a key (e.g., "[3]:" not "items[3]:")
        // An array header without key starts with "[" immediately
        if firstContent.hasPrefix("["), let _ = try? parseArrayHeader(String(firstContent)) {
            currentLine = nonEmptyLines[0].offset
            return try parseArrayAtCurrentLine(depth: 0, key: nil)
        }

        // Single primitive: exactly one non-empty line that's not an object key-value pair
        // A key-value pair has a colon NOT inside quotes and NOT part of an array header
        if nonEmptyLines.count == 1 {
            let contentStr = String(firstContent)
            if !isKeyValuePair(contentStr) {
                return try parsePrimitiveValue(contentStr)
            }
        }

        // Default: object
        currentLine = 0
        return try parseObject(atDepth: 0)
    }

    /// Checks if a line represents a key: value pair (as opposed to a single primitive value)
    private func isKeyValuePair(_ content: String) -> Bool {
        var inQuotes = false
        var escaped = false
        var bracketDepth = 0

        for char in content {
            if escaped {
                escaped = false
                continue
            }

            if char == "\\" {
                escaped = true
                continue
            }

            if char == "\"" {
                inQuotes.toggle()
                continue
            }

            if !inQuotes {
                if char == "[" {
                    bracketDepth += 1
                } else if char == "]" {
                    bracketDepth -= 1
                } else if char == ":" && bracketDepth == 0 {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Indentation Handling

    private func trimIndentation(_ line: String) -> (depth: Int, content: Substring) {
        var spaces = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == " " {
            spaces += 1
            index = line.index(after: index)
        }

        // Auto-detect indent size from first indented line
        if spaces > 0 && !indentDetected {
            indentSize = spaces
            indentDetected = true
        }

        // Calculate depth based on detected or default indent size
        let depth = indentSize > 0 ? spaces / indentSize : 0
        return (depth, line[index...])
    }

    private func peekLine() -> String? {
        guard currentLine < lines.count else { return nil }
        return lines[currentLine]
    }

    private func consumeLine() -> String? {
        guard currentLine < lines.count else { return nil }
        let line = lines[currentLine]
        currentLine += 1
        return line
    }

    private func skipEmptyLines() {
        while currentLine < lines.count, lines[currentLine].isEmpty {
            currentLine += 1
        }
    }

    // MARK: - Object Parsing

    private func parseObject(atDepth depth: Int) throws -> Value {
        // Check depth limit
        if depth > limits.maxDepth {
            throw TOONDecodingError.depthLimitExceeded(depth: depth, limit: limits.maxDepth)
        }

        var values: [String: Value] = [:]
        var keyOrder: [String] = []

        while let line = peekLine() {
            // Skip empty lines between object entries
            if line.isEmpty {
                _ = consumeLine()
                continue
            }

            let (lineDepth, content) = trimIndentation(line)

            // If we've decreased in depth, we're done with this object
            if lineDepth < depth {
                break
            }

            // If depth doesn't match expected, error
            if lineDepth != depth {
                throw TOONDecodingError.invalidIndentation(
                    line: currentLine + 1,
                    message: "Expected indentation depth \(depth), got \(lineDepth)"
                )
            }

            _ = consumeLine()

            // Parse the key-value pair
            let (key, value) = try parseKeyValuePair(String(content), atDepth: depth)

            // Handle path expansion if enabled
            if (expandPaths == .safe || expandPaths == .automatic) && key.contains(".") && key.isValidDottedPath {
                do {
                    try expandDottedKey(key, value: value, into: &values, keyOrder: &keyOrder)
                } catch {
                    // For .automatic mode, fall back to literal key on collision
                    if expandPaths == .automatic {
                        if !keyOrder.contains(key) {
                            keyOrder.append(key)
                        }
                        values[key] = value
                    } else {
                        throw error
                    }
                }
            } else {
                if !keyOrder.contains(key) {
                    keyOrder.append(key)
                }
                values[key] = value
            }

            // Check object key limit
            if keyOrder.count > limits.maxObjectKeys {
                throw TOONDecodingError.objectKeyLimitExceeded(count: keyOrder.count, limit: limits.maxObjectKeys)
            }
        }

        return .object(values, keyOrder: keyOrder)
    }

    private func parseKeyValuePair(_ content: String, atDepth depth: Int) throws -> (String, Value) {
        // Check for array header first: key[N]{fields}:
        if let header = try? parseArrayHeader(content) {
            let array = try parseArrayContent(header: header, atDepth: depth)
            return (header.key ?? "", array)
        }

        // Check for list item starting with "- "
        if content.hasPrefix("- ") {
            throw TOONDecodingError.invalidFormat("Unexpected list item outside array context at line \(currentLine)")
        }

        // Parse as key: value
        guard let colonIndex = findKeyValueSeparator(in: content) else {
            throw TOONDecodingError.invalidFormat("Expected key: value at line \(currentLine), got: \(content)")
        }

        let keyPart = String(content[..<colonIndex])
        let key = try parseKey(keyPart)

        let afterColon = content.index(after: colonIndex)
        let valuePart = String(content[afterColon...]).trimmingLeadingSpace()

        if valuePart.isEmpty {
            // Nested object or empty value
            let nestedValue = try parseNestedValue(atDepth: depth + 1)
            return (key, nestedValue)
        } else {
            // Inline value
            let value = try parsePrimitiveValue(valuePart)
            return (key, value)
        }
    }

    private func findKeyValueSeparator(in content: String) -> String.Index? {
        // Find the colon that separates key from value
        // Handle quoted keys: "key:with:colons": value
        var inQuotes = false
        var escaped = false
        var bracketDepth = 0

        for (i, char) in content.enumerated() {
            if escaped {
                escaped = false
                continue
            }

            if char == "\\" {
                escaped = true
                continue
            }

            if char == "\"" {
                inQuotes.toggle()
                continue
            }

            if !inQuotes {
                if char == "[" {
                    bracketDepth += 1
                } else if char == "]" {
                    bracketDepth -= 1
                } else if char == ":", bracketDepth == 0 {
                    return content.index(content.startIndex, offsetBy: i)
                }
            }
        }

        return nil
    }

    private func parseKey(_ keyPart: String) throws -> String {
        let trimmed = keyPart.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            // Quoted key
            let inner = String(trimmed.dropFirst().dropLast())
            return try unescapeString(inner)
        }

        // Unquoted key
        return trimmed
    }

    private func parseNestedValue(atDepth depth: Int) throws -> Value {
        skipEmptyLines()

        guard let line = peekLine() else {
            return .object([:], keyOrder: [])
        }

        let (lineDepth, content) = trimIndentation(line)

        if lineDepth < depth {
            // No nested content - empty object
            return .object([:], keyOrder: [])
        }

        if lineDepth != depth {
            throw TOONDecodingError.invalidIndentation(
                line: currentLine + 1,
                message: "Expected indentation depth \(depth), got \(lineDepth)"
            )
        }

        // Check if it's a list item
        if content.hasPrefix("- ") {
            // This shouldn't happen here - arrays should be parsed via array header
            throw TOONDecodingError.invalidFormat("Unexpected list item at line \(currentLine + 1)")
        }

        // Parse as nested object
        return try parseObject(atDepth: depth)
    }

    // MARK: - Array Parsing

    private struct ArrayHeader {
        let key: String?
        let count: Int
        let delimiter: String
        let fields: [String]?
        let hasLengthMarker: Bool
    }

    private func parseArrayHeader(_ content: String) throws -> ArrayHeader {
        // Pattern: [key][#N{delimiter}]{fields}:
        // Examples: [3]:, key[2]:, items[3]{a,b,c}:, items[2|]{a|b}:

        var remaining = content[...]

        // Extract key (optional)
        var key: String? = nil
        if remaining.first == "\"" {
            // Quoted key
            guard let endQuote = findClosingQuote(in: remaining) else {
                throw TOONDecodingError.invalidHeader("Unterminated quoted key in: \(content)")
            }
            let quotedKey = String(remaining[remaining.index(after: remaining.startIndex) ..< endQuote])
            key = try unescapeString(quotedKey)
            remaining = remaining[remaining.index(after: endQuote)...]
        } else if let bracketIndex = remaining.firstIndex(of: "[") {
            let keyPart = remaining[..<bracketIndex]
            if !keyPart.isEmpty {
                key = String(keyPart)
            }
            remaining = remaining[bracketIndex...]
        }

        // Must have bracket
        guard remaining.first == "[" else {
            throw TOONDecodingError.invalidHeader("Expected '[' in array header: \(content)")
        }
        remaining = remaining.dropFirst()

        // Check for length marker #
        var hasLengthMarker = false
        if remaining.first == "#" {
            hasLengthMarker = true
            remaining = remaining.dropFirst()
        }

        // Parse count
        var countStr = ""
        while let char = remaining.first, char.isNumber {
            countStr.append(char)
            remaining = remaining.dropFirst()
        }

        guard let count = Int(countStr) else {
            throw TOONDecodingError.invalidHeader("Invalid count in array header: \(content)")
        }

        // Check for delimiter indicator
        var delimiter = ","
        if let first = remaining.first, first == "|" || first == "\t" {
            delimiter = String(first)
            remaining = remaining.dropFirst()
        }

        // Must have closing bracket
        guard remaining.first == "]" else {
            throw TOONDecodingError.invalidHeader("Expected ']' in array header: \(content)")
        }
        remaining = remaining.dropFirst()

        // Check for fields
        var fields: [String]? = nil
        if remaining.first == "{" {
            remaining = remaining.dropFirst()
            guard let closeBrace = remaining.firstIndex(of: "}") else {
                throw TOONDecodingError.invalidHeader("Unterminated fields in array header: \(content)")
            }
            let fieldsStr = String(remaining[..<closeBrace])
            fields = try parseFieldsList(fieldsStr, delimiter: delimiter)
            remaining = remaining[remaining.index(after: closeBrace)...]
        }

        // Must end with colon
        guard remaining.first == ":" else {
            throw TOONDecodingError.invalidHeader("Expected ':' at end of array header: \(content)")
        }

        return ArrayHeader(
            key: key,
            count: count,
            delimiter: delimiter,
            fields: fields,
            hasLengthMarker: hasLengthMarker
        )
    }

    private func findClosingQuote(in str: Substring) -> String.Index? {
        var escaped = false
        var index = str.index(after: str.startIndex)  // Skip opening quote

        while index < str.endIndex {
            let char = str[index]
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                return index
            }
            index = str.index(after: index)
        }

        return nil
    }

    private func parseFieldsList(_ fieldsStr: String, delimiter: String) throws -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var escaped = false

        for char in fieldsStr {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }

            if char == "\\" {
                escaped = true
                current.append(char)
                continue
            }

            if char == "\"" {
                inQuotes.toggle()
                current.append(char)
                continue
            }

            if !inQuotes, String(char) == delimiter {
                try fields.append(parseFieldName(current))
                current = ""
                continue
            }

            current.append(char)
        }

        if !current.isEmpty {
            try fields.append(parseFieldName(current))
        }

        return fields
    }

    private func parseFieldName(_ field: String) throws -> String {
        let trimmed = field.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            let inner = String(trimmed.dropFirst().dropLast())
            return try unescapeString(inner)
        }
        return trimmed
    }

    private func parseArrayAtCurrentLine(depth: Int, key _: String?) throws -> Value {
        guard let line = consumeLine() else {
            throw TOONDecodingError.invalidFormat("Expected array header")
        }

        let (_, content) = trimIndentation(line)
        let header = try parseArrayHeader(String(content))
        return try parseArrayContent(header: header, atDepth: depth)
    }

    private func parseArrayContent(header: ArrayHeader, atDepth depth: Int) throws -> Value {
        // Check array length limit
        if header.count > limits.maxArrayLength {
            throw TOONDecodingError.arrayLengthLimitExceeded(length: header.count, limit: limits.maxArrayLength)
        }

        // Check for inline values after header
        // For example: tags[3]: a,b,c

        // Re-parse to get the full line with potential inline values
        let headerLine = lines[currentLine - 1]
        let (_, content) = trimIndentation(headerLine)
        let contentStr = String(content)

        // Find where the header ends (after the colon)
        if let colonIndex = contentStr.lastIndex(of: ":") {
            let afterColon = contentStr[contentStr.index(after: colonIndex)...]
            let inlineValues = afterColon.trimmingLeadingSpace()

            if !inlineValues.isEmpty {
                // Inline primitive array
                let values = try parseDelimitedValues(String(inlineValues), delimiter: header.delimiter)
                if values.count != header.count {
                    throw TOONDecodingError.countMismatch(
                        expected: header.count,
                        actual: values.count,
                        line: currentLine
                    )
                }
                return .array(values)
            }
        }

        // No inline values - parse expanded content
        if header.count == 0 {
            return .array([])
        }

        var items: [Value] = []

        if let fields = header.fields {
            // Tabular format
            items = try parseTabularRows(
                count: header.count,
                fields: fields,
                delimiter: header.delimiter,
                atDepth: depth
            )
        } else {
            // List format or array of arrays
            items = try parseListItems(count: header.count, delimiter: header.delimiter, atDepth: depth)
        }

        if items.count != header.count {
            throw TOONDecodingError.countMismatch(expected: header.count, actual: items.count, line: currentLine)
        }

        return .array(items)
    }

    private func parseTabularRows(count: Int, fields: [String], delimiter: String, atDepth depth: Int) throws -> [Value]
    {
        var rows: [Value] = []
        let expectedDepth = depth + 1

        for _ in 0 ..< count {
            skipEmptyLines()

            guard let line = consumeLine() else {
                break
            }

            if line.isEmpty {
                throw TOONDecodingError.unexpectedBlankLine(line: currentLine)
            }

            let (lineDepth, content) = trimIndentation(line)

            if lineDepth != expectedDepth {
                throw TOONDecodingError.invalidIndentation(
                    line: currentLine,
                    message: "Expected indentation depth \(expectedDepth), got \(lineDepth)"
                )
            }

            let values = try parseDelimitedValues(String(content), delimiter: delimiter)

            if values.count != fields.count {
                throw TOONDecodingError.fieldCountMismatch(
                    expected: fields.count,
                    actual: values.count,
                    line: currentLine
                )
            }

            // Build object from fields and values
            var objectValues: [String: Value] = [:]
            for (i, field) in fields.enumerated() {
                objectValues[field] = values[i]
            }
            rows.append(.object(objectValues, keyOrder: fields))
        }

        return rows
    }

    private func parseListItems(count: Int, delimiter: String, atDepth depth: Int) throws -> [Value] {
        var items: [Value] = []
        let expectedDepth = depth + 1

        for _ in 0 ..< count {
            skipEmptyLines()

            guard let line = peekLine() else {
                break
            }

            if line.isEmpty {
                throw TOONDecodingError.unexpectedBlankLine(line: currentLine + 1)
            }

            let (lineDepth, content) = trimIndentation(line)

            if lineDepth != expectedDepth {
                throw TOONDecodingError.invalidIndentation(
                    line: currentLine + 1,
                    message: "Expected indentation depth \(expectedDepth), got \(lineDepth)"
                )
            }

            _ = consumeLine()

            // Must start with "- "
            guard content.hasPrefix("- ") else {
                throw TOONDecodingError.invalidFormat("Expected list item starting with '- ' at line \(currentLine)")
            }

            let itemContent = String(content.dropFirst(2))
            let item = try parseListItemContent(itemContent, atDepth: expectedDepth, delimiter: delimiter)
            items.append(item)
        }

        return items
    }

    private func parseListItemContent(_ content: String, atDepth depth: Int, delimiter _: String) throws -> Value {
        // Check for array header WITHOUT key: - [N]: a,b,c
        // This returns a bare array, not an object with an array field
        if content.hasPrefix("["), let header = try? parseArrayHeader(content) {
            return try parseArrayContent(header: header, atDepth: depth)
        }

        // Check for key: value on same line (may be key[N]: values for array)
        if let colonIndex = findKeyValueSeparator(in: content) {
            let keyPart = String(content[..<colonIndex])
            let key = try parseKey(keyPart)

            let afterColon = content.index(after: colonIndex)
            let valuePart = String(content[afterColon...]).trimmingLeadingSpace()

            var objectValues: [String: Value] = [:]
            var keyOrder: [String] = [key]

            if valuePart.isEmpty {
                // Nested value
                let nestedValue = try parseNestedValue(atDepth: depth + 1)
                objectValues[key] = nestedValue
            } else {
                // Check if the key is an array header (like nums[3])
                // The full string would be "nums[3]: 1,2,3"
                if let header = try? parseArrayHeader(content) {
                    // Parse as array with the key
                    let array = try parseArrayContent(header: header, atDepth: depth)
                    let arrayKey = header.key ?? key
                    if !keyOrder.contains(arrayKey) && arrayKey != key {
                        keyOrder = [arrayKey]
                    }
                    objectValues[arrayKey] = array
                } else {
                    // Inline primitive value
                    objectValues[key] = try parsePrimitiveValue(valuePart)
                }
            }

            // Parse additional fields at depth + 1
            while let nextLine = peekLine() {
                if nextLine.isEmpty {
                    _ = consumeLine()
                    continue
                }

                let (nextDepth, nextContent) = trimIndentation(nextLine)

                if nextDepth != depth + 1 {
                    break
                }

                // Check if it's another list item (shouldn't be at this depth)
                if nextContent.hasPrefix("- ") {
                    break
                }

                _ = consumeLine()

                let (nextKey, nextValue) = try parseKeyValuePair(String(nextContent), atDepth: depth + 1)
                if !keyOrder.contains(nextKey) {
                    keyOrder.append(nextKey)
                }
                objectValues[nextKey] = nextValue
            }

            return .object(objectValues, keyOrder: keyOrder)
        }

        // Single primitive value
        return try parsePrimitiveValue(content)
    }

    // MARK: - Value Parsing

    private func parseDelimitedValues(_ content: String, delimiter: String) throws -> [Value] {
        var values: [Value] = []
        var current = ""
        var inQuotes = false
        var escaped = false

        for char in content {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }

            if char == "\\" {
                escaped = true
                current.append(char)
                continue
            }

            if char == "\"" {
                inQuotes.toggle()
                current.append(char)
                continue
            }

            if !inQuotes, String(char) == delimiter {
                try values.append(parsePrimitiveValue(current.trimmingCharacters(in: .whitespaces)))
                current = ""
                continue
            }

            current.append(char)
        }

        // Handle last value
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty || !values.isEmpty {
            try values.append(parsePrimitiveValue(trimmed))
        }

        return values
    }

    private func parsePrimitiveValue(_ content: String) throws -> Value {
        let trimmed = content.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return .string("")
        }

        // Quoted string
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            let inner = String(trimmed.dropFirst().dropLast())
            return try .string(unescapeString(inner))
        }

        // Boolean
        if trimmed == "true" {
            return .bool(true)
        }
        if trimmed == "false" {
            return .bool(false)
        }

        // Null
        if trimmed == "null" {
            return .null
        }

        // Number
        if let intValue = Int64(trimmed) {
            return .int(intValue)
        }

        if let doubleValue = Double(trimmed), trimmed.contains(".") || trimmed.lowercased().contains("e") {
            return .double(doubleValue)
        }

        // Default to string
        return .string(trimmed)
    }

    // MARK: - String Handling

    private func unescapeString(_ str: String) throws -> String {
        var result = ""
        var escaped = false

        for char in str {
            if escaped {
                switch char {
                case "\\": result.append("\\")
                case "\"": result.append("\"")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                default:
                    throw TOONDecodingError.invalidEscapeSequence("Invalid escape sequence: \\\(char)")
                }
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else {
                result.append(char)
            }
        }

        if escaped {
            throw TOONDecodingError.invalidEscapeSequence("Trailing backslash in string")
        }

        return result
    }

    // MARK: - Path Expansion

    private func expandDottedKey(
        _ key: String,
        value: Value,
        into values: inout [String: Value],
        keyOrder: inout [String]
    ) throws {
        let segments = key.split(separator: ".").map(String.init)

        guard segments.count > 1 else {
            if !keyOrder.contains(key) {
                keyOrder.append(key)
            }
            values[key] = value
            return
        }

        let firstKey = segments[0]
        if !keyOrder.contains(firstKey) {
            keyOrder.append(firstKey)
        }

        // Merge the value into the nested structure
        values[firstKey] = try mergeValueAtPath(
            into: values[firstKey],
            segments: Array(segments.dropFirst()),
            value: value
        )
    }

    private func mergeValueAtPath(
        into existing: Value?,
        segments: [String],
        value: Value
    ) throws -> Value {
        guard let segment = segments.first else {
            return value
        }

        let remainingSegments = Array(segments.dropFirst())

        // Get or create object at current level
        var objectValues: [String: Value]
        var objectKeyOrder: [String]

        if let existing = existing {
            guard case let .object(vals, order) = existing else {
                throw TOONDecodingError.pathCollision(path: segment, line: currentLine)
            }
            objectValues = vals
            objectKeyOrder = order
        } else {
            objectValues = [:]
            objectKeyOrder = []
        }

        // Recursively merge
        objectValues[segment] = try mergeValueAtPath(
            into: objectValues[segment],
            segments: remainingSegments,
            value: value
        )

        if !objectKeyOrder.contains(segment) {
            objectKeyOrder.append(segment)
        }

        return .object(objectValues, keyOrder: objectKeyOrder)
    }
}

// MARK: - Internal Decoder

extension TOONDecoder {
    /// Internal decoder implementation that conforms to the `Decoder` protocol.
    private final class Decoder: Swift.Decoder {
        let value: Value
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        init(value: Value, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.value = value
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key>
        where Key: CodingKey {
            guard let (values, keyOrder) = value.objectValue else {
                throw TOONDecodingError.typeMismatch(expected: "object", actual: value.typeName)
            }
            let container = KeyedContainer<Key>(
                values: values,
                keyOrder: keyOrder,
                codingPath: codingPath,
                userInfo: userInfo
            )
            return KeyedDecodingContainer(container)
        }

        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            guard let array = value.arrayValue else {
                throw TOONDecodingError.typeMismatch(expected: "array", actual: value.typeName)
            }
            return UnkeyedContainer(values: array, codingPath: codingPath, userInfo: userInfo)
        }

        func singleValueContainer() throws -> SingleValueDecodingContainer {
            return SingleValueContainer(value: value, codingPath: codingPath, userInfo: userInfo)
        }
    }
}

// MARK: - Keyed Decoding Container

extension TOONDecoder {
    private final class KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let values: [String: Value]
        let keyOrder: [String]
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        var allKeys: [Key] {
            keyOrder.compactMap { Key(stringValue: $0) }
        }

        init(
            values: [String: Value],
            keyOrder: [String],
            codingPath: [CodingKey],
            userInfo: [CodingUserInfoKey: Any]
        ) {
            self.values = values
            self.keyOrder = keyOrder
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        func contains(_ key: Key) -> Bool {
            values[key.stringValue] != nil
        }

        private func getValue(forKey key: Key) throws -> Value {
            guard let value = values[key.stringValue] else {
                throw TOONDecodingError.keyNotFound(key.stringValue)
            }
            return value
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            guard let value = values[key.stringValue] else {
                throw TOONDecodingError.keyNotFound(key.stringValue)
            }
            return value.isNull
        }

        func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
            let value = try getValue(forKey: key)
            guard let boolValue = value.boolValue else {
                throw TOONDecodingError.typeMismatch(expected: "bool", actual: value.typeName)
            }
            return boolValue
        }

        func decode(_: String.Type, forKey key: Key) throws -> String {
            let value = try getValue(forKey: key)
            guard let stringValue = value.stringValue else {
                throw TOONDecodingError.typeMismatch(expected: "string", actual: value.typeName)
            }
            return stringValue
        }

        func decode(_: Double.Type, forKey key: Key) throws -> Double {
            let value = try getValue(forKey: key)
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "double", actual: value.typeName)
            }
            return doubleValue
        }

        func decode(_: Float.Type, forKey key: Key) throws -> Float {
            let value = try getValue(forKey: key)
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "float", actual: value.typeName)
            }
            return Float(doubleValue)
        }

        func decode(_: Int.Type, forKey key: Key) throws -> Int {
            try decodeInt(from: getValue(forKey: key))
        }

        func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
            try decodeInt8(from: getValue(forKey: key))
        }

        func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
            try decodeInt16(from: getValue(forKey: key))
        }

        func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
            try decodeInt32(from: getValue(forKey: key))
        }

        func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
            let value = try getValue(forKey: key)
            guard let intValue = value.intValue else {
                throw TOONDecodingError.typeMismatch(expected: "int64", actual: value.typeName)
            }
            return intValue
        }

        func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
            try decodeUInt(from: getValue(forKey: key))
        }

        func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
            try decodeUInt8(from: getValue(forKey: key))
        }

        func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
            try decodeUInt16(from: getValue(forKey: key))
        }

        func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
            try decodeUInt32(from: getValue(forKey: key))
        }

        func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
            try decodeUInt64(from: getValue(forKey: key))
        }

        func decode<T>(_: T.Type, forKey key: Key) throws -> T where T: Decodable {
            let value = try getValue(forKey: key)

            // Handle special types
            if T.self == Date.self {
                return try decodeDate(from: value) as! T
            }

            if T.self == URL.self {
                return try decodeURL(from: value) as! T
            }

            if T.self == Data.self {
                return try decodeData(from: value) as! T
            }

            let decoder = Decoder(
                value: value,
                codingPath: codingPath + [key],
                userInfo: userInfo
            )
            return try T(from: decoder)
        }

        func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey key: Key) throws
            -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
        {
            let value = try getValue(forKey: key)
            guard let (values, keyOrder) = value.objectValue else {
                throw TOONDecodingError.typeMismatch(expected: "object", actual: value.typeName)
            }
            let container = KeyedContainer<NestedKey>(
                values: values,
                keyOrder: keyOrder,
                codingPath: codingPath + [key],
                userInfo: userInfo
            )
            return KeyedDecodingContainer(container)
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            let value = try getValue(forKey: key)
            guard let array = value.arrayValue else {
                throw TOONDecodingError.typeMismatch(expected: "array", actual: value.typeName)
            }
            return UnkeyedContainer(values: array, codingPath: codingPath + [key], userInfo: userInfo)
        }

        func superDecoder() throws -> Swift.Decoder {
            let value = values["super"] ?? .null
            return Decoder(value: value, codingPath: codingPath, userInfo: userInfo)
        }

        func superDecoder(forKey key: Key) throws -> Swift.Decoder {
            let value = try getValue(forKey: key)
            return Decoder(value: value, codingPath: codingPath + [key], userInfo: userInfo)
        }
    }
}

// MARK: - Unkeyed Decoding Container

extension TOONDecoder {
    private final class UnkeyedContainer: UnkeyedDecodingContainer {
        let values: [Value]
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        var count: Int? { values.count }
        var isAtEnd: Bool { currentIndex >= values.count }
        var currentIndex: Int = 0

        init(values: [Value], codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.values = values
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        private func getCurrentValue() throws -> Value {
            guard currentIndex < values.count else {
                throw TOONDecodingError.dataCorrupted("No more values in array")
            }
            let value = values[currentIndex]
            currentIndex += 1
            return value
        }

        func decodeNil() throws -> Bool {
            guard currentIndex < values.count else {
                throw TOONDecodingError.dataCorrupted("No more values in array")
            }
            if values[currentIndex].isNull {
                currentIndex += 1
                return true
            }
            return false
        }

        func decode(_: Bool.Type) throws -> Bool {
            let value = try getCurrentValue()
            guard let boolValue = value.boolValue else {
                throw TOONDecodingError.typeMismatch(expected: "bool", actual: value.typeName)
            }
            return boolValue
        }

        func decode(_: String.Type) throws -> String {
            let value = try getCurrentValue()
            guard let stringValue = value.stringValue else {
                throw TOONDecodingError.typeMismatch(expected: "string", actual: value.typeName)
            }
            return stringValue
        }

        func decode(_: Double.Type) throws -> Double {
            let value = try getCurrentValue()
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "double", actual: value.typeName)
            }
            return doubleValue
        }

        func decode(_: Float.Type) throws -> Float {
            let value = try getCurrentValue()
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "float", actual: value.typeName)
            }
            return Float(doubleValue)
        }

        func decode(_: Int.Type) throws -> Int {
            try decodeInt(from: getCurrentValue())
        }

        func decode(_: Int8.Type) throws -> Int8 {
            try decodeInt8(from: getCurrentValue())
        }

        func decode(_: Int16.Type) throws -> Int16 {
            try decodeInt16(from: getCurrentValue())
        }

        func decode(_: Int32.Type) throws -> Int32 {
            try decodeInt32(from: getCurrentValue())
        }

        func decode(_: Int64.Type) throws -> Int64 {
            let value = try getCurrentValue()
            guard let intValue = value.intValue else {
                throw TOONDecodingError.typeMismatch(expected: "int64", actual: value.typeName)
            }
            return intValue
        }

        func decode(_: UInt.Type) throws -> UInt {
            try decodeUInt(from: getCurrentValue())
        }

        func decode(_: UInt8.Type) throws -> UInt8 {
            try decodeUInt8(from: getCurrentValue())
        }

        func decode(_: UInt16.Type) throws -> UInt16 {
            try decodeUInt16(from: getCurrentValue())
        }

        func decode(_: UInt32.Type) throws -> UInt32 {
            try decodeUInt32(from: getCurrentValue())
        }

        func decode(_: UInt64.Type) throws -> UInt64 {
            try decodeUInt64(from: getCurrentValue())
        }

        func decode<T>(_: T.Type) throws -> T where T: Decodable {
            let value = try getCurrentValue()

            // Handle special types
            if T.self == Date.self {
                return try decodeDate(from: value) as! T
            }

            if T.self == URL.self {
                return try decodeURL(from: value) as! T
            }

            if T.self == Data.self {
                return try decodeData(from: value) as! T
            }

            let decoder = Decoder(
                value: value,
                codingPath: codingPath + [IndexedCodingKey(intValue: currentIndex - 1)],
                userInfo: userInfo
            )
            return try T(from: decoder)
        }

        func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey {
            let value = try getCurrentValue()
            guard let (values, keyOrder) = value.objectValue else {
                throw TOONDecodingError.typeMismatch(expected: "object", actual: value.typeName)
            }
            let container = KeyedContainer<NestedKey>(
                values: values,
                keyOrder: keyOrder,
                codingPath: codingPath + [IndexedCodingKey(intValue: currentIndex - 1)],
                userInfo: userInfo
            )
            return KeyedDecodingContainer(container)
        }

        func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let value = try getCurrentValue()
            guard let array = value.arrayValue else {
                throw TOONDecodingError.typeMismatch(expected: "array", actual: value.typeName)
            }
            return UnkeyedContainer(
                values: array,
                codingPath: codingPath + [IndexedCodingKey(intValue: currentIndex - 1)],
                userInfo: userInfo
            )
        }

        func superDecoder() throws -> Swift.Decoder {
            let value = try getCurrentValue()
            return Decoder(
                value: value,
                codingPath: codingPath + [IndexedCodingKey(intValue: currentIndex - 1)],
                userInfo: userInfo
            )
        }
    }
}

// MARK: - Single Value Decoding Container

extension TOONDecoder {
    private final class SingleValueContainer: SingleValueDecodingContainer {
        let value: Value
        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        init(value: Value, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
            self.value = value
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        func decodeNil() -> Bool {
            value.isNull
        }

        func decode(_: Bool.Type) throws -> Bool {
            guard let boolValue = value.boolValue else {
                throw TOONDecodingError.typeMismatch(expected: "bool", actual: value.typeName)
            }
            return boolValue
        }

        func decode(_: String.Type) throws -> String {
            guard let stringValue = value.stringValue else {
                throw TOONDecodingError.typeMismatch(expected: "string", actual: value.typeName)
            }
            return stringValue
        }

        func decode(_: Double.Type) throws -> Double {
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "double", actual: value.typeName)
            }
            return doubleValue
        }

        func decode(_: Float.Type) throws -> Float {
            guard let doubleValue = value.doubleValue else {
                throw TOONDecodingError.typeMismatch(expected: "float", actual: value.typeName)
            }
            return Float(doubleValue)
        }

        func decode(_: Int.Type) throws -> Int {
            try decodeInt(from: value)
        }

        func decode(_: Int8.Type) throws -> Int8 {
            try decodeInt8(from: value)
        }

        func decode(_: Int16.Type) throws -> Int16 {
            try decodeInt16(from: value)
        }

        func decode(_: Int32.Type) throws -> Int32 {
            try decodeInt32(from: value)
        }

        func decode(_: Int64.Type) throws -> Int64 {
            guard let intValue = value.intValue else {
                throw TOONDecodingError.typeMismatch(expected: "int64", actual: value.typeName)
            }
            return intValue
        }

        func decode(_: UInt.Type) throws -> UInt {
            try decodeUInt(from: value)
        }

        func decode(_: UInt8.Type) throws -> UInt8 {
            try decodeUInt8(from: value)
        }

        func decode(_: UInt16.Type) throws -> UInt16 {
            try decodeUInt16(from: value)
        }

        func decode(_: UInt32.Type) throws -> UInt32 {
            try decodeUInt32(from: value)
        }

        func decode(_: UInt64.Type) throws -> UInt64 {
            try decodeUInt64(from: value)
        }

        func decode<T>(_: T.Type) throws -> T where T: Decodable {
            // Handle special types
            if T.self == Date.self {
                return try decodeDate(from: value) as! T
            }

            if T.self == URL.self {
                return try decodeURL(from: value) as! T
            }

            if T.self == Data.self {
                return try decodeData(from: value) as! T
            }

            let decoder = Decoder(value: value, codingPath: codingPath, userInfo: userInfo)
            return try T(from: decoder)
        }
    }
}

// MARK: - Decoding Helpers

// ISO8601DateFormatter is not Sendable, so we create a new instance per decode
// This is thread-safe and avoids shared mutable state
private func decodeDate(from value: Value) throws -> Date {
    guard let stringValue = value.stringValue else {
        throw TOONDecodingError.typeMismatch(expected: "date string", actual: value.typeName)
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: stringValue) else {
        throw TOONDecodingError.dataCorrupted("Invalid date format: \(stringValue)")
    }
    return date
}

private func decodeURL(from value: Value) throws -> URL {
    guard let stringValue = value.stringValue else {
        throw TOONDecodingError.typeMismatch(expected: "URL string", actual: value.typeName)
    }
    guard !stringValue.isEmpty, let url = URL(string: stringValue) else {
        throw TOONDecodingError.dataCorrupted("Invalid URL: \(stringValue)")
    }
    return url
}

private func decodeData(from value: Value) throws -> Data {
    guard let stringValue = value.stringValue else {
        throw TOONDecodingError.typeMismatch(expected: "base64 string", actual: value.typeName)
    }
    guard let data = Data(base64Encoded: stringValue) else {
        throw TOONDecodingError.dataCorrupted("Invalid base64 data: \(stringValue)")
    }
    return data
}

private func decodeInt8(from value: Value) throws -> Int8 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "int8", actual: value.typeName)
    }
    guard let result = Int8(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in Int8")
    }
    return result
}

private func decodeInt16(from value: Value) throws -> Int16 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "int16", actual: value.typeName)
    }
    guard let result = Int16(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in Int16")
    }
    return result
}

private func decodeInt32(from value: Value) throws -> Int32 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "int32", actual: value.typeName)
    }
    guard let result = Int32(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in Int32")
    }
    return result
}

private func decodeInt(from value: Value) throws -> Int {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "int", actual: value.typeName)
    }
    guard let result = Int(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in Int")
    }
    return result
}

private func decodeUInt(from value: Value) throws -> UInt {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint", actual: value.typeName)
    }
    guard let result = UInt(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt")
    }
    return result
}

private func decodeUInt8(from value: Value) throws -> UInt8 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint8", actual: value.typeName)
    }
    guard let result = UInt8(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt8")
    }
    return result
}

private func decodeUInt16(from value: Value) throws -> UInt16 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint16", actual: value.typeName)
    }
    guard let result = UInt16(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt16")
    }
    return result
}

private func decodeUInt32(from value: Value) throws -> UInt32 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint32", actual: value.typeName)
    }
    guard let result = UInt32(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt32")
    }
    return result
}

private func decodeUInt64(from value: Value) throws -> UInt64 {
    guard let intValue = value.intValue else {
        throw TOONDecodingError.typeMismatch(expected: "uint64", actual: value.typeName)
    }
    guard let result = UInt64(exactly: intValue) else {
        throw TOONDecodingError.dataCorrupted("Value \(intValue) does not fit in UInt64")
    }
    return result
}

// MARK: -

private extension String {
    func trimmingLeadingSpace() -> String {
        guard let first = first, first == " " else { return self }
        return String(dropFirst())
    }

    var isValidDottedPath: Bool {
        // Valid dotted path must have segments that are valid identifiers
        let segments = split(separator: ".")
        guard segments.count > 1 else { return false }
        return segments.allSatisfy { $0.isValidIdentifier }
    }
}

private extension Substring {
    func trimmingLeadingSpace() -> Substring {
        guard let first = first, first == " " else { return self }
        return dropFirst()
    }

    var isValidIdentifier: Bool {
        guard let first = first else { return false }
        guard first.isLetter || first == "_" else { return false }
        return dropFirst().allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
