--!strict
-- Set only these two IDs after creating both Places in the SAME Experience.
return table.freeze({
	Version = "0.1.0",
	HubPlaceId = 0,
	DungeonPlaceId = 0,
	EnablePersistence = true, -- Studio always uses session data; published servers use DataStore
	FloorReward = 35,
	KillReward = 10,
	ChestReward = 20,
	PotionHealing = 40,
	StartingPotions = 3,
	MaxFloor = 1, -- stage 1: only the first floor is playable
	AdminUserIds = {},
})
