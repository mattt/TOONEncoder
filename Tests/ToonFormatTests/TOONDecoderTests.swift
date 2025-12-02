import Foundation
import Testing

@testable import TOONDecoder
import TOONEncoder

@Suite("TOONDecoder Tests")
struct TOONDecoderTests {
    let decoder = TOONDecoder()
    let encoder = TOONEncoder()

    // MARK: - Primitives

    @Test func safeStrings() async throws {
        let data = "hello".data(using: .utf8)!
        let result = try decoder.decode(String.self, from: data)
        #expect(result == "hello")

        let data2 = "Ada_99".data(using: .utf8)!
        let result2 = try decoder.decode(String.self, from: data2)
        #expect(result2 == "Ada_99")
    }

    @Test func emptyString() async throws {
        let data = "\"\"".data(using: .utf8)!
        let result = try decoder.decode(String.self, from: data)
        #expect(result == "")
    }

    @Test func quotedStrings() async throws {
        let data = "\"true\"".data(using: .utf8)!
        let result = try decoder.decode(String.self, from: data)
        #expect(result == "true")

        let data2 = "\"false\"".data(using: .utf8)!
        let result2 = try decoder.decode(String.self, from: data2)
        #expect(result2 == "false")

        let data3 = "\"null\"".data(using: .utf8)!
        let result3 = try decoder.decode(String.self, from: data3)
        #expect(result3 == "null")
    }

    @Test func quotedNumberStrings() async throws {
        let data = "\"42\"".data(using: .utf8)!
        let result = try decoder.decode(String.self, from: data)
        #expect(result == "42")

        let data2 = "\"-3.14\"".data(using: .utf8)!
        let result2 = try decoder.decode(String.self, from: data2)
        #expect(result2 == "-3.14")
    }

    @Test func escapeSequences() async throws {
        let data = "\"line1\\nline2\"".data(using: .utf8)!
        let result = try decoder.decode(String.self, from: data)
        #expect(result == "line1\nline2")

        let data2 = "\"tab\\there\"".data(using: .utf8)!
        let result2 = try decoder.decode(String.self, from: data2)
        #expect(result2 == "tab\there")

        let data3 = "\"return\\rcarriage\"".data(using: .utf8)!
        let result3 = try decoder.decode(String.self, from: data3)
        #expect(result3 == "return\rcarriage")

        let data4 = "\"C:\\\\Users\\\\path\"".data(using: .utf8)!
        let result4 = try decoder.decode(String.self, from: data4)
        #expect(result4 == "C:\\Users\\path")
    }

    @Test func unicodeAndEmoji() async throws {
        let data = "café".data(using: .utf8)!
        let result = try decoder.decode(String.self, from: data)
        #expect(result == "café")

        let data2 = "你好".data(using: .utf8)!
        let result2 = try decoder.decode(String.self, from: data2)
        #expect(result2 == "你好")

        let data3 = "🚀".data(using: .utf8)!
        let result3 = try decoder.decode(String.self, from: data3)
        #expect(result3 == "🚀")
    }

    @Test func integers() async throws {
        let data = "42".data(using: .utf8)!
        let result = try decoder.decode(Int.self, from: data)
        #expect(result == 42)

        let data2 = "-7".data(using: .utf8)!
        let result2 = try decoder.decode(Int.self, from: data2)
        #expect(result2 == -7)

        let data3 = "0".data(using: .utf8)!
        let result3 = try decoder.decode(Int.self, from: data3)
        #expect(result3 == 0)
    }

    @Test func doubles() async throws {
        let data = "3.14".data(using: .utf8)!
        let result = try decoder.decode(Double.self, from: data)
        #expect(result == 3.14)
    }

    @Test func booleans() async throws {
        let data = "true".data(using: .utf8)!
        let result = try decoder.decode(Bool.self, from: data)
        #expect(result == true)

        let data2 = "false".data(using: .utf8)!
        let result2 = try decoder.decode(Bool.self, from: data2)
        #expect(result2 == false)
    }

    // MARK: - Simple Objects

    @Test func simpleObject() async throws {
        struct TestObject: Codable, Equatable {
            let id: Int
            let name: String
            let active: Bool
        }

        let toon = """
            id: 123
            name: Ada
            active: true
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(TestObject.self, from: data)

        #expect(result.id == 123)
        #expect(result.name == "Ada")
        #expect(result.active == true)
    }

    @Test func objectWithNullValue() async throws {
        struct NullTestObject: Codable, Equatable {
            let id: Int
            let value: String?
        }

        let toon = """
            id: 123
            value: null
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(NullTestObject.self, from: data)

        #expect(result.id == 123)
        #expect(result.value == nil)
    }

    @Test func emptyObject() async throws {
        struct EmptyObject: Codable, Equatable {}

        let toon = ""
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(EmptyObject.self, from: data)
        #expect(result == EmptyObject())
    }

    @Test func objectWithSpecialCharacterStrings() async throws {
        struct SpecialStringObject: Codable, Equatable {
            let note: String
        }

        let toon = "note: \"a:b\""
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(SpecialStringObject.self, from: data)
        #expect(result.note == "a:b")
    }

    // MARK: - Object Keys

    @Test func keysWithSpecialCharacters() async throws {
        struct SpecialKeyObject: Codable, Equatable {
            let orderId: Int
            let index: Int

            enum CodingKeys: String, CodingKey {
                case orderId = "order:id"
                case index = "[index]"
            }
        }

        let toon = """
            "order:id": 7
            "[index]": 5
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(SpecialKeyObject.self, from: data)

        #expect(result.orderId == 7)
        #expect(result.index == 5)
    }

    @Test func keysWithSpacesAndHyphens() async throws {
        struct SpaceKeyObject: Codable, Equatable {
            let fullName: String

            enum CodingKeys: String, CodingKey {
                case fullName = "full name"
            }
        }

        let toon = "\"full name\": Ada"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(SpaceKeyObject.self, from: data)
        #expect(result.fullName == "Ada")
    }

    // MARK: - Nested Objects

    @Test func deepNestedObjects() async throws {
        struct DeepNestedObject: Codable, Equatable {
            struct Level2: Codable, Equatable {
                struct Level3: Codable, Equatable {
                    let c: String
                }

                let b: Level3
            }

            let a: Level2
        }

        let toon = """
            a:
              b:
                c: deep
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(DeepNestedObject.self, from: data)

        #expect(result.a.b.c == "deep")
    }

    // MARK: - Primitive Arrays

    @Test func primitiveArraysInline() async throws {
        struct PrimitiveArrayObject: Codable, Equatable {
            let tags: [String]
            let nums: [Int]
        }

        let toon = """
            tags[2]: reading,gaming
            nums[3]: 1,2,3
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(PrimitiveArrayObject.self, from: data)

        #expect(result.tags == ["reading", "gaming"])
        #expect(result.nums == [1, 2, 3])
    }

    @Test func emptyArrays() async throws {
        struct EmptyArrayObject: Codable, Equatable {
            let items: [String]
        }

        let toon = "items[0]:"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(EmptyArrayObject.self, from: data)
        #expect(result.items == [])
    }

    @Test func arrayWithQuotedStrings() async throws {
        struct QuotedArrayObject: Codable, Equatable {
            let data: [String]
        }

        let toon = "data[4]: x,y,\"true\",\"10\""
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(QuotedArrayObject.self, from: data)
        #expect(result.data == ["x", "y", "true", "10"])
    }

    // MARK: - Object Arrays (Tabular Format)

    @Test func tabularFormat() async throws {
        struct TabularObject: Codable, Equatable {
            let sku: String
            let qty: Int
            let price: Double
        }

        struct TabularArrayObject: Codable, Equatable {
            let items: [TabularObject]
        }

        let toon = """
            items[2]{sku,qty,price}:
              A1,2,9.99
              B2,1,14.5
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(TabularArrayObject.self, from: data)

        #expect(result.items.count == 2)
        #expect(result.items[0].sku == "A1")
        #expect(result.items[0].qty == 2)
        #expect(result.items[0].price == 9.99)
        #expect(result.items[1].sku == "B2")
        #expect(result.items[1].qty == 1)
        #expect(result.items[1].price == 14.5)
    }

    @Test func tabularFormatWithNullValues() async throws {
        struct NullTabularObject: Codable, Equatable {
            let id: Int
            let value: String?
        }

        struct NullTabularArrayObject: Codable, Equatable {
            let items: [NullTabularObject]
        }

        let toon = """
            items[2]{id,value}:
              1,null
              2,test
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(NullTabularArrayObject.self, from: data)

        #expect(result.items[0].id == 1)
        #expect(result.items[0].value == nil)
        #expect(result.items[1].id == 2)
        #expect(result.items[1].value == "test")
    }

    // MARK: - Mixed Arrays (List Format)

    @Test func listFormatWithObjects() async throws {
        struct ListItemObject: Codable, Equatable {
            let id: Int
            let name: String
        }

        let toon = """
            [2]:
              - id: 1
                name: First
              - id: 2
                name: Second
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode([ListItemObject].self, from: data)

        #expect(result.count == 2)
        #expect(result[0].id == 1)
        #expect(result[0].name == "First")
        #expect(result[1].id == 2)
        #expect(result[1].name == "Second")
    }

    @Test func listFormatWithNestedArrays() async throws {
        struct ListItemObject: Codable, Equatable {
            let nums: [Int]
            let name: String
        }

        struct ContainerObject: Codable, Equatable {
            let items: [ListItemObject]
        }

        let toon = """
            items[1]:
              - nums[3]: 1,2,3
                name: test
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(ContainerObject.self, from: data)

        #expect(result.items.count == 1)
        #expect(result.items[0].nums == [1, 2, 3])
        #expect(result.items[0].name == "test")
    }

    // MARK: - Arrays of Arrays

    @Test func arrayOfArrays() async throws {
        struct ArrayOfArraysObject: Codable, Equatable {
            let pairs: [[String]]
        }

        let toon = """
            pairs[2]:
              - [2]: a,b
              - [2]: c,d
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(ArrayOfArraysObject.self, from: data)

        #expect(result.pairs.count == 2)
        #expect(result.pairs[0] == ["a", "b"])
        #expect(result.pairs[1] == ["c", "d"])
    }

    // MARK: - Root Arrays

    @Test func rootPrimitiveArray() async throws {
        let toon = "[4]: x,y,\"true\",\"10\""
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode([String].self, from: data)
        #expect(result == ["x", "y", "true", "10"])
    }

    @Test func rootObjectArray() async throws {
        struct SimpleObject: Codable, Equatable {
            let id: Int
        }

        let toon = """
            [2]{id}:
              1
              2
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode([SimpleObject].self, from: data)

        #expect(result.count == 2)
        #expect(result[0].id == 1)
        #expect(result[1].id == 2)
    }

    @Test func rootEmptyArray() async throws {
        let toon = "[0]:"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode([String].self, from: data)
        #expect(result == [])
    }

    // MARK: - Complex Structures

    @Test func complexStructure() async throws {
        struct ComplexObject: Codable, Equatable {
            struct User: Codable, Equatable {
                let id: Int
                let name: String
                let tags: [String]
                let active: Bool
                let prefs: [String]
            }

            let user: User
        }

        let toon = """
            user:
              id: 123
              name: Ada
              tags[2]: reading,gaming
              active: true
              prefs[0]:
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(ComplexObject.self, from: data)

        #expect(result.user.id == 123)
        #expect(result.user.name == "Ada")
        #expect(result.user.tags == ["reading", "gaming"])
        #expect(result.user.active == true)
        #expect(result.user.prefs == [])
    }

    // MARK: - Delimiter Options

    @Test func tabDelimiter() async throws {
        struct DelimiterTestObject: Codable, Equatable {
            let tags: [String]
        }

        let toon = "tags[3\t]: reading\tgaming\tcoding"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(DelimiterTestObject.self, from: data)
        #expect(result.tags == ["reading", "gaming", "coding"])
    }

    @Test func pipeDelimiter() async throws {
        struct DelimiterTestObject: Codable, Equatable {
            let tags: [String]
        }

        let toon = "tags[3|]: reading|gaming|coding"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(DelimiterTestObject.self, from: data)
        #expect(result.tags == ["reading", "gaming", "coding"])
    }

    @Test func tabularArraysWithPipeDelimiter() async throws {
        struct TabularDelimiterObject: Codable, Equatable {
            let sku: String
            let qty: Int
            let price: Double
        }

        struct TabularDelimiterArrayObject: Codable, Equatable {
            let items: [TabularDelimiterObject]
        }

        let toon = """
            items[2|]{sku|qty|price}:
              A1|2|9.99
              B2|1|14.5
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(TabularDelimiterArrayObject.self, from: data)

        #expect(result.items.count == 2)
        #expect(result.items[0].sku == "A1")
        #expect(result.items[0].qty == 2)
        #expect(result.items[0].price == 9.99)
    }

    // MARK: - Length Marker Option

    @Test func lengthMarkerHash() async throws {
        struct LengthMarkerTestObject: Codable, Equatable {
            let tags: [String]
        }

        let toon = "tags[#3]: reading,gaming,coding"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(LengthMarkerTestObject.self, from: data)
        #expect(result.tags == ["reading", "gaming", "coding"])
    }

    // MARK: - Non-JSON Types

    @Test func dateConversion() async throws {
        struct DateObject: Codable, Equatable {
            let created: Date
        }

        let toon = "created: \"1970-01-01T00:00:00.000Z\""
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(DateObject.self, from: data)

        #expect(result.created == Date(timeIntervalSince1970: 0))
    }

    @Test func urlConversion() async throws {
        struct URLObject: Codable, Equatable {
            let url: URL
        }

        let toon = "url: \"https://example.com\""
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(URLObject.self, from: data)

        #expect(result.url == URL(string: "https://example.com")!)
    }

    @Test func dataConversion() async throws {
        struct DataObject: Codable, Equatable {
            let data: Data
        }

        let toon = "data: aGVsbG8="
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(DataObject.self, from: data)

        #expect(result.data == "hello".data(using: .utf8)!)
    }

    // MARK: - Path Expansion

    @Test func pathExpansionDisabled() async throws {
        struct DottedKeyObject: Codable, Equatable {
            let key: String

            enum CodingKeys: String, CodingKey {
                case key = "user.profile.name"
            }
        }

        let decoder = TOONDecoder()
        decoder.expandPaths = .disabled

        let toon = "user.profile.name: Ada"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(DottedKeyObject.self, from: data)
        #expect(result.key == "Ada")
    }

    @Test func pathExpansionSafe() async throws {
        struct NestedObject: Codable, Equatable {
            struct User: Codable, Equatable {
                struct Profile: Codable, Equatable {
                    let name: String
                }

                let profile: Profile
            }

            let user: User
        }

        let decoder = TOONDecoder()
        decoder.expandPaths = .safe

        let toon = "user.profile.name: Ada"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(NestedObject.self, from: data)
        #expect(result.user.profile.name == "Ada")
    }

    // MARK: - Specification Compliance

    @Test func versionDeclaration() async throws {
        #expect(TOONDecoder.specVersion == "3.0")
    }

    // MARK: - Round-Trip Tests

    @Test func roundTripSimpleObject() async throws {
        struct TestObject: Codable, Equatable {
            let id: Int
            let name: String
            let active: Bool
        }

        let original = TestObject(id: 123, name: "Ada", active: true)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(TestObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripTabularArray() async throws {
        struct Item: Codable, Equatable {
            let sku: String
            let qty: Int
            let price: Double
        }

        struct Container: Codable, Equatable {
            let items: [Item]
        }

        let original = Container(items: [
            Item(sku: "A1", qty: 2, price: 9.99),
            Item(sku: "B2", qty: 1, price: 14.5),
        ])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(Container.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripNestedObjects() async throws {
        struct DeepNestedObject: Codable, Equatable {
            struct Level2: Codable, Equatable {
                struct Level3: Codable, Equatable {
                    let c: String
                }

                let b: Level3
            }

            let a: Level2
        }

        let original = DeepNestedObject(
            a: DeepNestedObject.Level2(b: DeepNestedObject.Level2.Level3(c: "deep"))
        )
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DeepNestedObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripPrimitiveArrays() async throws {
        struct ArrayObject: Codable, Equatable {
            let tags: [String]
            let nums: [Int]
        }

        let original = ArrayObject(tags: ["reading", "gaming"], nums: [1, 2, 3])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ArrayObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripComplexStructure() async throws {
        struct ComplexObject: Codable, Equatable {
            struct User: Codable, Equatable {
                let id: Int
                let name: String
                let tags: [String]
                let active: Bool
            }

            let user: User
        }

        let original = ComplexObject(
            user: ComplexObject.User(
                id: 123,
                name: "Ada",
                tags: ["reading", "gaming"],
                active: true
            )
        )
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ComplexObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripDate() async throws {
        struct DateObject: Codable, Equatable {
            let created: Date
        }

        let original = DateObject(created: Date(timeIntervalSince1970: 0))
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DateObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripURL() async throws {
        struct URLObject: Codable, Equatable {
            let url: URL
        }

        let original = URLObject(url: URL(string: "https://example.com")!)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(URLObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripData() async throws {
        struct DataObject: Codable, Equatable {
            let data: Data
        }

        let original = DataObject(data: "hello".data(using: .utf8)!)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DataObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripEmptyArray() async throws {
        struct EmptyArrayObject: Codable, Equatable {
            let items: [String]
        }

        let original = EmptyArrayObject(items: [])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(EmptyArrayObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripQuotedStrings() async throws {
        struct QuotedObject: Codable, Equatable {
            let note: String
        }

        let original = QuotedObject(note: "a:b,c")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(QuotedObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripEscapeSequences() async throws {
        struct EscapeObject: Codable, Equatable {
            let text: String
        }

        let original = EscapeObject(text: "line1\nline2\ttab")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(EscapeObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripNullValues() async throws {
        struct NullObject: Codable, Equatable {
            let id: Int
            let value: String?
        }

        let original = NullObject(id: 1, value: nil)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(NullObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripTabDelimiter() async throws {
        struct DelimiterObject: Codable, Equatable {
            let tags: [String]
        }

        let encoder = TOONEncoder()
        encoder.delimiter = .tab

        let original = DelimiterObject(tags: ["reading", "gaming", "coding"])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DelimiterObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripPipeDelimiter() async throws {
        struct DelimiterObject: Codable, Equatable {
            let tags: [String]
        }

        let encoder = TOONEncoder()
        encoder.delimiter = .pipe

        let original = DelimiterObject(tags: ["reading", "gaming", "coding"])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(DelimiterObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripLengthMarker() async throws {
        struct LengthMarkerObject: Codable, Equatable {
            let tags: [String]
        }

        let encoder = TOONEncoder()
        encoder.lengthMarker = .hash

        let original = LengthMarkerObject(tags: ["reading", "gaming", "coding"])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(LengthMarkerObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripKeyFolding() async throws {
        struct NestedObject: Codable, Equatable {
            struct User: Codable, Equatable {
                struct Profile: Codable, Equatable {
                    let name: String
                }

                let profile: Profile
            }

            let user: User
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let decoder = TOONDecoder()
        decoder.expandPaths = .safe

        let original = NestedObject(user: .init(profile: .init(name: "Ada")))
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(NestedObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripArrayOfArrays() async throws {
        struct ArrayOfArraysObject: Codable, Equatable {
            let pairs: [[String]]
        }

        let original = ArrayOfArraysObject(pairs: [["a", "b"], ["c", "d"]])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ArrayOfArraysObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripUnicodeStrings() async throws {
        struct UnicodeObject: Codable, Equatable {
            let text: String
        }

        let original = UnicodeObject(text: "café 你好 🚀")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(UnicodeObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripSpecialKeyNames() async throws {
        struct SpecialKeyObject: Codable, Equatable {
            let orderId: Int
            let fullName: String

            enum CodingKeys: String, CodingKey {
                case orderId = "order:id"
                case fullName = "full name"
            }
        }

        let original = SpecialKeyObject(orderId: 7, fullName: "Ada")
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(SpecialKeyObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripMixedArrayFormats() async throws {
        struct MixedObject: Codable, Equatable {
            let id: Int
            let nested: [String: String]
        }

        struct MixedArrayObject: Codable, Equatable {
            let items: [MixedObject]
        }

        let original = MixedArrayObject(items: [
            MixedObject(id: 1, nested: ["x": "1"])
        ])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(MixedArrayObject.self, from: encoded)
        #expect(original == decoded)
    }

    // MARK: - Error Cases

    @Test func invalidEscapeSequence() async throws {
        let toon = "\"invalid\\x\""
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(String.self, from: data)
        }
    }

    @Test func countMismatch() async throws {
        struct ArrayObject: Codable {
            let items: [String]
        }

        let toon = "items[3]: a,b"  // Declares 3, but only 2 values
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(ArrayObject.self, from: data)
        }
    }

    @Test func fieldCountMismatch() async throws {
        struct TabularObject: Codable {
            let a: String
            let b: Int
        }

        struct Container: Codable {
            let items: [TabularObject]
        }

        let toon = """
            items[1]{a,b}:
              only_one_value
            """
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(Container.self, from: data)
        }
    }

    @Test func typeMismatch() async throws {
        struct IntObject: Codable {
            let value: Int
        }

        let toon = "value: not_a_number"
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(IntObject.self, from: data)
        }
    }

    @Test func keyNotFound() async throws {
        struct RequiredKeyObject: Codable {
            let required: String
        }

        let toon = "other: value"
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(RequiredKeyObject.self, from: data)
        }
    }

    // MARK: - Integer Overflow Protection

    @Test func integerOverflowInt8() async throws {
        struct Int8Object: Codable {
            let value: Int8
        }

        let toon = "value: 200"  // Exceeds Int8.max (127)
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(Int8Object.self, from: data)
        }
    }

    @Test func integerOverflowUInt8() async throws {
        struct UInt8Object: Codable {
            let value: UInt8
        }

        let toon = "value: -1"  // Negative value for unsigned
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(UInt8Object.self, from: data)
        }
    }

    @Test func integerOverflowUInt8TooLarge() async throws {
        struct UInt8Object: Codable {
            let value: UInt8
        }

        let toon = "value: 300"  // Exceeds UInt8.max (255)
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(UInt8Object.self, from: data)
        }
    }

    // MARK: - Decoding Limits

    @Test func inputSizeLimit() async throws {
        let decoder = TOONDecoder()
        decoder.limits = TOONDecoder.DecodingLimits(
            maxInputSize: 10,
            maxDepth: 128,
            maxObjectKeys: 10000,
            maxArrayLength: 100_000
        )

        let toon = "this is a long string that exceeds the limit"
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(String.self, from: data)
        }
    }

    @Test func arrayLengthLimit() async throws {
        let decoder = TOONDecoder()
        decoder.limits = TOONDecoder.DecodingLimits(
            maxInputSize: 10 * 1024 * 1024,
            maxDepth: 128,
            maxObjectKeys: 10000,
            maxArrayLength: 2
        )

        struct ArrayObject: Codable {
            let items: [String]
        }

        let toon = "items[5]: a,b,c,d,e"  // 5 items exceeds limit of 2
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(ArrayObject.self, from: data)
        }
    }

    @Test func unlimitedLimitsWork() async throws {
        let decoder = TOONDecoder()
        decoder.limits = .unlimited

        struct TestObject: Codable, Equatable {
            let name: String
        }

        let toon = "name: Ada"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(TestObject.self, from: data)
        #expect(result.name == "Ada")
    }
}
