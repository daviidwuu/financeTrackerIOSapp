import Testing
@testable import FinanceTracker

// MARK: - DecimalPrecision Tests
// These tests verify that financial math uses Decimal internally and avoids
// floating-point drift that would occur with naive Double arithmetic.

@Suite struct DecimalPrecisionTests {

    // MARK: - round

    @Test("round: exact cents are preserved")
    func test_round_exactCents_unchanged() {
        #expect(DecimalPrecision.round(1.23) == 1.23)
        #expect(DecimalPrecision.round(0.10) == 0.10)
        #expect(DecimalPrecision.round(99.99) == 99.99)
    }

    @Test("round: sub-cent values are rounded to 2 decimal places")
    func test_round_subCent_roundsCorrectly() {
        // 1.005 should round up to 1.01 (plain rounding)
        #expect(DecimalPrecision.round(1.005) == 1.01)
        // 1.004 should round down to 1.00
        #expect(DecimalPrecision.round(1.004) == 1.00)
    }

    @Test("round: negative amounts round symmetrically")
    func test_round_negative_roundsCorrectly() {
        #expect(DecimalPrecision.round(-9.995) == -10.00)
        #expect(DecimalPrecision.round(-0.004) == 0.00)
    }

    @Test("round: zero is preserved")
    func test_round_zero() {
        #expect(DecimalPrecision.round(0.0) == 0.0)
    }

    // MARK: - sum

    @Test("sum: classic floating-point trap does not cause drift")
    func test_sum_floatingPointTrap_noDrift() {
        // 0.1 + 0.2 == 0.30000000000000004 in Double arithmetic.
        // DecimalPrecision.sum must produce exactly 0.30.
        let result = DecimalPrecision.sum([0.1, 0.2])
        #expect(result == 0.30)
    }

    @Test("sum: repeated small additions accumulate correctly")
    func test_sum_repeatedAdditions_accurate() {
        // 100 × 0.10 should be exactly 10.00, not 9.999999999... or 10.000000001
        let values = Array(repeating: 0.10, count: 100)
        let result = DecimalPrecision.sum(values)
        #expect(result == 10.00)
    }

    @Test("sum: empty array returns zero")
    func test_sum_emptyArray_returnsZero() {
        #expect(DecimalPrecision.sum([]) == 0.0)
    }

    @Test("sum: single negative value is returned correctly")
    func test_sum_singleNegative() {
        #expect(DecimalPrecision.sum([-42.55]) == -42.55)
    }

    @Test("sum: mixed income and expense amounts net correctly")
    func test_sum_mixedSignAmounts() {
        // Income 300, expenses -120.50 and -79.50 → net 100.00
        let result = DecimalPrecision.sum([300.0, -120.50, -79.50])
        #expect(result == 100.00)
    }

    // MARK: - subtract

    @Test("subtract: basic subtraction is exact")
    func test_subtract_basic() {
        #expect(DecimalPrecision.subtract(10.00, 3.50) == 6.50)
    }

    @Test("subtract: floating-point trap case is handled")
    func test_subtract_floatingPointTrap() {
        // 0.3 - 0.1 == 0.19999999999999998 in Double; must be 0.20
        #expect(DecimalPrecision.subtract(0.3, 0.1) == 0.20)
    }

    @Test("subtract: result can be negative")
    func test_subtract_resultNegative() {
        #expect(DecimalPrecision.subtract(5.00, 8.00) == -3.00)
    }

    // MARK: - multiply

    @Test("multiply: simple multiplication is exact")
    func test_multiply_simple() {
        #expect(DecimalPrecision.multiply(3.00, 4.00) == 12.00)
    }

    @Test("multiply: fractional result rounds to 2 decimal places")
    func test_multiply_fractionalResult() {
        // 1.005 × 100 = 100.50
        #expect(DecimalPrecision.multiply(1.005, 100.0) == 100.50)
    }

    @Test("multiply: multiplying by zero returns zero")
    func test_multiply_byZero() {
        #expect(DecimalPrecision.multiply(999.99, 0.0) == 0.0)
    }

    // MARK: - divide

    @Test("divide: basic division is correct")
    func test_divide_basic() {
        #expect(DecimalPrecision.divide(10.0, 3.0) == 3.33)
    }

    @Test("divide: equal split of $10 among 3 people rounds to cent")
    func test_divide_equalSplit_roundsToCent() {
        // 10 / 3 = 3.3333... → 3.33
        let share = DecimalPrecision.divide(10.0, 3.0)
        #expect(share == 3.33)
    }

    @Test("divide: dividing by zero returns zero (safe guard)")
    func test_divide_byZero_returnsZero() {
        #expect(DecimalPrecision.divide(100.0, 0.0) == 0.0)
    }

    @Test("divide: $1 split 4 ways is exactly $0.25 per person")
    func test_divide_exactSplit() {
        #expect(DecimalPrecision.divide(1.0, 4.0) == 0.25)
    }
}
