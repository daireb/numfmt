# numfmt

Number and time formatting for Roblox.

## Installation

```sh
pesde add gh#daireb/numfmt
```

```luau
local numfmt = require(path.to.numfmt)
```

## API

### `numfmt.commas(num, locale?)`

Formats a number with thousands separators. On the client, automatically uses the player's locale for locale-aware formatting. On the server, falls back to standard commas. You can also pass a locale explicitly.

```luau
numfmt.commas(1234567)           --> "1,234,567"
numfmt.commas(1234567.89)        --> "1,234,567.89"
numfmt.commas(1234567, "en-us")  --> locale-aware formatting
```

### `numfmt.metric(num, places?, roundUp?)`

Formats a number with a metric suffix. Uses standard short-scale abbreviations: K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc (up to 10^36).

- `places` controls the number of significant digits (default `3`).
- `roundUp` rounds up instead of flooring when `true`.

```luau
numfmt.metric(1500)              --> "1.5K"
numfmt.metric(2500000)           --> "2.5M"
numfmt.metric(2500000, 2)        --> "2.5M"
numfmt.metric(999950, 3, true)   --> "1M"
numfmt.metric(0)                 --> "0"
```

### `numfmt.time(seconds, format?)`

Formats a duration in seconds as a time string.

When no format is given, automatically picks the best representation:

| Range | Output style |
|---|---|
| Under 1 hour | `M:SS` |
| 1 hour to 24 hours | `H:MM:SS` |
| 24 hours and above | Natural language (`"1 Day 2 Hours"`) |

Pass `"ms"`, `"hms"`, or `"dhms"` to force a specific format.

```luau
numfmt.time(61)              --> "1:01"
numfmt.time(3661)            --> "1:01:01"
numfmt.time(90061)           --> "1 Day 1 Hour"
numfmt.time(3661, "hms")     --> "1:01:01"
numfmt.time(61, "ms")        --> "1:01"
numfmt.time(90061, "dhms")   --> "01:01:01:01"
```

### `numfmt.roman(num)`

Converts a number to Roman numerals. Supports values from 1 to 3999 (standard range). The input is floored to an integer; 0 returns `"0"`.

```luau
numfmt.roman(42)     --> "XLII"
numfmt.roman(2025)   --> "MMXXV"
numfmt.roman(3999)   --> "MMMCMXCIX"
```

## Edge Cases

All functions handle `math.huge`, `-math.huge`, and `NaN` consistently:

```luau
numfmt.metric(math.huge)   --> "inf"
numfmt.metric(-math.huge)  --> "-inf"
numfmt.metric(0/0)         --> "NaN"
```

Negative numbers are supported across all functions.

## License

MIT
