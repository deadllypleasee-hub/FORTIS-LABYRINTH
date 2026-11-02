--!strict
-- Park-Miller PRNG: deterministic in Roblox, Luau CLI and Lune.
-- The largest intermediate integer is below 2^53.
local Random = {}
Random.__index = Random

function Random.new(seed: number)
	assert(seed == seed and math.abs(seed) < math.huge, "seed must be finite")
	return setmetatable({ state = math.floor(math.abs(seed)) % 2147483646 + 1 }, Random)
end

function Random:nextInteger(minimum: number, maximum: number): number
	assert(minimum <= maximum, "invalid random range")
	self.state = (self.state * 48271) % 2147483647
	return minimum + self.state % (maximum - minimum + 1)
end

return Random
