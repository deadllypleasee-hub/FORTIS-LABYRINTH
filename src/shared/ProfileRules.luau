--!strict
local ProfileRules = {}

export type Profile = {
	version: number,
	coins: number,
	kills: number,
	deaths: number,
	bestFloor: number,
	completedFloors: number,
	potions: number,
	rewards: { string },
}

function ProfileRules.new(): Profile
	return {
		version = 1,
		coins = 0,
		kills = 0,
		deaths = 0,
		bestFloor = 0,
		completedFloors = 0,
		potions = 3,
		rewards = {},
	}
end

local function integer(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(math.floor(value), 0, 1000000000)
end

function ProfileRules.normalize(raw: any): Profile
	local profile = ProfileRules.new()
	if type(raw) ~= "table" then
		return profile
	end
	for _, field in { "coins", "kills", "deaths", "bestFloor", "completedFloors", "potions" } do
		(profile :: any)[field] = integer(raw[field], (profile :: any)[field])
	end
	profile.bestFloor = math.min(profile.bestFloor, 25)
	if type(raw.rewards) == "table" then
		for _, id in raw.rewards do
			if type(id) == "string" and #id <= 100 and #profile.rewards < 128 then
				table.insert(profile.rewards, id)
			end
		end
	end
	return profile
end

-- Reward IDs are created by the server. The ledger bounds the saved profile.
function ProfileRules.reward(profile: Profile, rewardId: string, coins: number): boolean
	if #rewardId == 0 or #rewardId > 100 or coins < 0 or coins % 1 ~= 0 or coins ~= coins or coins > 100000 then
		return false
	end
	if table.find(profile.rewards, rewardId) then
		return false
	end
	table.insert(profile.rewards, rewardId)
	if #profile.rewards > 128 then
		table.remove(profile.rewards, 1)
	end
	profile.coins = math.min(profile.coins + coins, 1000000000)
	return true
end

return table.freeze(ProfileRules)
