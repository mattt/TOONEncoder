import Foundation
import Testing

@testable import TOONEncoder

@Suite("TOONEncoder Tests")
struct TOONEncoderTests {
    let encoder = TOONEncoder()

    // MARK: - Primitives

    @Test func safeStrings() async throws {
        #expect(String(data: try encoder.encode("hello"), encoding: .utf8) == "hello")
        #expect(String(data: try encoder.encode("Ada_99"), encoding: .utf8) == "Ada_99")
    }

    @Test func emptyString() async throws {
        #expect(String(data: try encoder.encode(""), encoding: .utf8) == "\"\"")
    }

    @Test func stringsThatLookLikeBooleans() async throws {
        #expect(String(data: try encoder.encode("true"), encoding: .utf8) == "\"true\"")
        #expect(String(data: try encoder.encode("false"), encoding: .utf8) == "\"false\"")
        #expect(String(data: try encoder.encode("null"), encoding: .utf8) == "\"null\"")
    }

    @Test func stringsThatLookLikeNumbers() async throws {
        #expect(String(data: try encoder.encode("42"), encoding: .utf8) == "\"42\"")
        #expect(String(data: try encoder.encode("-3.14"), encoding: .utf8) == "\"-3.14\"")
        #expect(String(data: try encoder.encode("1e-6"), encoding: .utf8) == "\"1e-6\"")
        #expect(String(data: try encoder.encode("05"), encoding: .utf8) == "\"05\"")
    }

    @Test func controlCharacters() async throws {
        #expect(
            String(data: try encoder.encode("line1\nline2"), encoding: .utf8) == "\"line1\\nline2\""
        )
        #expect(String(data: try encoder.encode("tab\there"), encoding: .utf8) == "\"tab\\there\"")
        #expect(
            String(data: try encoder.encode("return\rcarriage"), encoding: .utf8)
                == "\"return\\rcarriage\""
        )
        #expect(
            String(data: try encoder.encode("C:\\Users\\path"), encoding: .utf8)
                == "\"C:\\\\Users\\\\path\""
        )
    }

    @Test func structuralCharacters() async throws {
        #expect(String(data: try encoder.encode("[3]: x,y"), encoding: .utf8) == "\"[3]: x,y\"")
        #expect(String(data: try encoder.encode("- item"), encoding: .utf8) == "\"- item\"")
        #expect(String(data: try encoder.encode("[test]"), encoding: .utf8) == "\"[test]\"")
        #expect(String(data: try encoder.encode("{key}"), encoding: .utf8) == "\"{key}\"")
    }

    @Test func unicodeAndEmoji() async throws {
        #expect(String(data: try encoder.encode("café"), encoding: .utf8) == "café")
        #expect(String(data: try encoder.encode("你好"), encoding: .utf8) == "你好")
        #expect(String(data: try encoder.encode("🚀"), encoding: .utf8) == "🚀")
        #expect(String(data: try encoder.encode("hello 👋 world"), encoding: .utf8) == "hello 👋 world")
    }

    @Test func numbers() async throws {
        #expect(String(data: try encoder.encode(42), encoding: .utf8) == "42")
        #expect(String(data: try encoder.encode(3.14), encoding: .utf8) == "3.14")
        #expect(String(data: try encoder.encode(-7), encoding: .utf8) == "-7")
        #expect(String(data: try encoder.encode(0), encoding: .utf8) == "0")
    }

    @Test func specialNumericValues() async throws {
        #expect(String(data: try encoder.encode(-0.0), encoding: .utf8) == "0")
        #expect(String(data: try encoder.encode(1e6), encoding: .utf8) == "1000000")
        #expect(String(data: try encoder.encode(1e-6), encoding: .utf8) == "0.000001")
        #expect(String(data: try encoder.encode(1e20), encoding: .utf8) == "100000000000000000000")
        #expect(String(data: try encoder.encode(Int64.max), encoding: .utf8) == "9223372036854775807")
    }

    @Test func booleans() async throws {
        #expect(String(data: try encoder.encode(true), encoding: .utf8) == "true")
        #expect(String(data: try encoder.encode(false), encoding: .utf8) == "false")
    }

    @Test func nullValues() async throws {
        struct NullTest: Codable {
            let value: String?
        }
        let nullTest = NullTest(value: nil)
        let nullResult = String(data: try encoder.encode(nullTest), encoding: .utf8)!
        #expect(nullResult.contains("value: null"))
    }

    // MARK: - Simple Objects

    @Test func simpleObject() async throws {
        struct TestObject: Codable {
            let id: Int
            let name: String
            let active: Bool
        }

        let obj = TestObject(id: 123, name: "Ada", active: true)
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        #expect(result.contains("id: 123"))
        #expect(result.contains("name: Ada"))
        #expect(result.contains("active: true"))
    }

    @Test func objectWithNullValue() async throws {
        struct NullTestObject: Codable {
            let id: Int
            let value: String?
        }

        let nullObj = NullTestObject(id: 123, value: nil)
        let nullResult = String(data: try encoder.encode(nullObj), encoding: .utf8)!
        #expect(nullResult.contains("id: 123"))
        #expect(nullResult.contains("value: null"))
    }

    @Test func emptyObject() async throws {
        struct EmptyObject: Codable {}
        let emptyResult = String(data: try encoder.encode(EmptyObject()), encoding: .utf8)!
        #expect(emptyResult.isEmpty)
    }

    @Test func objectWithSpecialCharacterStrings() async throws {
        struct SpecialStringObject: Codable {
            let note: String
        }

        let specialObj = SpecialStringObject(note: "a:b")
        let specialResult = String(data: try encoder.encode(specialObj), encoding: .utf8)!
        #expect(specialResult.contains("note: \"a:b\""))

        let commaObj = SpecialStringObject(note: "a,b")
        let commaResult = String(data: try encoder.encode(commaObj), encoding: .utf8)!
        #expect(commaResult.contains("note: \"a,b\""))

        let newlineObj = SpecialStringObject(note: "line1\nline2")
        let newlineResult = String(data: try encoder.encode(newlineObj), encoding: .utf8)!
        #expect(newlineResult.contains("note: \"line1\\nline2\""))

        let quoteObj = SpecialStringObject(note: "say \"hello\"")
        let quoteResult = String(data: try encoder.encode(quoteObj), encoding: .utf8)!
        #expect(quoteResult.contains("note: \"say \\\"hello\\\"\""))
    }

    @Test func objectWithPaddedStrings() async throws {
        struct SpecialStringObject: Codable {
            let note: String
        }

        let paddedObj = SpecialStringObject(note: " padded ")
        let paddedResult = String(data: try encoder.encode(paddedObj), encoding: .utf8)!
        #expect(paddedResult.contains("note: \" padded \""))

        let spacesObj = SpecialStringObject(note: "  ")
        let spacesResult = String(data: try encoder.encode(spacesObj), encoding: .utf8)!
        #expect(spacesResult.contains("note: \"  \""))
    }

    @Test func objectWithAmbiguousStrings() async throws {
        struct AmbiguousStringObject: Codable {
            let v: String
        }

        let trueObj = AmbiguousStringObject(v: "true")
        let trueResult = String(data: try encoder.encode(trueObj), encoding: .utf8)!
        #expect(trueResult.contains("v: \"true\""))

        let numObj = AmbiguousStringObject(v: "42")
        let numResult = String(data: try encoder.encode(numObj), encoding: .utf8)!
        #expect(numResult.contains("v: \"42\""))

        let negObj = AmbiguousStringObject(v: "-7.5")
        let negResult = String(data: try encoder.encode(negObj), encoding: .utf8)!
        #expect(negResult.contains("v: \"-7.5\""))
    }

    // MARK: - Object Keys

    @Test func keysWithSpecialCharacters() async throws {
        struct SpecialKeyObject: Codable {
            let orderId: Int
            let index: Int
            let key: Int
            let comma: Int

            enum CodingKeys: String, CodingKey {
                case orderId = "order:id"
                case index = "[index]"
                case key = "{key}"
                case comma = "a,b"
            }
        }

        let specialKeyObj = SpecialKeyObject(orderId: 7, index: 5, key: 5, comma: 1)
        let result = String(data: try encoder.encode(specialKeyObj), encoding: .utf8)!

        #expect(result.contains("\"order:id\": 7"))
        #expect(result.contains("\"[index]\": 5"))
        #expect(result.contains("\"{key}\": 5"))
        #expect(result.contains("\"a,b\": 1"))
    }

    @Test func keysWithSpacesAndHyphens() async throws {
        struct SpaceKeyObject: Codable {
            let fullName: String
            let lead: Int
            let spaces: Int

            enum CodingKeys: String, CodingKey {
                case fullName = "full name"
                case lead = "-lead"
                case spaces = " a "
            }
        }

        let spaceKeyObj = SpaceKeyObject(fullName: "Ada", lead: 1, spaces: 1)
        let spaceResult = String(data: try encoder.encode(spaceKeyObj), encoding: .utf8)!

        #expect(spaceResult.contains("\"full name\": Ada"))
        #expect(spaceResult.contains("\"-lead\": 1"))
        #expect(spaceResult.contains("\" a \": 1"))
    }

    @Test func numericKeys() async throws {
        struct NumericKeyObject: Codable {
            let key123: String

            enum CodingKeys: String, CodingKey {
                case key123 = "123"
            }
        }

        let numericKeyObj = NumericKeyObject(key123: "x")
        let numericResult = String(data: try encoder.encode(numericKeyObj), encoding: .utf8)!
        #expect(numericResult.contains("\"123\": x"))
    }

    @Test func emptyStringKey() async throws {
        struct EmptyKeyObject: Codable {
            let empty: Int

            enum CodingKeys: String, CodingKey {
                case empty = ""
            }
        }

        let emptyKeyObj = EmptyKeyObject(empty: 1)
        let emptyKeyResult = String(data: try encoder.encode(emptyKeyObj), encoding: .utf8)!
        #expect(emptyKeyResult.contains("\"\": 1"))
    }

    @Test func controlCharactersInKeys() async throws {
        struct ControlKeyObject: Codable {
            let lineBreak: Int
            let tabHere: Int

            enum CodingKeys: String, CodingKey {
                case lineBreak = "line\nbreak"
                case tabHere = "tab\there"
            }
        }

        let controlKeyObj = ControlKeyObject(lineBreak: 1, tabHere: 2)
        let controlResult = String(data: try encoder.encode(controlKeyObj), encoding: .utf8)!
        #expect(controlResult.contains("\"line\\nbreak\": 1"))
        #expect(controlResult.contains("\"tab\\there\": 2"))
    }

    @Test func quotesInKeys() async throws {
        struct QuoteKeyObject: Codable {
            let quoted: Int

            enum CodingKeys: String, CodingKey {
                case quoted = "he said \"hi\""
            }
        }

        let quoteKeyObj = QuoteKeyObject(quoted: 1)
        let quoteKeyResult = String(data: try encoder.encode(quoteKeyObj), encoding: .utf8)!
        #expect(quoteKeyResult.contains("\"he said \\\"hi\\\"\": 1"))
    }

    // MARK: - Nested Objects

    @Test func deepNestedObjects() async throws {
        struct DeepNestedObject: Codable {
            struct Level2: Codable {
                struct Level3: Codable {
                    let c: String
                }
                let b: Level3
            }
            let a: Level2
        }

        let deepObj = DeepNestedObject(
            a: DeepNestedObject.Level2(b: DeepNestedObject.Level2.Level3(c: "deep"))
        )
        let result = String(data: try encoder.encode(deepObj), encoding: .utf8)!

        #expect(result.contains("a:"))
        #expect(result.contains("  b:"))
        #expect(result.contains("    c: deep"))
    }

    @Test func emptyNestedObject() async throws {
        struct EmptyNestedObject: Codable {
            let user: [String: String]
        }

        let emptyNestedObj = EmptyNestedObject(user: [:])
        let emptyNestedResult = String(data: try encoder.encode(emptyNestedObj), encoding: .utf8)!
        #expect(emptyNestedResult.contains("user:"))
    }

    // MARK: - Primitive Arrays

    @Test func primitiveArrays() async throws {
        struct PrimitiveArrayObject: Codable {
            let tags: [String]
            let nums: [Int]
            let data: [String]
        }

        let obj = PrimitiveArrayObject(
            tags: ["reading", "gaming"],
            nums: [1, 2, 3],
            data: ["x", "y", "true", "10"]
        )
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        #expect(result.contains("tags[2]: reading,gaming"))
        #expect(result.contains("nums[3]: 1,2,3"))
        #expect(result.contains("data[4]: x,y,\"true\",\"10\""))
    }

    @Test func emptyArrays() async throws {
        struct EmptyArrayObject: Codable {
            let items: [String]
        }

        let emptyObj = EmptyArrayObject(items: [])
        let emptyResult = String(data: try encoder.encode(emptyObj), encoding: .utf8)!
        #expect(emptyResult.contains("items[0]:"))
    }

    @Test func emptyStringInArrays() async throws {
        struct EmptyArrayObject: Codable {
            let items: [String]
        }

        let emptyStringObj = EmptyArrayObject(items: [""])
        let emptyStringResult = String(data: try encoder.encode(emptyStringObj), encoding: .utf8)!
        #expect(emptyStringResult.contains("items[1]: \"\""))

        let mixedEmptyObj = EmptyArrayObject(items: ["a", "", "b"])
        let mixedEmptyResult = String(data: try encoder.encode(mixedEmptyObj), encoding: .utf8)!
        #expect(mixedEmptyResult.contains("items[3]: a,\"\",b"))
    }

    @Test func whitespaceOnlyStringsInArrays() async throws {
        struct WhitespaceArrayObject: Codable {
            let items: [String]
        }

        let whitespaceObj = WhitespaceArrayObject(items: [" ", "  "])
        let whitespaceResult = String(data: try encoder.encode(whitespaceObj), encoding: .utf8)!
        #expect(whitespaceResult.contains("items[2]: \" \",\"  \""))
    }

    @Test func arraysWithSpecialCharacterStrings() async throws {
        struct SpecialArrayObject: Codable {
            let items: [String]
        }

        let specialObj = SpecialArrayObject(items: ["a", "b,c", "d:e"])
        let specialResult = String(data: try encoder.encode(specialObj), encoding: .utf8)!
        #expect(specialResult.contains("items[3]: a,\"b,c\",\"d:e\""))
    }

    @Test func arraysWithAmbiguousStrings() async throws {
        struct SpecialArrayObject: Codable {
            let items: [String]
        }

        let ambiguousObj = SpecialArrayObject(items: ["x", "true", "42", "-3.14"])
        let ambiguousResult = String(data: try encoder.encode(ambiguousObj), encoding: .utf8)!
        #expect(ambiguousResult.contains("items[4]: x,\"true\",\"42\",\"-3.14\""))
    }

    @Test func arraysWithStructuralStrings() async throws {
        struct SpecialArrayObject: Codable {
            let items: [String]
        }

        let structuralObj = SpecialArrayObject(items: ["[5]", "- item", "{key}"])
        let structuralResult = String(data: try encoder.encode(structuralObj), encoding: .utf8)!
        #expect(structuralResult.contains("items[3]: \"[5]\",\"- item\",\"{key}\""))
    }

    // MARK: - Object Arrays

    @Test func tabularFormat() async throws {
        struct TabularObject: Codable {
            let sku: String
            let qty: Int
            let price: Double
        }

        struct TabularArrayObject: Codable {
            let items: [TabularObject]
        }

        let tabularObj = TabularArrayObject(items: [
            TabularObject(sku: "A1", qty: 2, price: 9.99),
            TabularObject(sku: "B2", qty: 1, price: 14.5),
        ])
        let tabularResult = String(data: try encoder.encode(tabularObj), encoding: .utf8)!

        #expect(tabularResult.contains("items[2]{sku,qty,price}:"))
        #expect(tabularResult.contains("  A1,2,9.99"))
        #expect(tabularResult.contains("  B2,1,14.5"))
    }

    @Test func tabularFormatWithNullValues() async throws {
        struct NullTabularObject: Codable {
            let id: Int
            let value: String?
        }

        struct NullTabularArrayObject: Codable {
            let items: [NullTabularObject]
        }

        let nullTabularObj = NullTabularArrayObject(items: [
            NullTabularObject(id: 1, value: nil),
            NullTabularObject(id: 2, value: "test"),
        ])
        let nullTabularResult = String(data: try encoder.encode(nullTabularObj), encoding: .utf8)!
        #expect(nullTabularResult.contains("items[2]{id,value}:"))
        #expect(nullTabularResult.contains("  1,null"))
        #expect(nullTabularResult.contains("  2,test"))
    }

    @Test func tabularFormatWithDelimiters() async throws {
        struct DelimiterTabularObject: Codable {
            let sku: String
            let desc: String
            let qty: Int
        }

        struct DelimiterTabularArrayObject: Codable {
            let items: [DelimiterTabularObject]
        }

        let delimiterObj = DelimiterTabularArrayObject(items: [
            DelimiterTabularObject(sku: "A,1", desc: "cool", qty: 2),
            DelimiterTabularObject(sku: "B2", desc: "wip: test", qty: 1),
        ])
        let delimiterResult = String(data: try encoder.encode(delimiterObj), encoding: .utf8)!
        #expect(delimiterResult.contains("items[2]{sku,desc,qty}:"))
        #expect(delimiterResult.contains("  \"A,1\",cool,2"))
        #expect(delimiterResult.contains("  B2,\"wip: test\",1"))
    }

    @Test func tabularFormatWithAmbiguousStrings() async throws {
        struct AmbiguousTabularObject: Codable {
            let id: Int
            let status: String
        }

        struct AmbiguousTabularArrayObject: Codable {
            let items: [AmbiguousTabularObject]
        }

        let ambiguousTabularObj = AmbiguousTabularArrayObject(items: [
            AmbiguousTabularObject(id: 1, status: "true"),
            AmbiguousTabularObject(id: 2, status: "false"),
        ])
        let ambiguousTabularResult = String(
            data: try encoder.encode(ambiguousTabularObj),
            encoding: .utf8
        )!
        #expect(ambiguousTabularResult.contains("items[2]{id,status}:"))
        #expect(ambiguousTabularResult.contains("  1,\"true\""))
        #expect(ambiguousTabularResult.contains("  2,\"false\""))
    }

    @Test func tabularFormatWithQuotedKeys() async throws {
        struct QuotedKeyTabularObject: Codable {
            let orderId: Int
            let fullName: String

            enum CodingKeys: String, CodingKey {
                case orderId = "order:id"
                case fullName = "full name"
            }
        }

        struct QuotedKeyTabularArrayObject: Codable {
            let items: [QuotedKeyTabularObject]
        }

        let quotedKeyObj = QuotedKeyTabularArrayObject(items: [
            QuotedKeyTabularObject(orderId: 1, fullName: "Ada"),
            QuotedKeyTabularObject(orderId: 2, fullName: "Bob"),
        ])
        let quotedKeyResult = String(data: try encoder.encode(quotedKeyObj), encoding: .utf8)!
        #expect(quotedKeyResult.contains("items[2]{\"order:id\",\"full name\"}:"))
        #expect(quotedKeyResult.contains("  1,Ada"))
        #expect(quotedKeyResult.contains("  2,Bob"))
    }

    @Test func tabularFieldOrderFromFirstObject() async throws {
        struct OrderedObject: Codable {
            let a: Int
            let b: Int
            let c: Int
        }

        struct OrderedArrayObject: Codable {
            let items: [OrderedObject]
        }

        let orderedObj = OrderedArrayObject(items: [
            OrderedObject(a: 1, b: 2, c: 3),
            OrderedObject(a: 10, b: 20, c: 30),
        ])
        let orderedResult = String(data: try encoder.encode(orderedObj), encoding: .utf8)!
        #expect(orderedResult.contains("items[2]{a,b,c}:"))
        #expect(orderedResult.contains("  1,2,3"))
        #expect(orderedResult.contains("  10,20,30"))
    }

    // MARK: - Mixed Arrays

    @Test func objectsWithOptionalFields() async throws {
        struct OptionalFieldObject: Codable {
            let id: Int
            let name: String
            let extra: Bool?
        }

        struct OptionalFieldArrayObject: Codable {
            let items: [OptionalFieldObject]
        }

        let optionalObj = OptionalFieldArrayObject(items: [
            OptionalFieldObject(id: 1, name: "First", extra: nil),
            OptionalFieldObject(id: 2, name: "Second", extra: true),
        ])
        let optionalResult = String(data: try encoder.encode(optionalObj), encoding: .utf8)!

        #expect(optionalResult.contains("items[2]{id,name,extra}:"))
        #expect(optionalResult.contains("  1,First,null"))
        #expect(optionalResult.contains("  2,Second,true"))
    }

    @Test func objectsWithNestedValues() async throws {
        struct NestedValueObject: Codable {
            let id: Int
            let nested: [String: String]
        }

        struct NestedValueArrayObject: Codable {
            let items: [NestedValueObject]
        }

        let nestedObj = NestedValueArrayObject(items: [
            NestedValueObject(id: 1, nested: ["x": "1"])
        ])
        let nestedResult = String(data: try encoder.encode(nestedObj), encoding: .utf8)!

        #expect(nestedResult.contains("items[1]:"))
        #expect(nestedResult.contains("  - id: 1"))
        #expect(nestedResult.contains("    nested:"))
        #expect(nestedResult.contains("      x: \"1\""))
    }

    @Test func listFormatForDifferentFields() async throws {
        struct DifferentFieldObject1: Codable {
            let id: Int
            let name: String
        }

        struct DifferentFieldObject2: Codable {
            let id: Int
            let name: String
            let extra: Bool
        }

        // Swift cannot easily encode heterogeneous arrays, so we test the list format separately
        // Testing that objects with different field sets would use list format
        let obj1 = DifferentFieldObject1(id: 1, name: "First")
        let obj2 = DifferentFieldObject2(id: 2, name: "Second", extra: true)

        let result1 = String(data: try encoder.encode(obj1), encoding: .utf8)!
        #expect(result1.contains("id: 1"))
        #expect(result1.contains("name: First"))

        let result2 = String(data: try encoder.encode(obj2), encoding: .utf8)!
        #expect(result2.contains("id: 2"))
        #expect(result2.contains("name: Second"))
        #expect(result2.contains("extra: true"))
    }

    @Test func preserveFieldOrderInListItems() async throws {
        struct ListItemObject: Codable {
            let nums: [Int]
            let name: String
        }

        struct ListItemArrayObject: Codable {
            let items: [ListItemObject]
        }

        let listItemObj = ListItemArrayObject(items: [
            ListItemObject(nums: [1, 2, 3], name: "test")
        ])
        let listItemResult = String(data: try encoder.encode(listItemObj), encoding: .utf8)!
        #expect(listItemResult.contains("items[1]:"))
        #expect(listItemResult.contains("  - nums[3]: 1,2,3"))
        #expect(listItemResult.contains("    name: test"))
    }

    @Test func preserveFieldOrderWhenPrimitiveFirst() async throws {
        struct PrimitiveFirstObject: Codable {
            let name: String
            let nums: [Int]
        }

        struct PrimitiveFirstArrayObject: Codable {
            let items: [PrimitiveFirstObject]
        }

        let primitiveFirstObj = PrimitiveFirstArrayObject(items: [
            PrimitiveFirstObject(name: "test", nums: [1, 2, 3])
        ])
        let primitiveFirstResult = String(data: try encoder.encode(primitiveFirstObj), encoding: .utf8)!
        #expect(primitiveFirstResult.contains("items[1]:"))
        #expect(primitiveFirstResult.contains("  - name: test"))
        #expect(primitiveFirstResult.contains("    nums[3]: 1,2,3"))
    }

    @Test func listFormatWithMultipleArrayFields() async throws {
        struct MultipleArrayFieldsObject: Codable {
            let nums: [Int]
            let tags: [String]
            let name: String
        }

        struct MultipleArrayFieldsArrayObject: Codable {
            let items: [MultipleArrayFieldsObject]
        }

        let multipleArrayFieldsObj = MultipleArrayFieldsArrayObject(items: [
            MultipleArrayFieldsObject(nums: [1, 2], tags: ["a", "b"], name: "test")
        ])
        let multipleArrayFieldsResult = String(
            data: try encoder.encode(multipleArrayFieldsObj),
            encoding: .utf8
        )!
        #expect(multipleArrayFieldsResult.contains("items[1]:"))
        #expect(multipleArrayFieldsResult.contains("  - nums[2]: 1,2"))
        #expect(multipleArrayFieldsResult.contains("    tags[2]: a,b"))
        #expect(multipleArrayFieldsResult.contains("    name: test"))
    }

    @Test func listFormatWithOnlyArrayFields() async throws {
        struct OnlyArrayFieldsObject: Codable {
            let nums: [Int]
            let tags: [String]
        }

        struct OnlyArrayFieldsArrayObject: Codable {
            let items: [OnlyArrayFieldsObject]
        }

        let onlyArrayFieldsObj = OnlyArrayFieldsArrayObject(items: [
            OnlyArrayFieldsObject(nums: [1, 2, 3], tags: ["a", "b"])
        ])
        let onlyArrayFieldsResult = String(
            data: try encoder.encode(onlyArrayFieldsObj),
            encoding: .utf8
        )!
        #expect(onlyArrayFieldsResult.contains("items[1]:"))
        #expect(onlyArrayFieldsResult.contains("  - nums[3]: 1,2,3"))
        #expect(onlyArrayFieldsResult.contains("    tags[2]: a,b"))
    }

    @Test func listFormatWithEmptyArraysInObjects() async throws {
        struct EmptyArrayInObjectObject: Codable {
            let name: String
            let data: [String]
        }

        struct EmptyArrayInObjectArrayObject: Codable {
            let items: [EmptyArrayInObjectObject]
        }

        let emptyArrayInObjectObj = EmptyArrayInObjectArrayObject(items: [
            EmptyArrayInObjectObject(name: "test", data: [])
        ])
        let emptyArrayInObjectResult = String(
            data: try encoder.encode(emptyArrayInObjectObj),
            encoding: .utf8
        )!
        #expect(emptyArrayInObjectResult.contains("items[1]:"))
        #expect(emptyArrayInObjectResult.contains("  - name: test"))
        #expect(emptyArrayInObjectResult.contains("    data[0]:"))
    }

    @Test func nestedTabularArraysFirstFieldOnHyphenLine() async throws {
        struct NestedTabularObject: Codable {
            let id: Int
        }

        struct NestedTabularContainerObject: Codable {
            let users: [NestedTabularObject]
            let note: String
        }

        struct NestedTabularContainerArrayObject: Codable {
            let items: [NestedTabularContainerObject]
        }

        let nestedTabularObj = NestedTabularContainerArrayObject(items: [
            NestedTabularContainerObject(
                users: [NestedTabularObject(id: 1), NestedTabularObject(id: 2)],
                note: "x"
            )
        ])
        let nestedTabularResult = String(
            data: try encoder.encode(nestedTabularObj),
            encoding: .utf8
        )!
        #expect(nestedTabularResult.contains("items[1]:"))
        #expect(nestedTabularResult.contains("  - users[2]{id}:"))
        #expect(nestedTabularResult.contains("    1"))
        #expect(nestedTabularResult.contains("    2"))
        #expect(nestedTabularResult.contains("    note: x"))
    }

    @Test func emptyArraysOnHyphenLineWhenFirst() async throws {
        struct EmptyArrayFirstObject: Codable {
            let data: [String]
            let name: String
        }

        struct EmptyArrayFirstArrayObject: Codable {
            let items: [EmptyArrayFirstObject]
        }

        let emptyArrayFirstObj = EmptyArrayFirstArrayObject(items: [
            EmptyArrayFirstObject(data: [], name: "x")
        ])
        let emptyArrayFirstResult = String(
            data: try encoder.encode(emptyArrayFirstObj),
            encoding: .utf8
        )!
        #expect(emptyArrayFirstResult.contains("items[1]:"))
        #expect(emptyArrayFirstResult.contains("  - data[0]:"))
        #expect(emptyArrayFirstResult.contains("    name: x"))
    }

    @Test func listFormatWithArrayOfArrays() async throws {
        struct ArrayOfArraysInObjectObject: Codable {
            let matrix: [[Int]]
            let name: String
        }

        struct ArrayOfArraysInObjectArrayObject: Codable {
            let items: [ArrayOfArraysInObjectObject]
        }

        let arrayOfArraysInObjectObj = ArrayOfArraysInObjectArrayObject(items: [
            ArrayOfArraysInObjectObject(matrix: [[1, 2], [3, 4]], name: "grid")
        ])
        let arrayOfArraysInObjectResult = String(
            data: try encoder.encode(arrayOfArraysInObjectObj),
            encoding: .utf8
        )!
        #expect(arrayOfArraysInObjectResult.contains("items[1]:"))
        #expect(arrayOfArraysInObjectResult.contains("  - matrix[2]:"))
        #expect(arrayOfArraysInObjectResult.contains("    - [2]: 1,2"))
        #expect(arrayOfArraysInObjectResult.contains("    - [2]: 3,4"))
        #expect(arrayOfArraysInObjectResult.contains("    name: grid"))
    }

    @Test func nestedTabularArrayInListFormat() async throws {
        struct NestedUser: Codable {
            let id: Int
            let name: String
        }

        struct NestedTabularInListObject: Codable {
            let users: [NestedUser]
            let status: String
        }

        struct NestedTabularInListArrayObject: Codable {
            let items: [NestedTabularInListObject]
        }

        let nestedTabularInListObj = NestedTabularInListArrayObject(items: [
            NestedTabularInListObject(
                users: [
                    NestedUser(id: 1, name: "Ada"),
                    NestedUser(id: 2, name: "Bob"),
                ],
                status: "active"
            )
        ])
        let nestedTabularInListResult = String(
            data: try encoder.encode(nestedTabularInListObj),
            encoding: .utf8
        )!
        #expect(nestedTabularInListResult.contains("items[1]:"))
        #expect(nestedTabularInListResult.contains("  - users[2]{id,name}:"))
        #expect(nestedTabularInListResult.contains("    1,Ada"))
        #expect(nestedTabularInListResult.contains("    2,Bob"))
        #expect(nestedTabularInListResult.contains("    status: active"))
    }

    @Test func nestedListArrayInListFormat() async throws {
        struct NestedListUser: Codable {
            let id: Int
            let name: String?
        }

        struct NestedListInListObject: Codable {
            let users: [NestedListUser]
            let status: String
        }

        struct NestedListInListArrayObject: Codable {
            let items: [NestedListInListObject]
        }

        let nestedListInListObj = NestedListInListArrayObject(items: [
            NestedListInListObject(
                users: [NestedListUser(id: 1, name: "Ada"), NestedListUser(id: 2, name: nil)],
                status: "active"
            )
        ])
        let nestedListInListResult = String(
            data: try encoder.encode(nestedListInListObj),
            encoding: .utf8
        )!
        #expect(nestedListInListResult.contains("items[1]:"))
        #expect(nestedListInListResult.contains("  - users[2]"))
        #expect(nestedListInListResult.contains("    status: active"))
    }

    // MARK: - Arrays of Arrays

    @Test func arrayOfArrays() async throws {
        struct ArrayOfArraysObject: Codable {
            let pairs: [[String]]
        }

        let arrayOfArraysObj = ArrayOfArraysObject(pairs: [["a", "b"], ["c", "d"]])
        let result = String(data: try encoder.encode(arrayOfArraysObj), encoding: .utf8)!

        #expect(result.contains("pairs[2]:"))
        #expect(result.contains("  - [2]: a,b"))
        #expect(result.contains("  - [2]: c,d"))
    }

    @Test func arrayOfArraysWithDelimiters() async throws {
        struct ArrayOfArraysObject: Codable {
            let pairs: [[String]]
        }

        let delimiterObj = ArrayOfArraysObject(pairs: [["a", "b"], ["c,d", "e:f", "true"]])
        let delimiterResult = String(data: try encoder.encode(delimiterObj), encoding: .utf8)!
        #expect(delimiterResult.contains("pairs[2]:"))
        #expect(delimiterResult.contains("  - [2]: a,b"))
        #expect(delimiterResult.contains("  - [3]: \"c,d\",\"e:f\",\"true\""))
    }

    @Test func arrayOfArraysWithEmptyInnerArrays() async throws {
        struct ArrayOfArraysObject: Codable {
            let pairs: [[String]]
        }

        let emptyInnerObj = ArrayOfArraysObject(pairs: [[], []])
        let emptyInnerResult = String(data: try encoder.encode(emptyInnerObj), encoding: .utf8)!
        #expect(emptyInnerResult.contains("pairs[2]:"))
        #expect(emptyInnerResult.contains("  - [0]:"))
        #expect(emptyInnerResult.contains("  - [0]:"))
    }

    @Test func arrayOfArraysWithMixedLengths() async throws {
        struct ArrayOfArraysObject: Codable {
            let pairs: [[String]]
        }

        let mixedLengthObj = ArrayOfArraysObject(pairs: [["1"], ["2", "3"]])
        let mixedLengthResult = String(data: try encoder.encode(mixedLengthObj), encoding: .utf8)!
        #expect(mixedLengthResult.contains("pairs[2]:"))
        #expect(mixedLengthResult.contains("  - [1]: \"1\""))
        #expect(mixedLengthResult.contains("  - [2]: \"2\",\"3\""))
    }

    // MARK: - Root Arrays

    @Test func rootPrimitiveArray() async throws {
        let primitiveArray = ["x", "y", "true", "10"]
        let primitiveResult = String(data: try encoder.encode(primitiveArray), encoding: .utf8)!
        #expect(primitiveResult.contains("[4]: x,y,\"true\",\"10\""))
    }

    @Test func rootObjectArray() async throws {
        struct SimpleObject: Codable {
            let id: Int
        }

        let objectArray = [SimpleObject(id: 1), SimpleObject(id: 2)]
        let objectResult = String(data: try encoder.encode(objectArray), encoding: .utf8)!
        #expect(objectResult.contains("[2]{id}:"))
        #expect(objectResult.contains("  1"))
        #expect(objectResult.contains("  2"))
    }

    @Test func rootObjectArrayWithOptionalFields() async throws {
        struct OptionalObject: Codable {
            let id: Int
            let name: String?
        }

        let optionalArray = [
            OptionalObject(id: 1, name: nil),
            OptionalObject(id: 2, name: "Ada"),
        ]
        let optionalResult = String(data: try encoder.encode(optionalArray), encoding: .utf8)!
        #expect(optionalResult.contains("[2]{id,name}:"))
        #expect(optionalResult.contains("  1,null"))
        #expect(optionalResult.contains("  2,Ada"))
    }

    @Test func rootObjectArrayInListFormat() async throws {
        struct DifferentObject1: Codable {
            let id: Int
        }

        struct DifferentObject2: Codable {
            let id: Int
            let name: String
        }

        // Swift cannot encode heterogeneous arrays easily
        // Test list format expectations separately
        let obj1 = DifferentObject1(id: 1)
        let obj2 = DifferentObject2(id: 2, name: "Ada")

        let result1 = String(data: try encoder.encode(obj1), encoding: .utf8)!
        #expect(result1.contains("id: 1"))

        let result2 = String(data: try encoder.encode(obj2), encoding: .utf8)!
        #expect(result2.contains("id: 2"))
        #expect(result2.contains("name: Ada"))
    }

    @Test func rootEmptyArray() async throws {
        let emptyArray: [String] = []
        let emptyResult = String(data: try encoder.encode(emptyArray), encoding: .utf8)!
        #expect(emptyResult.contains("[0]:"))
    }

    @Test func rootArrayOfArrays() async throws {
        let arrayOfArrays = [["1", "2"], []]
        let arrayOfArraysResult = String(data: try encoder.encode(arrayOfArrays), encoding: .utf8)!
        #expect(arrayOfArraysResult.contains("[2]:"))
        #expect(arrayOfArraysResult.contains("  - [2]: \"1\",\"2\""))
        #expect(arrayOfArraysResult.contains("  - [0]:"))
    }

    // MARK: - Complex Structures

    @Test func complexStructure() async throws {
        struct ComplexObject: Codable {
            struct User: Codable {
                let id: Int
                let name: String
                let tags: [String]
                let active: Bool
                let prefs: [String]
            }
            let user: User
        }

        let complexObj = ComplexObject(
            user: ComplexObject.User(
                id: 123,
                name: "Ada",
                tags: ["reading", "gaming"],
                active: true,
                prefs: []
            )
        )
        let result = String(data: try encoder.encode(complexObj), encoding: .utf8)!

        #expect(result.contains("user:"))
        #expect(result.contains("  id: 123"))
        #expect(result.contains("  name: Ada"))
        #expect(result.contains("  tags[2]: reading,gaming"))
        #expect(result.contains("  active: true"))
        #expect(result.contains("  prefs[0]:"))
    }

    // MARK: - Delimiter Options

    @Test func tabDelimiter() async throws {
        let encoder = TOONEncoder()
        encoder.delimiter = .tab

        struct DelimiterTestObject: Codable {
            let tags: [String]
        }

        let tabObj = DelimiterTestObject(tags: ["reading", "gaming", "coding"])
        let tabResult = String(data: try encoder.encode(tabObj), encoding: .utf8)!
        #expect(tabResult.contains("tags[3\t]: reading\tgaming\tcoding"))
    }

    @Test func pipeDelimiter() async throws {
        let encoder = TOONEncoder()
        encoder.delimiter = .pipe

        struct DelimiterTestObject: Codable {
            let tags: [String]
        }

        let pipeObj = DelimiterTestObject(tags: ["reading", "gaming", "coding"])
        let pipeResult = String(data: try encoder.encode(pipeObj), encoding: .utf8)!
        #expect(pipeResult.contains("tags[3|]: reading|gaming|coding"))
    }

    @Test func tabularArraysWithTabDelimiter() async throws {
        struct TabularDelimiterObject: Codable {
            let sku: String
            let qty: Int
            let price: Double
        }

        struct TabularDelimiterArrayObject: Codable {
            let items: [TabularDelimiterObject]
        }

        let tabEncoder = TOONEncoder()
        tabEncoder.delimiter = .tab
        let tabularTabObj = TabularDelimiterArrayObject(items: [
            TabularDelimiterObject(sku: "A1", qty: 2, price: 9.99),
            TabularDelimiterObject(sku: "B2", qty: 1, price: 14.5),
        ])
        let tabularTabResult = String(data: try tabEncoder.encode(tabularTabObj), encoding: .utf8)!
        #expect(tabularTabResult.contains("items[2\t]{sku\tqty\tprice}:"))
        #expect(tabularTabResult.contains("  A1\t2\t9.99"))
        #expect(tabularTabResult.contains("  B2\t1\t14.5"))
    }

    @Test func tabularArraysWithPipeDelimiter() async throws {
        struct TabularDelimiterObject: Codable {
            let sku: String
            let qty: Int
            let price: Double
        }

        struct TabularDelimiterArrayObject: Codable {
            let items: [TabularDelimiterObject]
        }

        let pipeEncoder = TOONEncoder()
        pipeEncoder.delimiter = .pipe
        let tabularPipeObj = TabularDelimiterArrayObject(items: [
            TabularDelimiterObject(sku: "A1", qty: 2, price: 9.99),
            TabularDelimiterObject(sku: "B2", qty: 1, price: 14.5),
        ])
        let tabularPipeResult = String(data: try pipeEncoder.encode(tabularPipeObj), encoding: .utf8)!
        #expect(tabularPipeResult.contains("items[2|]{sku|qty|price}:"))
        #expect(tabularPipeResult.contains("  A1|2|9.99"))
        #expect(tabularPipeResult.contains("  B2|1|14.5"))
    }

    @Test func delimiterAwareQuoting() async throws {
        struct DelimiterTestObject: Codable {
            let tags: [String]
        }

        let delimiterEncoder = TOONEncoder()
        delimiterEncoder.delimiter = .tab
        let delimiterQuoteObj = DelimiterTestObject(tags: ["a", "b\tc", "d"])
        let delimiterQuoteResult = String(
            data: try delimiterEncoder.encode(delimiterQuoteObj),
            encoding: .utf8
        )!
        #expect(delimiterQuoteResult.contains("tags[3\t]: a\t\"b\\tc\"\td"))

        delimiterEncoder.delimiter = .pipe
        let pipeQuoteObj = DelimiterTestObject(tags: ["a", "b|c", "d"])
        let pipeQuoteResult = String(data: try delimiterEncoder.encode(pipeQuoteObj), encoding: .utf8)!
        #expect(pipeQuoteResult.contains("tags[3|]: a|\"b|c\"|d"))
    }

    @Test func nonCommaDelimiterDoesNotQuoteCommas() async throws {
        struct DelimiterTestObject: Codable {
            let tags: [String]
        }

        let delimiterEncoder = TOONEncoder()
        delimiterEncoder.delimiter = .pipe
        let commaObj = DelimiterTestObject(tags: ["a,b", "c,d"])
        let commaResult = String(data: try delimiterEncoder.encode(commaObj), encoding: .utf8)!
        #expect(commaResult.contains("tags[2|]: a,b|c,d"))

        delimiterEncoder.delimiter = .tab
        let tabCommaResult = String(data: try delimiterEncoder.encode(commaObj), encoding: .utf8)!
        #expect(tabCommaResult.contains("tags[2\t]: a,b\tc,d"))
    }

    // MARK: - Length Marker Option

    @Test func lengthMarkerHash() async throws {
        let encoder = TOONEncoder()
        encoder.lengthMarker = .hash

        struct LengthMarkerTestObject: Codable {
            let tags: [String]
            let items: [String]
        }

        let lengthMarkerObj = LengthMarkerTestObject(tags: ["reading", "gaming", "coding"], items: [])
        let result = String(data: try encoder.encode(lengthMarkerObj), encoding: .utf8)!

        #expect(result.contains("tags[#3]: reading,gaming,coding"))
        #expect(result.contains("items[#0]:"))
    }

    @Test func lengthMarkerWithTabularArrays() async throws {
        let encoder = TOONEncoder()
        encoder.lengthMarker = .hash

        struct TabularLengthMarkerObject: Codable {
            let sku: String
            let qty: Int
            let price: Double
        }

        struct TabularLengthMarkerArrayObject: Codable {
            let items: [TabularLengthMarkerObject]
        }

        let tabularLengthMarkerObj = TabularLengthMarkerArrayObject(items: [
            TabularLengthMarkerObject(sku: "A1", qty: 2, price: 9.99),
            TabularLengthMarkerObject(sku: "B2", qty: 1, price: 14.5),
        ])
        let tabularLengthMarkerResult = String(
            data: try encoder.encode(tabularLengthMarkerObj),
            encoding: .utf8
        )!
        #expect(tabularLengthMarkerResult.contains("items[#2]{sku,qty,price}:"))
        #expect(tabularLengthMarkerResult.contains("  A1,2,9.99"))
        #expect(tabularLengthMarkerResult.contains("  B2,1,14.5"))
    }

    @Test func lengthMarkerWithNestedArrays() async throws {
        let encoder = TOONEncoder()
        encoder.lengthMarker = .hash

        struct NestedLengthMarkerObject: Codable {
            let pairs: [[String]]
        }

        let nestedLengthMarkerObj = NestedLengthMarkerObject(pairs: [["a", "b"], ["c", "d"]])
        let nestedLengthMarkerResult = String(
            data: try encoder.encode(nestedLengthMarkerObj),
            encoding: .utf8
        )!
        #expect(nestedLengthMarkerResult.contains("pairs[#2]:"))
        #expect(nestedLengthMarkerResult.contains("  - [#2]: a,b"))
        #expect(nestedLengthMarkerResult.contains("  - [#2]: c,d"))
    }

    @Test func lengthMarkerWithDelimiter() async throws {
        let encoder = TOONEncoder()
        encoder.lengthMarker = .hash
        encoder.delimiter = .pipe

        struct LengthMarkerTestObject: Codable {
            let tags: [String]
        }

        let lengthMarkerObj = LengthMarkerTestObject(tags: ["reading", "gaming", "coding"])
        let delimiterLengthMarkerResult = String(
            data: try encoder.encode(lengthMarkerObj),
            encoding: .utf8
        )!
        #expect(delimiterLengthMarkerResult.contains("tags[#3|]: reading|gaming|coding"))
    }

    @Test func lengthMarkerNone() async throws {
        let encoder = TOONEncoder()
        encoder.lengthMarker = .none
        encoder.delimiter = .pipe

        struct LengthMarkerTestObject: Codable {
            let tags: [String]
        }

        let lengthMarkerObj = LengthMarkerTestObject(tags: ["reading", "gaming", "coding"])
        let noMarkerResult = String(data: try encoder.encode(lengthMarkerObj), encoding: .utf8)!
        #expect(noMarkerResult.contains("tags[3|]: reading|gaming|coding"))
    }

    // MARK: - Non-JSON-serializable Values

    @Test func dateConversion() async throws {
        let date = Date(timeIntervalSince1970: 0)
        let dateResult = String(data: try encoder.encode(date), encoding: .utf8)!
        #expect(dateResult.contains("\"1970-01-01T00:00:00.000Z\""))

        struct DateObject: Codable {
            let created: Date
        }

        let dateObj = DateObject(created: date)
        let dateObjResult = String(data: try encoder.encode(dateObj), encoding: .utf8)!
        #expect(dateObjResult.contains("created: \"1970-01-01T00:00:00.000Z\""))
    }

    @Test func urlConversion() async throws {
        let url = URL(string: "https://example.com")!
        let urlResult = String(data: try encoder.encode(url), encoding: .utf8)!
        #expect(urlResult.contains("\"https://example.com\""))

        struct URLObject: Codable {
            let url: URL
        }

        let urlObj = URLObject(url: url)
        let urlObjResult = String(data: try encoder.encode(urlObj), encoding: .utf8)!
        #expect(urlObjResult.contains("url: \"https://example.com\""))
    }

    @Test func dataConversion() async throws {
        let data = "hello".data(using: .utf8)!
        let dataResult = String(data: try encoder.encode(data), encoding: .utf8)!
        #expect(dataResult.contains("aGVsbG8="))

        struct DataObject: Codable {
            let data: Data
        }

        let dataObj = DataObject(data: data)
        let dataObjResult = String(data: try encoder.encode(dataObj), encoding: .utf8)!
        #expect(dataObjResult.contains("data: aGVsbG8="))
    }

    @Test func nonFiniteNumbers() async throws {
        let infResult = String(data: try encoder.encode(Double.infinity), encoding: .utf8)!
        #expect(infResult.contains("null"))

        let negInfResult = String(data: try encoder.encode(-Double.infinity), encoding: .utf8)!
        #expect(negInfResult.contains("null"))

        let nanResult = String(data: try encoder.encode(Double.nan), encoding: .utf8)!
        #expect(nanResult.contains("null"))

        struct NonFiniteObject: Codable {
            let value: Double
        }

        let nonFiniteObj = NonFiniteObject(value: Double.infinity)
        let nonFiniteResult = String(data: try encoder.encode(nonFiniteObj), encoding: .utf8)!
        #expect(nonFiniteResult.contains("value: null"))
    }

    @Test func integerTypesConversion() async throws {
        // Swift's Int is a native type, similar to JavaScript's BigInt in behavior
        let largeInt = Int.max
        let largeIntResult = String(data: try encoder.encode(largeInt), encoding: .utf8)!
        #expect(largeIntResult == "9223372036854775807")

        struct IntObject: Codable {
            let id: Int
        }

        let intObj = IntObject(id: 456)
        let intObjResult = String(data: try encoder.encode(intObj), encoding: .utf8)!
        #expect(intObjResult.contains("id: 456"))
    }

    @Test func optionalToNull() async throws {
        // Swift optionals convert to null when nil, similar to JavaScript's undefined → null
        struct OptionalValueObject: Codable {
            let value: String?
        }

        let nilObj = OptionalValueObject(value: nil)
        let nilResult = String(data: try encoder.encode(nilObj), encoding: .utf8)!
        #expect(nilResult.contains("value: null"))

        // Note: Swift does not have exact equivalents for JavaScript's Function or Symbol types
        // These would not be Codable in Swift and would be caught at compile time
    }

    // MARK: - Whitespace and Formatting Invariants

    @Test func noTrailingSpaces() async throws {
        struct WhitespaceTestObject: Codable {
            struct User: Codable {
                let id: Int
                let name: String
            }
            let user: User
            let items: [String]
        }

        let whitespaceObj = WhitespaceTestObject(
            user: WhitespaceTestObject.User(id: 123, name: "Ada"),
            items: ["a", "b"]
        )
        let result = String(data: try encoder.encode(whitespaceObj), encoding: .utf8)!
        let lines = result.components(separatedBy: "\n")

        for line in lines {
            #expect(!line.hasSuffix(" "))
        }
    }

    @Test func noTrailingNewline() async throws {
        struct WhitespaceTestObject: Codable {
            struct User: Codable {
                let id: Int
                let name: String
            }
            let user: User
            let items: [String]
        }

        let whitespaceObj = WhitespaceTestObject(
            user: WhitespaceTestObject.User(id: 123, name: "Ada"),
            items: ["a", "b"]
        )
        let result = String(data: try encoder.encode(whitespaceObj), encoding: .utf8)!
        #expect(!result.hasSuffix("\n"))

        struct SimpleWhitespaceObject: Codable {
            let id: Int
        }

        let simpleObj = SimpleWhitespaceObject(id: 123)
        let simpleResult = String(data: try encoder.encode(simpleObj), encoding: .utf8)!
        #expect(!simpleResult.hasSuffix("\n"))
    }

    // MARK: - Key Folding (TOON 2.1)

    @Test func keyFoldingDisabled() async throws {
        struct NestedObject: Codable {
            struct User: Codable {
                struct Profile: Codable {
                    let name: String
                }
                let profile: Profile
            }
            let user: User
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .disabled

        let obj = NestedObject(user: .init(profile: .init(name: "Ada")))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
        user:
          profile:
            name: Ada
        """
        #expect(result == expected)
    }

    @Test func keyFoldingSafe() async throws {
        struct NestedObject: Codable {
            struct User: Codable {
                struct Profile: Codable {
                    let name: String
                }
                let profile: Profile
            }
            let user: User
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = NestedObject(user: .init(profile: .init(name: "Ada")))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
        user.profile.name: Ada
        """
        #expect(result == expected)
    }

    @Test func keyFoldingWithMultipleFields() async throws {
        struct Config: Codable {
            struct Database: Codable {
                struct Connection: Codable {
                    let host: String
                    let port: Int
                }
                let connection: Connection
            }
            struct API: Codable {
                let key: String
            }
            let database: Database
            let api: API
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = Config(
            database: .init(connection: .init(host: "localhost", port: 5432)),
            api: .init(key: "secret")
        )
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
        database.connection:
          host: localhost
          port: 5432
        api.key: secret
        """
        #expect(result == expected)
    }

    @Test func keyFoldingStopsAtInvalidIdentifier() async throws {
        // Keys with hyphens cannot be folded
        struct ValidThenInvalid: Codable {
            struct Data: Codable {
                struct UserInfo: Codable {
                    let field1: String

                    enum CodingKeys: String, CodingKey {
                        case field1 = "field-1"
                    }
                }
                let userInfo: UserInfo

                enum CodingKeys: String, CodingKey {
                    case userInfo = "user-info"
                }
            }
            let data: Data
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = ValidThenInvalid(data: .init(userInfo: .init(field1: "value")))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // Should fold "data" but stop at "user-info" because it contains hyphen
        let expected = """
        data:
          "user-info":
            "field-1": value
        """
        #expect(result == expected)
    }

    @Test func keyFoldingWithArray() async throws {
        struct Container: Codable {
            struct Wrapper: Codable {
                let items: [Int]
            }
            let wrapper: Wrapper
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = Container(wrapper: .init(items: [1, 2, 3]))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
        wrapper.items[3]: 1,2,3
        """
        #expect(result == expected)
    }

    @Test func versionDeclaration() async throws {
        #expect(TOONEncoder.specVersion == "3.0")
    }

    @Test func canonicalNumberFormat() async throws {
        // TOON 2.1 requires canonical decimal form: no trailing fractional zeros
        struct Numbers: Codable {
            let a: Double
            let b: Double
            let c: Double
            let d: Double
        }

        let obj = Numbers(a: 1.5, b: 2.0, c: 0.1, d: 123.456)
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        let expected = """
        a: 1.5
        b: 2
        c: 0.1
        d: 123.456
        """
        #expect(result == expected)
    }

    // MARK: - flattenDepth Tests (TOON 3.0)

    @Test func flattenDepthUnlimited() async throws {
        struct DeepNested: Codable {
            struct Level1: Codable {
                struct Level2: Codable {
                    struct Level3: Codable {
                        let value: Int
                    }
                    let level3: Level3
                }
                let level2: Level2
            }
            let level1: Level1
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe
        encoder.flattenDepth = .max  // Unlimited (default)

        let obj = DeepNested(level1: .init(level2: .init(level3: .init(value: 42))))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // All levels should be folded into a single dotted path
        let expected = """
        level1.level2.level3.value: 42
        """
        #expect(result == expected)
    }

    @Test func flattenDepthLimited() async throws {
        struct DeepNested: Codable {
            struct Level1: Codable {
                struct Level2: Codable {
                    struct Level3: Codable {
                        let value: Int
                    }
                    let level3: Level3
                }
                let level2: Level2
            }
            let level1: Level1
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe
        encoder.flattenDepth = 2  // Only fold 2 segments

        let obj = DeepNested(level1: .init(level2: .init(level3: .init(value: 42))))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // Only first 2 levels should be folded
        let expected = """
        level1.level2:
          level3:
            value: 42
        """
        #expect(result == expected)
    }

    @Test func flattenDepthThree() async throws {
        struct DeepNested: Codable {
            struct Level1: Codable {
                struct Level2: Codable {
                    struct Level3: Codable {
                        let value: Int
                    }
                    let level3: Level3
                }
                let level2: Level2
            }
            let level1: Level1
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe
        encoder.flattenDepth = 3

        let obj = DeepNested(level1: .init(level2: .init(level3: .init(value: 42))))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // First 3 levels should be folded
        let expected = """
        level1.level2.level3:
          value: 42
        """
        #expect(result == expected)
    }

    @Test func flattenDepthOne() async throws {
        // flattenDepth < 2 has no practical folding effect
        struct NestedObject: Codable {
            struct User: Codable {
                let name: String
            }
            let user: User
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe
        encoder.flattenDepth = 1  // No folding effect

        let obj = NestedObject(user: .init(name: "Ada"))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // Should not fold because flattenDepth < 2
        let expected = """
        user:
          name: Ada
        """
        #expect(result == expected)
    }

    // MARK: - Collision Avoidance Tests (TOON 3.0)

    @Test func keyFoldingCollisionAvoidance() async throws {
        // Test that folding doesn't create keys that collide with existing siblings
        // The key "a.b" is a literal sibling key, and folding "a" -> {b: 1} would create "a.b"
        // which would collide, so folding should NOT happen
        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        // Create a structure where "a.b" is a literal key at the same level as "a"
        struct CollisionTest: Codable {
            struct Nested: Codable {
                let b: Int
            }
            let ab: Int   // Will be encoded as "a.b" (literal dotted key)
            let a: Nested // Would be folded to "a.b" if not for collision

            enum CodingKeys: String, CodingKey {
                case ab = "a.b"
                case a
            }
        }

        let obj = CollisionTest(ab: 1, a: .init(b: 2))
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // "a" should NOT be folded to "a.b" because "a.b" exists as a sibling
        // Note: "a.b" is a valid unquoted key per spec (pattern allows dots)
        let expected = """
        a.b: 1
        a:
          b: 2
        """
        #expect(result == expected)
    }

    @Test func keyFoldingNoCollision() async throws {
        // Test normal folding when there's no collision
        struct NoCollision: Codable {
            struct A: Codable {
                let b: Int
            }
            let a: A
            let c: Int
        }

        let encoder = TOONEncoder()
        encoder.keyFolding = .safe

        let obj = NoCollision(a: .init(b: 1), c: 2)
        let result = String(data: try encoder.encode(obj), encoding: .utf8)!

        // "a" should be folded to "a.b" since there's no collision
        let expected = """
        a.b: 1
        c: 2
        """
        #expect(result == expected)
    }
}
