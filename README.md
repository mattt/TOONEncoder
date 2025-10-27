# TOONEncoder

A Swift encoder for [TOON](https://github.com/johannschopplich/toon) (Token-Oriented Object Notation),
a compact format designed to reduce LLM token usage by 30–60% compared to JSON.

LLM tokens have a cost, and JSON is verbose.
TOON saves tokens while remaining human-readable by
using indentation for structure and tabular format for uniform data:

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
see the [TOON project README](https://github.com/johannschopplich/toon).

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

Add a `#` prefix to array lengths for emphasis:

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

When you have arrays containing primitive inner arrays:

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

## License

This project is available under the MIT license.
See the LICENSE file for more info.
