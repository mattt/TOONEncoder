# TOONEncoder

A Swift encoder for [TOON](https://github.com/toon-format/spec) (Token-Oriented Object Notation),
a compact format designed to reduce LLM token usage by 30–60% compared with JSON.

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

## Requirements

* Swift 6.0+ / Xcode 16+
* iOS 13.0+ / macOS 10.15+ / watchOS 6.0+ / tvOS 13.0+ / visionOS 1.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/mattt/TOONEncoder.git", from: "0.1.0")
]
```

## Usage

### Basic Encoding

```swift
import TOONEncoder

struct User: Codable {
    let id: Int
    let name: String
    let tags: [String]
    let active: Bool
}

let user = User(
    id: 123,
    name: "Ada",
    tags: ["reading", "gaming"],
    active: true
)

let encoder = TOONEncoder()
let data = try encoder.encode(user)
print(String(data: data, encoding: .utf8)!)
```

Output:
```
id: 123
name: Ada
tags[2]: reading,gaming
active: true
```

### Custom Delimiters

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

### Length Markers

Add a `#` prefix to array lengths for emphasis and readability:

```swift
let data = [
    "tags": ["reading", "gaming", "coding"],
    "items": [
        ["sku": "A1", "qty": 2, "price": 9.99],
        ["sku": "B2", "qty": 1, "price": 14.5]
    ]
]

let encoder = TOONEncoder()
encoder.lengthMarker = .hash

let output = try encoder.encode(data)
```

Output:
```
tags[#3]: reading,gaming,coding
items[#2]{sku,qty,price}:
  A1,2,9.99
  B2,1,14.5
```

### Tabular Arrays

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

### Arrays of Arrays

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

### Key Folding

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

When enabled, key folding applies only when
all path segments are valid identifiers
(start with a letter or underscore and contain only alphanumerics or underscores),
each level in the chain is a single-key object,
and the folded path does not collide with an existing sibling key
(collision avoidance).

#### Flatten Depth

To control how aggressively key folding collapses nested objects,
use `flattenDepth`:

```swift
struct Metrics: Codable {
    struct Service: Codable {
        struct CPU: Codable {
            let usage: Double
        }
        let cpu: CPU
    }
    let service: Service
}

let value = Metrics(
    service: .init(
        cpu: .init(usage: 0.73)
    )
)

let encoder = TOONEncoder()
encoder.keyFolding = .safe
let data = try encoder.encode(value)
```

Output with unlimited `flattenDepth` (default):

```
service.cpu.usage: 0.73
```

Output with deep nesting and `flattenDepth = 2`:

```swift
encoder.flattenDepth = 2
```

```
service.cpu:
  usage: 0.73
```

> [!TIP]
> Specifying a flatten depth less than 2 has no practical effect.

### Version Information

Check the supported TOON specification version:

```swift
print(TOONEncoder.specVersion) // "3.0"
```

## License

This project is available under the MIT license.
See the LICENSE file for more info.
