import Foundation

/// Lightweight currency conversion using a static USD-based rate table.
/// Rates are approximate and refreshed on each app release. For totals shown
/// in the workspace default currency, expenses in other currencies are
/// converted on-the-fly. Source rows still display in the original currency
/// so an audit reviewer can always see the original receipt amount.
///
/// To refresh: pull mid-market rates from any FX API (ECB, exchangerate.host)
/// and replace `usdRates` below. A future iteration should fetch live rates
/// at bootstrap and cache them per workspace.
enum CurrencyConverter {
    /// Mid-market rates as of 2026-05-20 (1 USD = X CCY). Add new currencies
    /// here to expand coverage. Missing currencies fall back to no conversion.
    static let usdRates: [String: Double] = [
        "USD": 1.0,
        "EUR": 0.93,
        "GBP": 0.79,
        "THB": 35.50,
        "JPY": 157.20,
        "SGD": 1.35,
        "AUD": 1.51,
        "CAD": 1.37,
        "CHF": 0.91,
        "CNY": 7.24,
        "HKD": 7.80,
        "INR": 83.50,
        "KRW": 1370.00,
        "MXN": 17.10,
        "NZD": 1.64,
        "SEK": 10.65,
        "NOK": 10.85,
        "DKK": 6.93,
        "ZAR": 18.30,
        "BRL": 5.10
    ]

    /// True if both currencies are known; conversion will be exact (no fallback).
    static func canConvert(from source: String, to target: String) -> Bool {
        usdRates[source.uppercased()] != nil && usdRates[target.uppercased()] != nil
    }

    /// Convert an amount from `source` currency to `target`. Returns `nil`
    /// when either side is unknown — callers should treat that as "don't
    /// include this expense in the aggregate" rather than guessing.
    static func convert(_ amount: Double, from source: String, to target: String) -> Double? {
        let s = source.uppercased(), t = target.uppercased()
        if s == t { return amount }
        guard let sRate = usdRates[s], let tRate = usdRates[t] else { return nil }
        let inUSD = amount / sRate
        return inUSD * tRate
    }

    /// Convenience for the common workspace path: convert an expense's
    /// amount to the workspace's default currency. Returns the original
    /// amount unchanged when source == target.
    static func convertToDefault(amount: Double, currency: String, defaultCurrency: String) -> Double? {
        convert(amount, from: currency, to: defaultCurrency)
    }
}
