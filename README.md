# TOON Format for Swift

[![CI](https://github.com/toon-format/toon-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/toon-format/toon-swift/actions)
[![Swift Version](https://img.shields.io/badge/swift-6.0+-orange.svg)](https://swift.org)
[![SPEC v3.0](https://img.shields.io/badge/spec-v3.0-fef3c0?labelColor=1b1b1f)](https://github.com/toon-format/spec)
[![License: MIT](https://img.shields.io/badge/license-MIT-fef3c0?labelColor=1b1b1f)](./LICENSE.md)

Compact, human-readable serialization format for LLM contexts with **30-60% token reduction** vs JSON. Combines YAML-like indentation with CSV-like tabular arrays. Full compatibility with the [official TOON specification](https://github.com/toon-format/spec).

**Key Features:** Minimal syntax • Tabular arrays for uniform data • Array length validation • Swift 6.0+ • Configurable delimiters • Key folding / Path expansion support • Linux compatible.

LLM tokens are expensive, and JSON is verbose.
TOON saves tokens while remaining human-readable by
using indentation for structure and a tabular format for uniform data:

**JSON**:

```json
{
  "users": [
    { "id": 1, "name": "Alice", "role": "admin" },
    { "id": 2, "name": "Bob", "role": "user" }
  ]
}
```

**TOON**:

```
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
```

For full details on TOON's design, benchmarks, and specification,
see the [TOON specification](https://github.com/toon-format/spec).

## Features

### TOONEncoder

`TOONEncoder` conforms to **TOON specification version 3.0** (2025-11-24)
and implements the following features:

- [x] Canonical number formatting (no trailing zeros, no leading zeros except `0`; `-0` normalized to `0`)
- [x] Correct escape sequences for strings (`\\`, `\"`, `\n`, `\r`, `\t`)
- [x] Three delimiter types: comma (default), tab, pipe
- [x] Array length validation
- [x] Object key order preservation
- [x] Array order preservation
- [x] Tabular format for uniform object arrays
- [x] Inline format for primitive arrays
- [x] Expanded list format for nested structures
- [x] Key folding to collapse single-key object chains into dotted paths
- [x] Configurable flatten depth to limit the depth of key folding
- [x] Collision avoidance so folded keys never collide with existing sibling keys

### TOONDecoder

`TOONDecoder` conforms to **TOON specification version 3.0** (2025-11-24)
and implements the following features:

- [x] Correct escape sequence parsing (`\\`, `\"`, `\n`, `\r`, `\t`)
- [x] Three delimiter types: comma (default), tab, pipe
- [x] Array length validation
- [x] Tabular format parsing with field headers
- [x] Inline format for primitive arrays
- [x] Expanded list format for nested structures
- [x] Path expansion to unfold dotted keys into nested objects (inverse of key folding)
- [x] Detailed error reporting with line numbers
- [x] Configurable decoding limits for security

## Requirements

- Swift 6.0+ / Xcode 16+
- iOS 13.0+ / macOS 10.15+ / watchOS 6.0+ / tvOS 13.0+ / visionOS 1.0+ / Linux

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/toon-format/toon-swift.git", from: "0.3.0")
]
```

Then add the dependency to your target:

```swift
.target(name: "YourTarget", dependencies: ["ToonFormat"])
```

## Usage

### Quick Start

```swift
import ToonFormat

struct User: Codable {
    let id: Int
    let name: String
    let tags: [String]
    let active: Bool
}

// Encoding
let user = User(
    id: 123,
    name: "Ada",
    tags: ["reading", "gaming"],
    active: true
)

let encoder = TOONEncoder()
let data = try encoder.encode(user)
print(String(data: data, encoding: .utf8)!)
// id: 123
// name: Ada
// tags[2]: reading,gaming
// active: true

// Decoding
let decoder = TOONDecoder()
let decoded = try decoder.decode(User.self, from: data)
print(decoded.name) // "Ada"
```

#### Custom Delimiters

Use tab or pipe delimiters for additional token savings:

```swift
struct Item: Codable {
    let sku: String
    let name: String
    let qty: Int
    let price: Double
}

let items = [
    Item(sku: "A1", name: "Widget", qty: 2, price: 9.99),
    Item(sku: "B2", name: "Gadget", qty: 1, price: 14.5)
]

let encoder = TOONEncoder()
encoder.delimiter = .tab  // or .pipe

let data = try encoder.encode(["items": items])
```

Output with tab delimiter:

```
items[2	]{sku	name	qty	price}:
  A1	Widget	2	9.99
  B2	Gadget	1	14.5
```

Output with pipe delimiter:

```
items[2|]{sku|name|qty|price}:
  A1|Widget|2|9.99
  B2|Gadget|1|14.5
```

#### Tabular Arrays

Arrays of objects with identical primitive fields use an efficient tabular format:

```swift
struct Item: Codable {
    let sku: String
    let qty: Int
    let price: Double
}

let items = [
    Item(sku: "A1", qty: 2, price: 9.99),
    Item(sku: "B2", qty: 1, price: 14.5)
]

let encoder = TOONEncoder()
let data = try encoder.encode(["items": items])
```

Output:

```
items[2]{sku,qty,price}:
  A1,2,9.99
  B2,1,14.5
```

#### Arrays of Arrays

For arrays containing primitive inner arrays:

```swift
let pairs = [[1, 2], [3, 4]]

let encoder = TOONEncoder()
let data = try encoder.encode(["pairs": pairs])
```

Output:

```
pairs[2]:
  - [2]: 1,2
  - [2]: 3,4
```

#### Key Folding

Key folding collapses single-key nested objects into dotted paths, reducing indentation and token count:

```swift
struct Config: Codable {
    struct Database: Codable {
        struct Connection: Codable {
            let host: String
            let port: Int
        }
        let connection: Connection
    }
    let database: Database
}

let config = Config(
    database: .init(
        connection: .init(host: "localhost", port: 5432)
    )
)

let encoder = TOONEncoder()
encoder.keyFolding = .safe
let data = try encoder.encode(config)
```

Without key folding:

```
database:
  connection:
    host: localhost
    port: 5432
```

Output with key folding (`encoder.keyFolding = .safe`):

```
database.connection:
  host: localhost
  port: 5432
```

### Decoding Limits

Protect against malicious or malformed input:

```swift
let decoder = TOONDecoder()
decoder.limits = TOONDecoder.DecodingLimits(
    maxInputSize: 1024 * 1024,  // 1 MB
    maxDepth: 64,
    maxObjectKeys: 1000,
    maxArrayLength: 10000
)
```

### Version Information

Check the supported TOON specification version:

```swift
print(toonSpecVersion) // "3.0"
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on how to get started, coding standards, and the process for submitting pull requests.

Before contributing, please review:

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [TOON Specification](https://github.com/toon-format/spec/blob/main/SPEC.md)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to hello@johannschopplich.com.

## Project Status

This library implements **TOON specification version 3.0** (2025-11-24) with full encoding and decoding support.

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Documentation

- [📜 TOON Spec](https://github.com/toon-format/spec) - Official specification
- [🐛 Issues](https://github.com/toon-format/toon-swift/issues) - Bug reports and features
- [🤝 Contributing](CONTRIBUTING.md) - Contribution guidelines

## License

MIT License – see [LICENSE.md](LICENSE.md) for details
