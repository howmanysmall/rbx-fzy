/**
 * # Fzy
 *
 * The Luau implementation of the fzy string matching algorithm. This algorithm
 * is optimized for matching stuff on the terminal, but should serve well as a
 * baseline search algorithm within a game too.
 *
 * @see https://github.com/swarn/fzy-lua
 * @see https://github.com/jhawthorn/fzy/blob/master/ALGORITHM.md
 *
 * Modified from the initial code to fit this codebase. While this
 * definitely messes with some naming which may have been better, it
 * also keeps usage of this library consistent with other libraries.
 *
 * ### Notes:
 * * A higher score is better than a lower score
 * * Scoring time is `O(n*m)` where `n` is the length of the needle
 * 	and `m` is the length of the haystack.
 * * Scoring memory is also `O(n*m)`
 * * Should do quite well with small lists
 */
declare namespace Fzy {
	/**
	 * Configuration for Fzy. See {@link CreateConfig} for details. This affects scoring
	 * and how the matching is done.
	 */
	export interface FzyConfig {
		CapitalMatchScore: number;
		CaseSensitive: boolean;
		ConsecutiveMatchScore: number;
		DotMatchScore: number;
		GapInnerScore: number;
		GapLeadingScore: number;
		GapTrailingScore: number;
		MaxMatchLength: number;
		SlashMatchScore: number;
		WordMatchScore: number;
	}

	/**
	 * Creates a new configuration for Fzy.
	 * @param config
	 */
	export function CreateConfig(config?: Partial<FzyConfig>): FzyConfig;

	/**
	 * Returns true if it is a config
	 * @param config
	 */
	export function IsFzyConfig(config: unknown): config is FzyConfig;

	/**
	 * Check if `needle` is a subsequence of the `haystack`.
	 *
	 * Usually called before {@link Score} or {@link Positions}.
	 *
	 * @param config
	 * @param needle
	 * @param haystack
	 */
	export function HasMatch(config: FzyConfig, needle: string, haystack: string): boolean;

	/**
	 * Computes whether `needle` or `haystack` are a perfect match or not.
	 * @param config
	 * @param needle
	 * @param haystack
	 */
	export function IsPerfectMatch(config: FzyConfig, needle: string, haystack: string): boolean;

	/**
	 * Compute a matching score.
	 * @param config
	 * @param needle Must be a subsequence of `haystack`, or the result is undefined.
	 * @param haystack
	 * @returns Higher scores indicate better matches. See also {@link GetMinScore} and {@link GetMaxScore}.
	 */
	export function Score(config: FzyConfig, needle: string, haystack: string): number;

	/**
	 * Compute the locations where Fzy matches a string.
	 *
	 * Determine where each character of the `needle` is matched to the `haystack`
	 * in the optimal match.
	 *
	 * @param config
	 * @param needle Must be a subsequence of `haystack`, or the result is undefined.
	 * @param haystack
	 *
	 * @returns A tuple, where the first element is the indices, where `indices[n]` is the location of the `n`th character of `needle` in `haystack`, and the second element is the same matching score returned by the score function.
	 */
	export function Positions(
		config: FzyConfig,
		needle: string,
		haystack: string,
	): LuaTuple<[positions: Array<number>, score: number]>;

	/**
	 * Apply {@link HasMatch} and {@link Positions} to an array of haystacks.
	 *
	 * Returns an array with one entry per matching line in `haystacks`,
	 * each entry giving the index of the line in `haystacks` as well as
	 * the equivalent to the return value of `positions` for that line.
	 *
	 * @param config
	 * @param needle
	 * @param haystacks
	 */
	export function Filter(
		config: FzyConfig,
		needle: string,
		haystacks: Array<string>,
	): Array<[index: number, positions: Array<number>, score: number]>;

	/**
	 * An interface that is returned from {@link BetterFilter}.
	 */
	export interface FilterResult {
		Index: number;
		Positions: Array<number>;
		Score: number;
		String: string;
	}

	/**
	 * Almost the same as {@link Filter}, but returns an array of {@link FilterResult} instead.
	 * @param config
	 * @param needle
	 * @param haystacks
	 */
	export function BetterFilter(config: FzyConfig, needle: string, haystacks: Array<string>): Array<FilterResult>;

	/**
	 * The lowest value returned by `score`.
	 *
	 * In two special cases:
	 *  - an empty `needle`, or
	 *  - a `needle` or `haystack` larger than than {@link GetMaxLength},
	 *
	 * the {@link Score} function will return this exact value, which can be used as a
	 * sentinel. This is the lowest possible score.
	 */
	export function GetMinScore(): number;

	/**
	 * The score returned for exact matches. This is the highest possible score.
	 */
	export function GetMaxScore(): number;

	/**
	 * The maximum size for which `Fzy` will evaluate scores.
	 *
	 * This function is quite useless, just do `config.MaxMatchLength`.
	 * @param config
	 */
	export function GetMaxLength(config: FzyConfig): number;

	/**
	 * The minimum score returned for normal matches.
	 *
	 * For matches that don't return {@link GetMinScore}, their score will be greater
	 * than this value.
	 *
	 * This function is quite useless, just do `config.MaxMatchLength*config.GapInnerScore`.
	 * @param config
	 */
	export function GetScoreFloor(config: FzyConfig): number;

	/**
	 * The maximum score for non-exact matches.
	 *
	 * For matches that don't return {@link GetMaxScore}, their score will be less than
	 * than this value.
	 *
	 * This function is quite useless, just do `config.MaxMatchLength*config.ConsecutiveMatchScore`.
	 * @param config
	 */
	export function GetScoreCeiling(config: FzyConfig): number;
}

export = Fzy;
