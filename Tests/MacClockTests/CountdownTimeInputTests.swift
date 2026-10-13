import Foundation
import Testing
@testable import MacClock

@Suite("CountdownTimeInput")
struct CountdownTimeInputTests {

    @Test("解析分、分:秒、時:分:秒", arguments: [
        ("5", 300.0), ("5:30", 330.0), ("1:00:05", 3605.0), (" 2 : 15 ", 135.0), ("0", 0.0),
    ])
    func parsesValidInput(input: String, expected: TimeInterval) {
        #expect(CountdownTimeInput.parse(input) == expected)
    }

    @Test("不合法的輸入回傳 0", arguments: [
        "", "a:30", "5:", ":30", "-1", "1:2:3:4", "1.5", "abc", "100000",
    ])
    func rejectsInvalidInput(input: String) {
        #expect(CountdownTimeInput.parse(input) == 0)
    }

    @Test("極大數字不會溢位")
    func noOverflow() {
        #expect(CountdownTimeInput.parse("99999999999999999999") == 0)
        #expect(CountdownTimeInput.parse("99999:99999:99999") > 0)
    }

    @Test("輸入框格式")
    func formatInput() {
        #expect(CountdownTimeInput.format(330) == "5:30")
        #expect(CountdownTimeInput.format(3605) == "1:00:05")
    }

    @Test("列表顯示格式")
    func formatDisplay() {
        #expect(CountdownTimeInput.formatDisplay(65) == "01:05")
        #expect(CountdownTimeInput.formatDisplay(7200) == "2:00:00")
    }

    @Test("格式化後可再解析回原值", arguments: [59.0, 330.0, 3605.0, 86399.0])
    func roundTrip(seconds: TimeInterval) {
        #expect(CountdownTimeInput.parse(CountdownTimeInput.format(seconds)) == seconds)
    }
}
