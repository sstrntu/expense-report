import XCTest
@testable import TurfmappExpenseReport

final class CurrencyConverterTests: XCTestCase {

    // MARK: - canConvert

    func testCanConvertReturnsTrueForKnownPair() {
        XCTAssertTrue(CurrencyConverter.canConvert(from: "USD", to: "EUR"))
        XCTAssertTrue(CurrencyConverter.canConvert(from: "THB", to: "USD"))
        XCTAssertTrue(CurrencyConverter.canConvert(from: "JPY", to: "GBP"))
    }

    func testCanConvertReturnsFalseWhenEitherCurrencyUnknown() {
        XCTAssertFalse(CurrencyConverter.canConvert(from: "XYZ", to: "USD"))
        XCTAssertFalse(CurrencyConverter.canConvert(from: "USD", to: "ABC"))
        XCTAssertFalse(CurrencyConverter.canConvert(from: "FOO", to: "BAR"))
    }

    func testCanConvertIsCaseInsensitive() {
        XCTAssertTrue(CurrencyConverter.canConvert(from: "usd", to: "eur"))
        XCTAssertTrue(CurrencyConverter.canConvert(from: "Thb", to: "USD"))
    }

    // MARK: - convert

    func testConvertSameCurrencyReturnsIdentity() {
        XCTAssertEqual(CurrencyConverter.convert(100, from: "USD", to: "USD"), 100)
        XCTAssertEqual(CurrencyConverter.convert(500, from: "EUR", to: "EUR"), 500)
    }

    func testConvertReturnsNilForUnknownCurrency() {
        XCTAssertNil(CurrencyConverter.convert(100, from: "XYZ", to: "USD"))
        XCTAssertNil(CurrencyConverter.convert(100, from: "USD", to: "ABC"))
    }

    func testConvertUSDToEURUsesRate() {
        // 100 USD → 100 / 1.0 * 0.93 = 93 EUR
        let result = CurrencyConverter.convert(100, from: "USD", to: "EUR")
        XCTAssertEqual(result ?? 0, 93, accuracy: 0.01)
    }

    func testConvertEURToUSDIsInverse() {
        // 93 EUR → (93 / 0.93) * 1.0 = 100 USD
        let result = CurrencyConverter.convert(93, from: "EUR", to: "USD")
        XCTAssertEqual(result ?? 0, 100, accuracy: 0.01)
    }

    func testConvertTHBToUSD() {
        // 3550 THB → 3550 / 35.5 * 1.0 = 100 USD
        let result = CurrencyConverter.convert(3550, from: "THB", to: "USD")
        XCTAssertEqual(result ?? 0, 100, accuracy: 0.01)
    }

    func testConvertCrossRateGoesViaUSD() {
        // 93 EUR → 100 USD → 100 * 35.5 = 3550 THB
        let result = CurrencyConverter.convert(93, from: "EUR", to: "THB")
        XCTAssertEqual(result ?? 0, 3550, accuracy: 1.0)
    }

    func testConvertIsCaseInsensitive() {
        let lower = CurrencyConverter.convert(100, from: "usd", to: "eur")
        let upper = CurrencyConverter.convert(100, from: "USD", to: "EUR")
        XCTAssertEqual(lower, upper)
    }

    // MARK: - convertToDefault

    func testConvertToDefaultDelegatesToConvert() {
        let direct = CurrencyConverter.convert(100, from: "EUR", to: "USD")
        let viaDefault = CurrencyConverter.convertToDefault(amount: 100, currency: "EUR", defaultCurrency: "USD")
        XCTAssertEqual(direct, viaDefault)
    }

    func testConvertToDefaultSameCurrencyPassesThrough() {
        XCTAssertEqual(
            CurrencyConverter.convertToDefault(amount: 250, currency: "USD", defaultCurrency: "USD"),
            250
        )
    }
}
