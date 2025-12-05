import Foundation
import Testing

@testable import ToonFormat

@Suite("Decoder Tests")
struct DecoderTests {
    let encoder = TOONEncoder()
    let decoder = TOONDecoder()

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
        // Quoted strings that look like booleans/null should remain strings
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
        // Quoted strings that look like numbers should remain strings
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

    @Test func quotedEscapeInString() async throws {
        let data = "\"hello \\\"world\\\"\"".data(using: .utf8)!
        let result = try decoder.decode(String.self, from: data)
        #expect(result == "hello \"world\"")
    }

    @Test func multipleEscapeSequences() async throws {
        let data = "\"line1\\nline2\\ttab\\rreturn\\\\slash\"".data(using: .utf8)!
        let result = try decoder.decode(String.self, from: data)
        #expect(result == "line1\nline2\ttab\rreturn\\slash")
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

    @Test func largeIntegers() async throws {
        let data = "9223372036854775807".data(using: .utf8)!  // Int64.max
        let result = try decoder.decode(Int64.self, from: data)
        #expect(result == Int64.max)

        let data2 = "-9223372036854775808".data(using: .utf8)!  // Int64.min
        let result2 = try decoder.decode(Int64.self, from: data2)
        #expect(result2 == Int64.min)
    }

    @Test func doubles() async throws {
        let data = "3.14".data(using: .utf8)!
        let result = try decoder.decode(Double.self, from: data)
        #expect(result == 3.14)
    }

    @Test func negativeDouble() async throws {
        let data = "-3.14".data(using: .utf8)!
        let result = try decoder.decode(Double.self, from: data)
        #expect(result == -3.14)
    }

    @Test func zeroDouble() async throws {
        let data = "0.0".data(using: .utf8)!
        let result = try decoder.decode(Double.self, from: data)
        #expect(result == 0.0)
    }

    @Test func scientificNotation() async throws {
        let data = "1.5e10".data(using: .utf8)!
        let result = try decoder.decode(Double.self, from: data)
        #expect(result == 1.5e10)

        let data2 = "-2.5E-3".data(using: .utf8)!
        let result2 = try decoder.decode(Double.self, from: data2)
        #expect(result2 == -2.5e-3)
    }

    @Test func floatDecoding() async throws {
        struct FloatObject: Codable, Equatable {
            let value: Float
        }

        let toon = "value: 3.14"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(FloatObject.self, from: data)
        #expect(abs(result.value - 3.14) < 0.001)
    }

    @Test func booleans() async throws {
        let data = "true".data(using: .utf8)!
        let result = try decoder.decode(Bool.self, from: data)
        #expect(result == true)

        let data2 = "false".data(using: .utf8)!
        let result2 = try decoder.decode(Bool.self, from: data2)
        #expect(result2 == false)
    }

    @Test func nullRootValue() async throws {
        let data = "null".data(using: .utf8)!
        let result = try decoder.decode(String?.self, from: data)
        #expect(result == nil)
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

    @Test func emptyNestedObject() async throws {
        struct Outer: Codable, Equatable {
            struct Inner: Codable, Equatable {}
            let inner: Inner
        }

        let toon = "inner:"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(Outer.self, from: data)
        #expect(result.inner == Outer.Inner())
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

    @Test func extraWhitespaceInValues() async throws {
        struct TestObject: Codable, Equatable {
            let name: String
        }

        let toon = "name:   Ada   "
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(TestObject.self, from: data)
        #expect(result.name == "Ada")
    }

    @Test func crlfLineEndings() async throws {
        struct TestObject: Codable, Equatable {
            let id: Int
            let name: String
        }

        let toon = "id: 123\r\nname: Ada"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(TestObject.self, from: data)

        #expect(result.id == 123)
        #expect(result.name == "Ada")
    }

    // MARK: - Optional Values

    @Test func missingOptionalKey() async throws {
        struct OptionalObject: Codable, Equatable {
            let required: String
            let optional: String?
        }

        let toon = "required: hello"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(OptionalObject.self, from: data)

        #expect(result.required == "hello")
        #expect(result.optional == nil)
    }

    @Test func presentOptionalWithValue() async throws {
        struct OptionalObject: Codable, Equatable {
            let required: String
            let optional: String?
        }

        let toon = """
            required: hello
            optional: world
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(OptionalObject.self, from: data)

        #expect(result.required == "hello")
        #expect(result.optional == "world")
    }

    @Test func optionalArrays() async throws {
        struct OptionalArrayObject: Codable, Equatable {
            let items: [String]?
        }

        let toon1 = ""
        let data1 = toon1.data(using: .utf8)!
        let result1 = try decoder.decode(OptionalArrayObject.self, from: data1)
        #expect(result1.items == nil)

        let toon2 = "items[2]: a,b"
        let data2 = toon2.data(using: .utf8)!
        let result2 = try decoder.decode(OptionalArrayObject.self, from: data2)
        #expect(result2.items == ["a", "b"])
    }

    @Test func decodingWithDefaultValues() async throws {
        struct DefaultValueObject: Codable, Equatable {
            let name: String
            var count: Int = 0

            init(name: String, count: Int = 0) {
                self.name = name
                self.count = count
            }
        }

        let toon = """
            name: test
            count: 42
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(DefaultValueObject.self, from: data)
        #expect(result.name == "test")
        #expect(result.count == 42)
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

    @Test func unicodeKeys() async throws {
        struct UnicodeKeyObject: Codable, Equatable {
            let greeting: String

            enum CodingKeys: String, CodingKey {
                case greeting = "挨拶"
            }
        }

        let toon = "挨拶: hello"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(UnicodeKeyObject.self, from: data)
        #expect(result.greeting == "hello")
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

    @Test func nestedDictionary() async throws {
        struct OuterObject: Codable, Equatable {
            let nested: [String: String]
        }

        let toon = """
            nested:
              x: one
              y: two
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(OuterObject.self, from: data)

        #expect(result.nested["x"] == "one")
        #expect(result.nested["y"] == "two")
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

    @Test func multipleEmptyArrays() async throws {
        struct MultiEmptyArrays: Codable, Equatable {
            let a: [String]
            let b: [Int]
            let c: [Bool]
        }

        let toon = """
            a[0]:
            b[0]:
            c[0]:
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(MultiEmptyArrays.self, from: data)
        #expect(result.a == [])
        #expect(result.b == [])
        #expect(result.c == [])
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

    @Test func emptyStringInArray() async throws {
        struct ArrayObject: Codable, Equatable {
            let items: [String]
        }

        let toon = "items[3]: a,\"\",b"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(ArrayObject.self, from: data)
        #expect(result.items == ["a", "", "b"])
    }

    @Test func arraysWithSpecialStringValues() async throws {
        struct SpecialArrayObject: Codable, Equatable {
            let items: [String]
        }

        // Test strings with commas (quoted)
        let toon = "items[3]: \"a,b\",c,d"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(SpecialArrayObject.self, from: data)
        #expect(result.items == ["a,b", "c", "d"])
    }

    @Test func boolArrayInline() async throws {
        struct BoolArrayObject: Codable, Equatable {
            let flags: [Bool]
        }

        let toon = "flags[3]: true,false,true"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(BoolArrayObject.self, from: data)
        #expect(result.flags == [true, false, true])
    }

    @Test func nullInArray() async throws {
        struct NullArrayObject: Codable, Equatable {
            let items: [String?]
        }

        let toon = "items[3]: a,null,b"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(NullArrayObject.self, from: data)
        #expect(result.items.count == 3)
        #expect(result.items[0] == "a")
        #expect(result.items[1] == nil)
        #expect(result.items[2] == "b")
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

    @Test func singleColumnTabular() async throws {
        struct SingleColumn: Codable, Equatable {
            let id: Int
        }

        struct Container: Codable, Equatable {
            let items: [SingleColumn]
        }

        let toon = """
            items[3]{id}:
              1
              2
              3
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(Container.self, from: data)

        #expect(result.items.count == 3)
        #expect(result.items[0].id == 1)
        #expect(result.items[1].id == 2)
        #expect(result.items[2].id == 3)
    }

    @Test func tabularWithQuotedFieldNames() async throws {
        struct SpecialFields: Codable, Equatable {
            let firstName: String
            let lastName: String

            enum CodingKeys: String, CodingKey {
                case firstName = "first:name"
                case lastName = "last:name"
            }
        }

        struct Container: Codable, Equatable {
            let people: [SpecialFields]
        }

        let toon = """
            people[2]{"first:name","last:name"}:
              Ada,Lovelace
              Grace,Hopper
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(Container.self, from: data)

        #expect(result.people.count == 2)
        #expect(result.people[0].firstName == "Ada")
        #expect(result.people[0].lastName == "Lovelace")
    }

    @Test func stringStringDictionary() async throws {
        let toon = """
            [2]{key,value}:
              a,one
              b,two
            """
        let data = toon.data(using: .utf8)!

        // Decode as array of key-value objects
        struct KV: Codable, Equatable {
            let key: String
            let value: String
        }
        let result = try decoder.decode([KV].self, from: data)
        #expect(result.count == 2)
        #expect(result[0].key == "a")
        #expect(result[0].value == "one")
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

    @Test func arrayOfObjectsWithArrays() async throws {
        struct ItemWithArray: Codable, Equatable {
            let id: Int
            let tags: [String]
        }

        struct Container: Codable, Equatable {
            let items: [ItemWithArray]
        }

        let toon = """
            items[2]:
              - id: 1
                tags[2]: a,b
              - id: 2
                tags[1]: c
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(Container.self, from: data)

        #expect(result.items.count == 2)
        #expect(result.items[0].id == 1)
        #expect(result.items[0].tags == ["a", "b"])
        #expect(result.items[1].id == 2)
        #expect(result.items[1].tags == ["c"])
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

    @Test func deeplyNestedArrays() async throws {
        struct Container: Codable, Equatable {
            let matrix: [[[Int]]]
        }

        let toon = """
            matrix[2]:
              - [2]:
                - [2]: 1,2
                - [2]: 3,4
              - [1]:
                - [3]: 5,6,7
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(Container.self, from: data)

        #expect(result.matrix.count == 2)
        #expect(result.matrix[0].count == 2)
        #expect(result.matrix[0][0] == [1, 2])
        #expect(result.matrix[0][1] == [3, 4])
        #expect(result.matrix[1].count == 1)
        #expect(result.matrix[1][0] == [5, 6, 7])
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

    @Test func objectWithBothInlineAndExpandedArrays() async throws {
        struct MixedObject: Codable, Equatable {
            let inline: [String]
            let expanded: [String]
        }

        let toon = """
            inline[2]: a,b
            expanded[2]:
              - c
              - d
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(MixedObject.self, from: data)

        #expect(result.inline == ["a", "b"])
        #expect(result.expanded == ["c", "d"])
    }

    @Test func complexNestedObjectsWithArrays() async throws {
        struct Address: Codable, Equatable {
            let city: String
            let zip: String
        }

        struct Person: Codable, Equatable {
            let name: String
            let addresses: [Address]
        }

        struct Company: Codable, Equatable {
            let name: String
            let employees: [Person]
        }

        let toon = """
            name: TechCorp
            employees[2]:
              - name: Ada
                addresses[1]{city,zip}:
                  London,SW1A
              - name: Grace
                addresses[2]{city,zip}:
                  NYC,NY10001
                  Boston,MA02101
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(Company.self, from: data)

        #expect(result.name == "TechCorp")
        #expect(result.employees.count == 2)
        #expect(result.employees[0].name == "Ada")
        #expect(result.employees[0].addresses.count == 1)
        #expect(result.employees[0].addresses[0].city == "London")
        #expect(result.employees[1].addresses.count == 2)
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

    // MARK: - Enum Decoding

    @Test func stringBackedEnum() async throws {
        enum Status: String, Codable {
            case active
            case inactive
            case pending
        }

        struct EnumObject: Codable, Equatable {
            let status: Status
        }

        let toon = "status: active"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(EnumObject.self, from: data)
        #expect(result.status == .active)
    }

    @Test func intBackedEnum() async throws {
        enum Priority: Int, Codable {
            case low = 1
            case medium = 2
            case high = 3
        }

        struct EnumObject: Codable, Equatable {
            let priority: Priority
        }

        let toon = "priority: 2"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(EnumObject.self, from: data)
        #expect(result.priority == .medium)
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

    @Test func pathExpansionAutomatic() async throws {
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
        // .automatic is the default
        #expect(decoder.expandPaths == .automatic)

        let toon = "user.profile.name: Ada"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(NestedObject.self, from: data)
        #expect(result.user.profile.name == "Ada")
    }

    @Test func pathExpansionAutomaticFallbackOnCollision() async throws {
        struct CollisionObject: Codable, Equatable {
            let user: String
            let userName: String

            enum CodingKeys: String, CodingKey {
                case user
                case userName = "user.name"
            }
        }

        let decoder = TOONDecoder()
        // .automatic should fall back to literal key on path collision

        let toon = """
            user: Ada
            user.name: Lovelace
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(CollisionObject.self, from: data)
        #expect(result.user == "Ada")
        #expect(result.userName == "Lovelace")
    }

    @Test func pathExpansionSafeCollisionError() async throws {
        struct CollisionObject: Codable {
            let user: String
        }

        let decoder = TOONDecoder()
        decoder.expandPaths = .safe

        // This should fail because user.name implies user is an object,
        // but we also have user as a direct value
        let toon = """
            user: Ada
            user.name: Lovelace
            """
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(CollisionObject.self, from: data)
        }
    }

    @Test func multipleLevelPathExpansion() async throws {
        struct DeepNested: Codable, Equatable {
            struct Level1: Codable, Equatable {
                struct Level2: Codable, Equatable {
                    struct Level3: Codable, Equatable {
                        let value: String
                    }
                    let c: Level3
                }
                let b: Level2
            }
            let a: Level1
        }

        let decoder = TOONDecoder()
        decoder.expandPaths = .safe

        let toon = "a.b.c.value: deep"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(DeepNested.self, from: data)
        #expect(result.a.b.c.value == "deep")
    }

    // MARK: - Auto-detected Indentation

    @Test func autoDetectIndentation4Spaces() async throws {
        struct NestedObject: Codable, Equatable {
            struct Inner: Codable, Equatable {
                let value: String
            }

            let outer: Inner
        }

        let toon = """
            outer:
                value: test
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(NestedObject.self, from: data)
        #expect(result.outer.value == "test")
    }

    @Test func autoDetectIndentation3Spaces() async throws {
        struct NestedObject: Codable, Equatable {
            struct Inner: Codable, Equatable {
                let value: String
            }

            let outer: Inner
        }

        let toon = """
            outer:
               value: test
            """
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(NestedObject.self, from: data)
        #expect(result.outer.value == "test")
    }

    @Test func singleSpaceIndentation() async throws {
        struct NestedObject: Codable, Equatable {
            struct Inner: Codable, Equatable {
                let value: String
            }
            let outer: Inner
        }

        // Test 1-space indentation detection
        let toon = "outer:\n value: test"
        let data = toon.data(using: .utf8)!
        let result = try decoder.decode(NestedObject.self, from: data)
        #expect(result.outer.value == "test")
    }

    // MARK: - Specification Compliance

    @Test func versionDeclaration() async throws {
        #expect(toonSpecVersion == "3.0")
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

    @Test func roundTripOptionalValues() async throws {
        struct OptionalObject: Codable, Equatable {
            let required: String
            let optional: String?
        }

        let original1 = OptionalObject(required: "hello", optional: nil)
        let encoded1 = try encoder.encode(original1)
        let decoded1 = try decoder.decode(OptionalObject.self, from: encoded1)
        #expect(original1 == decoded1)

        let original2 = OptionalObject(required: "hello", optional: "world")
        let encoded2 = try encoder.encode(original2)
        let decoded2 = try decoder.decode(OptionalObject.self, from: encoded2)
        #expect(original2 == decoded2)
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

    @Test func roundTripEnums() async throws {
        enum Status: String, Codable {
            case active
            case inactive
        }

        struct EnumObject: Codable, Equatable {
            let status: Status
        }

        let original = EnumObject(status: .active)
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(EnumObject.self, from: encoded)
        #expect(original == decoded)
    }

    @Test func roundTripNestedOptionalArrays() async throws {
        struct NestedOptional: Codable, Equatable {
            let items: [String?]
        }

        let original = NestedOptional(items: ["a", nil, "b"])
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(NestedOptional.self, from: encoded)
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

    @Test func trailingBackslashError() async throws {
        let data = "\"invalid\\\"".data(using: .utf8)!
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

    @Test func invalidDateFormat() async throws {
        struct DateObject: Codable {
            let created: Date
        }

        let toon = "created: \"not-a-date\""
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(DateObject.self, from: data)
        }
    }

    @Test func invalidURL() async throws {
        struct URLObject: Codable {
            let url: URL
        }

        // Empty URL should fail
        let toon = "url: \"\""
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(URLObject.self, from: data)
        }
    }

    @Test func invalidBase64Data() async throws {
        struct DataObject: Codable {
            let data: Data
        }

        let toon = "data: \"not-valid-base64!!!\""
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(DataObject.self, from: data)
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

    @Test func int16Boundaries() async throws {
        struct Int16Object: Codable {
            let value: Int16
        }

        let toon1 = "value: 32767"  // Int16.max
        let data1 = toon1.data(using: .utf8)!
        let result1 = try decoder.decode(Int16Object.self, from: data1)
        #expect(result1.value == Int16.max)

        let toon2 = "value: -32768"  // Int16.min
        let data2 = toon2.data(using: .utf8)!
        let result2 = try decoder.decode(Int16Object.self, from: data2)
        #expect(result2.value == Int16.min)

        // Overflow
        let toon3 = "value: 32768"  // Exceeds Int16.max
        let data3 = toon3.data(using: .utf8)!
        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(Int16Object.self, from: data3)
        }
    }

    @Test func int32Boundaries() async throws {
        struct Int32Object: Codable {
            let value: Int32
        }

        let toon1 = "value: 2147483647"  // Int32.max
        let data1 = toon1.data(using: .utf8)!
        let result1 = try decoder.decode(Int32Object.self, from: data1)
        #expect(result1.value == Int32.max)

        let toon2 = "value: -2147483648"  // Int32.min
        let data2 = toon2.data(using: .utf8)!
        let result2 = try decoder.decode(Int32Object.self, from: data2)
        #expect(result2.value == Int32.min)

        // Overflow
        let toon3 = "value: 2147483648"  // Exceeds Int32.max
        let data3 = toon3.data(using: .utf8)!
        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(Int32Object.self, from: data3)
        }
    }

    @Test func uint16Boundaries() async throws {
        struct UInt16Object: Codable {
            let value: UInt16
        }

        let toon1 = "value: 65535"  // UInt16.max
        let data1 = toon1.data(using: .utf8)!
        let result1 = try decoder.decode(UInt16Object.self, from: data1)
        #expect(result1.value == UInt16.max)

        // Overflow
        let toon2 = "value: 65536"  // Exceeds UInt16.max
        let data2 = toon2.data(using: .utf8)!
        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(UInt16Object.self, from: data2)
        }
    }

    @Test func uint32Boundaries() async throws {
        struct UInt32Object: Codable {
            let value: UInt32
        }

        let toon1 = "value: 4294967295"  // UInt32.max
        let data1 = toon1.data(using: .utf8)!
        let result1 = try decoder.decode(UInt32Object.self, from: data1)
        #expect(result1.value == UInt32.max)

        // Overflow
        let toon2 = "value: 4294967296"  // Exceeds UInt32.max
        let data2 = toon2.data(using: .utf8)!
        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(UInt32Object.self, from: data2)
        }
    }

    @Test func uint64Boundaries() async throws {
        struct UInt64Object: Codable {
            let value: UInt64
        }

        let toon1 = "value: 0"
        let data1 = toon1.data(using: .utf8)!
        let result1 = try decoder.decode(UInt64Object.self, from: data1)
        #expect(result1.value == 0)

        // Negative values should fail
        let toon2 = "value: -1"
        let data2 = toon2.data(using: .utf8)!
        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(UInt64Object.self, from: data2)
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

    @Test func depthLimitExceeded() async throws {
        let decoder = TOONDecoder()
        decoder.limits = TOONDecoder.DecodingLimits(
            maxInputSize: 10 * 1024 * 1024,
            maxDepth: 1,
            maxObjectKeys: 10000,
            maxArrayLength: 100_000
        )

        struct Level3: Codable {
            let value: String
        }
        struct Level2: Codable {
            let inner: Level3
        }
        struct Level1: Codable {
            let middle: Level2
        }

        // depth 0: root, depth 1: middle, depth 2: inner (should exceed limit of 1)
        let toon = """
            middle:
              inner:
                value: deep
            """
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(Level1.self, from: data)
        }
    }

    @Test func objectKeyLimitExceeded() async throws {
        let decoder = TOONDecoder()
        decoder.limits = TOONDecoder.DecodingLimits(
            maxInputSize: 10 * 1024 * 1024,
            maxDepth: 128,
            maxObjectKeys: 2,
            maxArrayLength: 100_000
        )

        struct ManyKeysObject: Codable {
            let a: Int
            let b: Int
            let c: Int
        }

        let toon = """
            a: 1
            b: 2
            c: 3
            """
        let data = toon.data(using: .utf8)!

        #expect(throws: TOONDecodingError.self) {
            try decoder.decode(ManyKeysObject.self, from: data)
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
