import Testing
@testable import MacClock

@Suite("SingleValueCache")
struct SingleValueCacheTests {
    private final class Box {
        let key: String
        init(_ key: String) { self.key = key }
    }

    /// 記錄建立的物件（weak），用來確認舊值有被釋放
    private final class Factory: @unchecked Sendable {
        private(set) var created: [(key: String, box: () -> Box?)] = []
        func make(_ key: String) -> Box {
            let box = Box(key)
            weak var weakBox = box
            created.append((key, { weakBox }))
            return box
        }
        var aliveKeys: [String] { created.filter { $0.box() != nil }.map(\.key) }
    }

    @Test("相同 key 重複使用同一個物件")
    func reusesSameKey() {
        let factory = Factory()
        let cache = SingleValueCache<String, Box>(make: factory.make)
        let sameObject = cache.withValue(for: "zh") { first, _ in
            ObjectIdentifier(first)
        } == cache.withValue(for: "zh") { second, _ in
            ObjectIdentifier(second)
        }
        #expect(sameObject)
        #expect(factory.created.count == 1)
    }

    @Test("key 改變時只保留新的那一個，舊的被釋放")
    func keepsOnlyCurrentKey() {
        let factory = Factory()
        let cache = SingleValueCache<String, Box>(make: factory.make)
        cache.withValue(for: "zh") { _, _ in }
        let key = cache.withValue(for: "en") { value, _ in value.key }
        #expect(key == "en")
        #expect(factory.aliveKeys == ["en"])
    }

    @Test("切回原本的 key 會重新建立")
    func switchingBackRecreates() {
        let factory = Factory()
        let cache = SingleValueCache<String, Box>(make: factory.make)
        cache.withValue(for: "zh") { _, _ in }
        cache.withValue(for: "en") { _, _ in }
        cache.withValue(for: "zh") { _, _ in }
        #expect(factory.created.count == 3)
        #expect(factory.aliveKeys == ["zh"])
    }

    @Test("rebuild 丟掉目前的值、建立新的，之後沿用新的")
    func rebuildReplaces() {
        let factory = Factory()
        let cache = SingleValueCache<String, Box>(make: factory.make)
        let (before, after) = cache.withValue(for: "zh") { value, rebuild in
            (ObjectIdentifier(value), ObjectIdentifier(rebuild()))
        }
        #expect(before != after)
        let next = cache.withValue(for: "zh") { value, _ in ObjectIdentifier(value) }
        #expect(next == after)
        #expect(factory.created.count == 2)
        #expect(factory.aliveKeys == ["zh"])
    }
}
