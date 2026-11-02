--!strict
-- Pure, shared calculations. The server is the authority for inputs and results.
local CombatRules = {}

CombatRules.SwordDamage = 28
CombatRules.SwordRange = 10
CombatRules.SwordCooldown = 0.55
CombatRules.SwordMinimumDot = 0.05
CombatRules.EnemyDamage = 12
CombatRules.EnemyRange = 5
CombatRules.EnemyCooldown = 1.25

function CombatRules.isFinite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function CombatRules.withinRange(distance: number, maximum: number): boolean
	return CombatRules.isFinite(distance)
		and CombatRules.isFinite(maximum)
		and distance >= 0
		and maximum >= 0
		and distance <= maximum
end

function CombatRules.cooldownReady(now: number, previous: number?, cooldown: number): boolean
	if not CombatRules.isFinite(now) or not CombatRules.isFinite(cooldown) or cooldown < 0 then
		return false
	end
	if previous == nil then
		return true
	end
	return CombatRules.isFinite(previous) and now - previous >= cooldown
end

function CombatRules.isInFront(dotProduct: number): boolean
	return CombatRules.isFinite(dotProduct) and dotProduct >= CombatRules.SwordMinimumDot
end

function CombatRules.damage(baseDamage: number, armor: number): number
	if not CombatRules.isFinite(baseDamage) or not CombatRules.isFinite(armor) then
		return 0
	end
	return math.max(0, math.floor(math.max(0, baseDamage) * 100 / (100 + math.max(0, armor)) + 0.5))
end

return table.freeze(CombatRules)
