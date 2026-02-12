-- numfmt: Number and time formatting for Roblox

-- Types

export type TimeFormat = "hms" | "ms" | "dhms"

-- Constants

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local ROMAN_MAP = {
	{ 1000, "M" },
	{ 900, "CM" },
	{ 500, "D" },
	{ 400, "CD" },
	{ 100, "C" },
	{ 90, "XC" },
	{ 50, "L" },
	{ 40, "XL" },
	{ 10, "X" },
	{ 9, "IX" },
	{ 5, "V" },
	{ 4, "IV" },
	{ 1, "I" },
}

-- State

local localeCache: {
	[string]: {
		locTable: any,
		translator: any,
		separator: string?,
	},
} = {}
local cachedPlayerLocale: string? = nil

-- Private Helpers

local function formatSpecial(num: number): string?
	if num ~= num then
		return "NaN"
	end
	if num == math.huge then
		return "inf"
	end
	if num == -math.huge then
		return "-inf"
	end
	return nil
end

local function getPlayerLocale(): string?
	if cachedPlayerLocale then
		return cachedPlayerLocale
	end
	local ok, player = pcall(function()
		return (game :: any):GetService("Players").LocalPlayer
	end)
	if ok and player then
		cachedPlayerLocale = player.LocaleId
		return cachedPlayerLocale
	end
	return nil
end

local function insertCommas(str: string): string
	local result = ""
	local len = #str
	for i = 1, len do
		if i > 1 and (len - i + 1) % 3 == 0 then
			result ..= ","
		end
		result ..= str:sub(i, i)
	end
	return result
end

-- Module

local numfmt = {}

--[=[
	Formats a number with commas (thousands separators).

	If a locale is provided (or auto-detected on the client), uses Roblox's
	LocalizationService for locale-aware formatting. Otherwise falls back to
	standard comma formatting.

	```luau
	numfmt.commas(1234567)           --> "1,234,567"
	numfmt.commas(1234567.89)        --> "1,234,567.89"
	numfmt.commas(1234567, "en-us")  --> locale-aware formatting
	```

	@param num -- The number to format.
	@param locale -- Optional locale identifier (e.g. "en-us").
	@return The formatted string.
]=]
function numfmt.commas(num: number, locale: string?): string
	local special = formatSpecial(num)
	if special then
		return special
	end

	if num < 0 then
		return "-" .. numfmt.commas(-num, locale)
	end

	-- Try to auto-detect locale on client
	if locale == nil then
		locale = getPlayerLocale()
	end

	-- Locale-aware path via Roblox LocalizationService
	if locale then
		local ok, result = pcall(function()
			local cache = localeCache[locale]
			if cache == nil then
				local locTable = Instance.new("LocalizationTable")
				locTable:SetEntries({
					{
						Key = "Num",
						Source = "{Val:num}",
						Values = { [locale] = "{Val:num}" },
					},
				})
				local translator = locTable:GetTranslator(locale)

				-- Detect the decimal separator for this locale
				local testStr = translator:FormatByKey("Num", { Val = 1.5 })
				local separator = testStr:match("1(.)5")

				cache = {
					locTable = locTable,
					translator = translator,
					separator = separator,
				}
				localeCache[locale] = cache
			end

			local raw: string = cache.translator:FormatByKey("Num", { Val = num })

			if num ~= math.floor(num) then
				-- Has fractional part: strip trailing zeroes after decimal separator
				local sep = cache.separator
				if sep and raw:find(sep, 1, true) then
					raw = raw:gsub("0+$", "")
					raw = raw:gsub("%" .. sep .. "$", "")
				end
				return raw
			else
				-- Whole number: strip the decimal portion appended by the locale
				local sep = cache.separator
				if sep then
					local sepPos = raw:find(sep, 1, true)
					if sepPos then
						return raw:sub(1, sepPos - 1)
					end
				end
				return raw
			end
		end)

		if ok then
			return result
		else
			warn("[numfmt] Locale formatting failed: " .. tostring(result))
		end
	end

	-- Manual fallback: standard comma formatting
	local whole, frac = math.modf(num)
	local wholeStr = tostring(math.floor(whole))

	-- If tostring produced scientific notation, return as-is
	if wholeStr:find("e", 1, true) then
		return tostring(num)
	end

	local str = insertCommas(wholeStr)

	if frac ~= 0 then
		-- Preserve original decimal precision from tostring
		local fullStr = tostring(num)
		local dotPos = fullStr:find("%.")
		if dotPos then
			str ..= fullStr:sub(dotPos)
		end
	end

	return str
end

--[=[
	Formats a number with a metric suffix (e.g. "1.5K", "2.3M").

	Suffixes: K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc (up to 10^36).

	```luau
	numfmt.metric(1500)              --> "1.5K"
	numfmt.metric(2500000, 2)        --> "2.5M"
	numfmt.metric(999950, 3, true)   --> "1M"
	```

	@param num -- The number to format.
	@param places -- Number of significant digits (default 3).
	@param roundUp -- Round up instead of flooring (default false).
	@return The formatted metric string.
]=]
function numfmt.metric(num: number, places: number?, roundUp: boolean?): string
	local special = formatSpecial(num)
	if special then
		return special
	end

	if num == 0 then
		return "0"
	end

	if num < 0 then
		return "-" .. numfmt.metric(-num, places, roundUp)
	end

	if num < 1 then
		return tostring(num)
	end

	local sf = places or 3

	local len = math.floor(math.log10(num))
	local tier = math.min(math.floor(len / 3), #SUFFIXES)

	if tier <= 0 then
		return tostring(math.floor(num))
	end

	-- Scale down to the tier and truncate/round to the desired significant figures
	local divisor = 10 ^ (tier * 3)
	local scaled = num / divisor

	local scaledDigits = math.floor(math.log10(scaled)) + 1
	local decPlaces = math.max(0, sf - scaledDigits)
	local factor = 10 ^ decPlaces
	local mathFn = if roundUp then math.ceil else math.floor
	scaled = mathFn(scaled * factor) / factor

	-- Handle overflow after rounding (e.g. 999.9K rounding up to 1000K -> 1M)
	if scaled >= 1000 and tier < #SUFFIXES then
		tier += 1
		scaled /= 1000
	end

	-- Format the scaled number, avoiding unnecessary trailing ".0"
	local str: string
	if scaled == math.floor(scaled) then
		str = tostring(math.floor(scaled))
	else
		str = tostring(scaled)
	end

	return str .. SUFFIXES[tier]
end

--[=[
	Formats a duration in seconds as a time string.

	When no format is specified, automatically picks the best format based on
	the magnitude of the value:
	- Under 1 hour: M:SS
	- 1 hour to 24 hours: H:MM:SS
	- 24 hours and above: natural language ("1 Day 2 Hours")

	A specific format can be forced by passing `"ms"`, `"hms"`, or `"dhms"`.

	```luau
	numfmt.time(61)              --> "1:01"
	numfmt.time(3661)            --> "1:01:01"
	numfmt.time(90061)           --> "1 Day 1 Hour"
	numfmt.time(3661, "hms")     --> "1:01:01"
	numfmt.time(61, "ms")        --> "1:01"
	numfmt.time(90061, "dhms")   --> "01:01:01:01"
	```

	@param seconds -- The duration in seconds.
	@param format -- Optional format: "ms", "hms", or "dhms".
	@return The formatted time string.
]=]
function numfmt.time(seconds: number, format: TimeFormat?): string
	local special = formatSpecial(seconds)
	if special then
		return special
	end

	if seconds < 0 then
		return "-" .. numfmt.time(-seconds, format)
	end

	if format == "ms" then
		local m = math.floor(seconds / 60)
		local s = math.floor(seconds) % 60
		return string.format("%i:%02i", m, s)
	elseif format == "hms" then
		local h = math.floor(seconds / 3600)
		local m = math.floor(seconds / 60) % 60
		local s = math.floor(seconds) % 60
		return string.format("%i:%02i:%02i", h, m, s)
	elseif format == "dhms" then
		local d = math.floor(seconds / 86400)
		local h = math.floor(seconds / 3600) % 24
		local m = math.floor(seconds / 60) % 60
		local s = math.floor(seconds) % 60
		return string.format("%02i:%02i:%02i:%02i", d, h, m, s)
	end

	-- Adaptive: pick the best format based on magnitude
	if seconds >= 86400 then
		local days = math.floor(seconds / 86400)
		local hours = math.floor((seconds % 86400) / 3600)

		local daysLabel = if days == 1 then "Day" else "Days"
		local hoursLabel = if hours == 1 then "Hour" else "Hours"

		return `{numfmt.commas(days)} {daysLabel} {numfmt.commas(hours)} {hoursLabel}`
	elseif seconds >= 3600 then
		return numfmt.time(seconds, "hms")
	else
		return numfmt.time(seconds, "ms")
	end
end

--[=[
	Converts a number to Roman numerals.

	Supports values from 1 to 3999 (standard Roman numeral range).
	Values outside this range are floored; 0 returns "0".

	```luau
	numfmt.roman(42)     --> "XLII"
	numfmt.roman(2025)   --> "MMXXV"
	```

	@param num -- The number to convert.
	@return The Roman numeral string.
]=]
function numfmt.roman(num: number): string
	local special = formatSpecial(num)
	if special then
		return special
	end

	if num < 0 then
		return "-" .. numfmt.roman(-num)
	end

	num = math.floor(num)
	if num == 0 then
		return "0"
	end

	local result = ""
	for _, pair in ROMAN_MAP do
		local value = pair[1]
		local symbol = pair[2]
		while num >= value do
			result ..= symbol
			num -= value
		end
	end

	return result
end

export type numfmt = typeof(numfmt)

return numfmt
