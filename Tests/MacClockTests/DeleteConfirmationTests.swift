import Testing
@testable import MacClock

@Suite("DeleteConfirmation")
struct DeleteConfirmationTests {

    @Test("標題包含項目類型與名稱")
    func titleWithName() {
        #expect(DeleteConfirmation.title(for: .timer, name: "泡茶") == "要刪除計時器「泡茶」嗎？")
        #expect(DeleteConfirmation.title(for: .schedule, name: "開始工作") == "要刪除排程「開始工作」嗎？")
    }

    @Test("名稱空白時使用通用標題", arguments: ["", "   ", "\n"])
    func titleWithoutName(name: String) {
        #expect(DeleteConfirmation.title(for: .timer, name: name) == "要刪除這個計時器嗎？")
    }

    @Test("名稱過長時截斷")
    func longNameTruncated() {
        let long = String(repeating: "長", count: 100)
        let title = DeleteConfirmation.title(for: .schedule, name: long)
        #expect(title.contains(String(repeating: "長", count: DeleteConfirmation.maxNameLength) + "…"))
        #expect(!title.contains(String(repeating: "長", count: DeleteConfirmation.maxNameLength + 1)))
    }
}
