--[=[
	The lua implementation of the fzy string matching algorithm. This algorithm
	is optimized for matching stuff on the terminal, but should serve well as a
	baseline search algorithm within a game too.

	See:
	* https://github.com/swarn/fzy-lua
	* https://github.com/jhawthorn/fzy/blob/master/ALGORITHM.md

	Modified from the initial code to fit this codebase. While this
	definitely messes with some naming which may have been better, it
	also keeps usage of this library consistent with other libraries.

	Notes:
	* A higher score is better than a lower score
	* Scoring time is `O(n*m)` where `n` is the length of the needle
	  and `m` is the length of the haystack.
	* Scoring memory is also `O(n*m)`
	* Should do quite well with small lists

	TODO: Support UTF8

	@class Fzy
]=]

--[[
The MIT License (MIT)

Copyright (c) 2020 Seth Warn

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

local MAX_SCORE = math.huge
local MIN_SCORE = -math.huge

local Fzy = {}

--[=[
	Configuration for Fzy. See [Fzy.CreateConfig] for details. This affects scoring
	and how the matching is done.

	@interface FzyConfig
	.CapitalMatchScore number
	.CaseSensitive boolean
	.ConsecutiveMatchScore number
	.DotMatchScore number
	.GapInnerScore number
	.GapLeadingScore number
	.GapTrailingScore number
	.MaxMatchLength number
	.SlashMatchScore number
	.WordMatchScore number
	@within Fzy
]=]

--[=[
	Creates a new configuration for Fzy.

	@param config table
	@return FzyConfig
]=]
function Fzy.CreateConfig(config)
	assert(config == nil or type(config) == "table", "Bad config")

	config = config or {}

	if config.CaseSensitive == nil then
		config.CaseSensitive = false
	elseif type(config.CaseSensitive) ~= "boolean" then
		error("Bad config.CaseSensitive")
	end

	-- These numbers are from the Fzy, algorithm but may be adjusted
	config.GapLeadingScore = config.GapLeadingScore or -0.005
	config.GapTrailingScore = config.GapTrailingScore or -0.005
	config.GapInnerScore = config.GapInnerScore or -0.01
	config.ConsecutiveMatchScore = config.ConsecutiveMatchScore or 1
	config.SlashMatchScore = config.SlashMatchScore or 0.9
	config.WordMatchScore = config.WordMatchScore or 0.8
	config.CapitalMatchScore = config.CapitalMatchScore or 0.7
	config.DotMatchScore = config.DotMatchScore or 0.6
	config.MaxMatchLength = config.MaxMatchLength or 1024

	return config
end

--[=[
	Returns true if it is a config

	@param config any
	@return boolean
]=]
function Fzy.IsFzyConfig(config)
	return type(config) == "table"
		and type(config.CapitalMatchScore) == "number"
		and type(config.CaseSensitive) == "boolean"
		and type(config.ConsecutiveMatchScore) == "number"
		and type(config.DotMatchScore) == "number"
		and type(config.GapInnerScore) == "number"
		and type(config.GapLeadingScore) == "number"
		and type(config.GapTrailingScore) == "number"
		and type(config.MaxMatchLength) == "number"
		and type(config.SlashMatchScore) == "number"
		and type(config.WordMatchScore) == "number"
end

--[=[
	Check if `needle` is a subsequence of the `haystack`.

	Usually called before [Fzy.Score] or [Fzy.Positions].

	@param config FzyConfig
	@param needle string
	@param haystack string
	@return boolean
]=]
function Fzy.HasMatch(config, needle: string, haystack: string)
	if not config.CaseSensitive then
		needle = string.lower(needle)
		haystack = string.lower(haystack)
	end

	local jndex = 1
	for index = 1, #needle do
		jndex = string.find(haystack, string.sub(needle, index, index), jndex, true)
		if not jndex then
			return false
		else
			jndex += 1
		end
	end

	return true
end

local function preComputeBonus(config, haystack: string)
	local size = #haystack
	local matchBonus = table.create(size)
	local lastByte = 47

	for index = 1, size do
		local thisByte = string.byte(haystack, index, index)
		if lastByte == 47 or lastByte == 92 then
			matchBonus[index] = config.SlashMatchScore
		elseif lastByte == 45 or (lastByte == 95 or lastByte == 32) then
			matchBonus[index] = config.WordMatchScore
		elseif lastByte == 46 then
			matchBonus[index] = config.DotMatchScore
		elseif lastByte >= 97 and lastByte <= 122 and thisByte >= 65 and thisByte <= 90 then
			matchBonus[index] = config.CapitalMatchScore
		else
			matchBonus[index] = 0
		end

		lastByte = thisByte
	end

	return matchBonus
end

local function compute(config, needle: string, haystack: string, D, M)
	-- Note that the match bonuses must be computed before the arguments are
	-- converted to lowercase, since there are bonuses for camelCase.

	local matchBonus = preComputeBonus(config, haystack)
	local needleLength = #needle
	local haystackLength = #haystack

	if not config.CaseSensitive then
		needle = string.lower(needle)
		haystack = string.lower(haystack)
	end

	-- Because lua only grants access to chars through substring extraction,
	-- get all the characters from the haystack once now, to reuse below.
	local haystackCharacters = string.split(haystack, "")

	for index = 1, needleLength do
		D[index] = table.create(haystackLength)
		M[index] = table.create(haystackLength)

		local previousScore = MIN_SCORE
		local gapScore = index == needleLength and config.GapTrailingScore or config.GapInnerScore
		local needleCharacter = string.sub(needle, index, index)

		for jndex = 1, haystackLength do
			if needleCharacter == haystackCharacters[jndex] then
				local score = MIN_SCORE
				if index == 1 then
					score = (jndex - 1) * config.GapLeadingScore + matchBonus[jndex]
				elseif jndex > 1 then
					local scoreA = M[index - 1][jndex - 1] + matchBonus[jndex]
					local scoreB = D[index - 1][jndex - 1] + config.ConsecutiveMatchScore
					score = math.max(scoreA, scoreB)
				end

				D[index][jndex] = score
				previousScore = math.max(score, previousScore + gapScore)
				M[index][jndex] = previousScore
			else
				D[index][jndex] = MIN_SCORE
				previousScore += gapScore
				M[index][jndex] = previousScore
			end
		end
	end
end

--[=[
	Computes whether a needle or haystack are a perfect match or not

	@param config FzyConfig
	@param needle string -- must be a subsequence of `haystack`, or the result is undefined.
	@param haystack string
	@return boolean
]=]
function Fzy.IsPerfectMatch(config, needle, haystack)
	if config.CaseSensitive then
		return needle == haystack
	else
		return string.lower(needle) == string.lower(haystack)
	end
end

--[=[
	Compute a matching score.

	@param config FzyConfig
	@param needle string -- must be a subsequence of `haystack`, or the result is undefined.
	@param haystack string
	@return number -- higher scores indicate better matches. See also [Fzy.GetMinScore] and [Fzy.GetMaxScore].
]=]
function Fzy.Score(config, needle: string, haystack: string): number
	local needleLength = #needle
	local haystackLength = #haystack

	if
		needleLength == 0
		or haystackLength == 0
		or haystackLength > config.MaxMatchLength
		or needleLength > haystackLength
	then
		return MIN_SCORE
	elseif Fzy.IsPerfectMatch(config, needle, haystack) then
		return MAX_SCORE
	else
		local D = {}
		local M = {}
		compute(config, needle, haystack, D, M)
		return M[needleLength][haystackLength]
	end
end

--[=[
	Compute the locations where fzy matches a string.

	Determine where each character of the `needle` is matched to the `haystack`
	in the optimal match.

	@param config FzyConfig
	@param needle string -- must be a subsequence of `haystack`, or the result is undefined.
	@param haystack string
	@return { int } -- indices, where `indices[n]` is the location of the `n`th character of `needle` in `haystack`.
	@return number -- the same matching score returned by `score`
]=]
function Fzy.Positions(config, needle: string, haystack: string)
	local needleLength = #needle
	local haystackLength = #haystack

	if
		needleLength == 0
		or haystackLength == 0
		or haystackLength > config.MaxMatchLength
		or needleLength > haystackLength
	then
		return {}, MIN_SCORE
	elseif Fzy.IsPerfectMatch(config, needle, haystack) then
		local consecutive = table.create(needleLength)
		for index = 1, needleLength do
			consecutive[index] = index
		end

		return consecutive, MAX_SCORE
	end

	local D = {}
	local M = {}
	compute(config, needle, haystack, D, M)

	local positions = table.create(needleLength)
	local match_required = false
	local jndex = haystackLength
	for index = needleLength, 1, -1 do
		while jndex >= 1 do
			if D[index][jndex] ~= MIN_SCORE and (match_required or D[index][jndex] == M[index][jndex]) then
				match_required = index ~= 1
					and jndex ~= 1
					and M[index][jndex] == D[index - 1][jndex - 1] + config.ConsecutiveMatchScore

				positions[index] = jndex
				jndex -= 1
				break
			else
				jndex -= 1
			end
		end
	end

	return positions, M[needleLength][haystackLength]
end

--[=[
	Apply [Fzy.HasMatch] and [Fzy.Positions] to an array of haystacks.

	Returns an array with one entry per matching line in `haystacks`,
	each entry giving the index of the line in `haystacks` as well as
	the equivalent to the return value of `positions` for that line.

	@param config FzyConfig
	@param needle string
	@param haystacks { string }
	@return {{idx, positions, score}, ...}
]=]
function Fzy.Filter(config, needle: string, haystacks: {string})
	local result = {}
	local length = 0

	for index, line in haystacks do
		if Fzy.HasMatch(config, needle, line) then
			local position, score = Fzy.Positions(config, needle, line)
			length += 1
			result[length] = {index, position, score}
		end
	end

	return result
end

export type IFilterResult = {
	Index: number,
	Positions: {number},
	Score: number,
	String: string,
}

function Fzy.BetterFilter(config, needle: string, haystacks: {string}): {IFilterResult}
	local result = {}
	local length = 0

	for index, line in haystacks do
		if Fzy.HasMatch(config, needle, line) then
			local positions, score = Fzy.Positions(config, needle, line)
			length += 1
			result[length] = {
				Index = index;
				Positions = positions;
				Score = score;
				String = haystacks[index];
			}
		end
	end

	return result
end

--[=[
	The lowest value returned by `score`.

	In two special cases:
	 - an empty `needle`, or
	 - a `needle` or `haystack` larger than than [Fzy.GetMaxLength],

	the [Fzy.Score] function will return this exact value, which can be used as a
	sentinel. This is the lowest possible score.

	@return number
]=]
function Fzy.GetMinScore(): number
	return MIN_SCORE
end

--[=[
	The score returned for exact matches. This is the highest possible score.

	@return number
]=]
function Fzy.GetMaxScore(): number
	return MAX_SCORE
end

--[=[
	The maximum size for which `fzy` will evaluate scores.

	@param config FzyConfig
	@return number
]=]
function Fzy.GetMaxLength(config): number
	assert(Fzy.IsFzyConfig(config), "Bad config")

	return config.MaxMatchLength
end

--[=[
	The minimum score returned for normal matches.

	For matches that don't return [Fzy.GetMinScore], their score will be greater
	than than this value.

	@param config FzyConfig
	@return number
]=]
function Fzy.GetScoreFloor(config): number
	assert(Fzy.IsFzyConfig(config), "Bad config")

	return config.MaxMatchLength * config.GapInnerScore
end

--[=[
	The maximum score for non-exact matches.

	For matches that don't return [Fzy.GetMaxScore], their score will be less than
	this value.

	@param config FzyConfig
	@return number
]=]
function Fzy.GetScoreCeiling(config): number
	assert(Fzy.IsFzyConfig(config), "Bad config")

	return config.MaxMatchLength * config.ConsecutiveMatchScore
end

table.freeze(Fzy)
return Fzy
