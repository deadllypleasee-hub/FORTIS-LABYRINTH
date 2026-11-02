--!strict
local RunRules = {}

function RunRules.canStart(status: string): boolean
	return status == "Hub"
end

function RunRules.canComplete(status: string, aliveEnemies: number, distance: number): boolean
	return status == "Active" and aliveEnemies == 0 and distance >= 0 and distance <= 12
end

function RunRules.canAct(status: string, health: number): boolean
	return status == "Active" and health > 0
end

return table.freeze(RunRules)
