# Amounts are decimal strings

Every monetary amount, quantity and VAT rate in extraction schemas, stored extraction results and API responses is a decimal string (`"1234.56"`), constrained by a JSON Schema `pattern`, never a JSON number. JSON numbers become binary floats in JavaScript clients and in Ruby unless parsed specially, and ActiveSupport already serialises `BigDecimal` as a string, so numbers would not survive the round trip consistently. Business rules parse the strings with `BigDecimal`. VAT rates are percentages (`"21"` means 21%).

## Considered Options

- **JSON numbers parsed as `BigDecimal`**: works inside Ruby, but loses precision in the TypeScript companion and any other JavaScript client.
- **Integer minor units** (Stripe style): exact, but quantities and VAT rates are not money, and the model would have to convert printed amounts, which invites arithmetic errors.
