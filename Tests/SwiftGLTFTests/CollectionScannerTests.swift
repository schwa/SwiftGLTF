import Foundation
import Testing

@testable import SwiftGLTF

struct CollectionScannerTests {
    @Test
    func basicScanAndCursor() {
        var scanner = CollectionScanner(elements: [1, 2, 3, 4, 5])
        #expect(scanner.atEnd == false)
        #expect(scanner.remainingCount == 5)

        let first = scanner.scan(count: 2)
        #expect(first.map(Array.init) == [1, 2])
        #expect(scanner.remainingCount == 3)
        #expect(Array(scanner.remaining) == [3, 4, 5])

        let tooMany = scanner.scan(count: 99) // not enough remaining
        #expect(tooMany == nil)
        let rest = scanner.scan(count: 3)
        #expect(rest.map(Array.init) == [3, 4, 5])
        #expect(scanner.atEnd)
        let afterEnd = scanner.scan(count: 1)
        #expect(afterEnd == nil) // at end
    }

    @Test
    func peek() {
        var scanner = CollectionScanner(elements: [10, 20])
        #expect(scanner.peek() == 10)
        _ = scanner.scan(count: 2)
        #expect(scanner.peek() == nil)
    }

    @Test
    func scanSingleValue() {
        var scanner = CollectionScanner(elements: [1, 2, 3])
        let a = scanner.scan(value: 1)
        #expect(a)
        let bad = scanner.scan(value: 9) // mismatch, cursor unchanged
        #expect(bad == false)
        let b = scanner.scan(value: 2)
        #expect(b)
        _ = scanner.scan(value: 3)
        let atEnd = scanner.scan(value: 4)
        #expect(atEnd == false) // at end
    }

    @Test
    func scanValueSequence() {
        var scanner = CollectionScanner(elements: [1, 2, 3, 4])
        let a = scanner.scan(value: [1, 2])
        #expect(a)
        let bad = scanner.scan(value: [9, 9]) // mismatch resets cursor
        #expect(bad == false)
        #expect(Array(scanner.remaining) == [3, 4])
        let b = scanner.scan(value: [3, 4])
        #expect(b)
        #expect(scanner.atEnd)
    }

    @Test
    func scanUpToSingleValue() {
        var scanner = CollectionScanner(elements: [1, 2, 3, 0, 4])
        let upTo = scanner.scanUpTo(value: 0)
        #expect(upTo.map(Array.init) == [1, 2, 3])
        #expect(scanner.peek() == 0) // separator not consumed

        var consuming = CollectionScanner(elements: [1, 2, 0, 3])
        let head = consuming.scanUpTo(value: 0, consuming: true)
        #expect(head.map(Array.init) == [1, 2])
        #expect(consuming.peek() == 3) // separator consumed

        var noMatch = CollectionScanner(elements: [1, 2, 3])
        let all = noMatch.scanUpTo(value: 9)
        #expect(all.map(Array.init) == [1, 2, 3])
    }

    @Test
    func scanUpToValueSequence() {
        var scanner = CollectionScanner(elements: [1, 2, 7, 8, 3])
        let head = scanner.scanUpTo(value: [7, 8])
        #expect(head.map(Array.init) == [1, 2])

        var consuming = CollectionScanner(elements: [1, 2, 7, 8, 3])
        let consumed = consuming.scanUpTo(value: [7, 8], consuming: true)
        #expect(consumed.map(Array.init) == [1, 2])
        #expect(Array(consuming.remaining) == [3])

        var noMatch = CollectionScanner(elements: [1, 2, 3])
        let all = noMatch.scanUpTo(value: [9, 9])
        #expect(all.map(Array.init) == [1, 2, 3])
    }

    @Test
    func componentsSeparatedBy() {
        var scanner = CollectionScanner(elements: [1, 0, 2, 0, 3])
        let parts = scanner.scan(componentsSeparatedBy: 0).map(Array.init)
        #expect(parts == [[1], [2], [3]])

        var empty = CollectionScanner<[Int]>(elements: [])
        let none = empty.scan(componentsSeparatedBy: 0)
        #expect(none.isEmpty)
    }

    @Test
    func scanAnyOf() {
        var scanner = CollectionScanner(elements: [2, 5, 9])
        let hit = scanner.scan(anyOf: [1, 2, 3])
        #expect(hit == 2)
        let miss = scanner.scan(anyOf: [1, 2, 3]) // 5 not in set
        #expect(miss == nil)
        _ = scanner.scan(count: 2)
        let atEnd = scanner.scan(anyOf: [1, 2, 3])
        #expect(atEnd == nil) // at end
    }

    @Test
    func scanUntil() {
        var scanner = CollectionScanner(elements: [1, 2, 3, 4])
        let head = scanner.scan { $0 >= 3 }
        #expect(head.map(Array.init) == [1, 2])
        #expect(scanner.peek() == 3)

        var never = CollectionScanner(elements: [1, 2])
        let all = never.scan { $0 > 99 }
        #expect(all.map(Array.init) == [1, 2]) // consumes all
    }

    @Test
    func scanBlock() {
        let scanner = CollectionScanner(elements: [1, 2, 3])
        let count = scanner.scan { inner -> Int in
            inner.scan(count: 2)?.count ?? 0
        }
        #expect(count == 2)
        #expect(scanner.atEnd == false) // operates on a copy
    }

    @Test
    func scanBinaryIntegerAndFloat() {
        var int32 = CollectionScanner(elements: [UInt8](withLittleEndianUInt32: 0x1234_5678))
        let u = int32.scan(type: UInt32.self)
        #expect(u == 0x1234_5678)

        var floatValue: Float = 3.5
        let floatBytes = Swift.withUnsafeBytes(of: &floatValue) { Array($0) }
        var floatScanner = CollectionScanner(elements: floatBytes)
        let f = floatScanner.scan(type: Float.self)
        #expect(f == 3.5)

        var short = CollectionScanner<[UInt8]>(elements: [0x01])
        let tooShort = short.scan(type: UInt32.self)
        #expect(tooShort == nil) // not enough bytes
    }

    @Test
    func scanIntegerArray() {
        let bytes: [UInt8] = [1, 0, 2, 0, 3, 0] // three little-endian UInt16
        var scanner = CollectionScanner(elements: bytes)
        let values = scanner.scan(type: UInt16.self, count: 3)
        #expect(values == [1, 2, 3])
    }

    @Test
    func debugDescription() {
        var scanner = CollectionScanner(elements: [1, 2, 3, 4])
        _ = scanner.scan(count: 1)
        #expect(scanner.debugDescription == "0 / 4 / 1")
    }
}

private extension Array where Element == UInt8 {
    init(withLittleEndianUInt32 value: UInt32) {
        var little = value.littleEndian
        self = Swift.withUnsafeBytes(of: &little) { Array($0) }
    }
}
