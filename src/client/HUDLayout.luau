--!strict
-- Input is the ScreenGui safe area, after Roblox has applied device insets.
local HUDLayout = {}

function HUDLayout.calculate(width: number, height: number)
	assert(width > 0 and height > 0, "HUD requires a positive safe area")
	local scale = math.min(math.clamp(width / 700, 0.75, 1.1), width / 452, height / 372)
	local canvasWidth, canvasHeight = width / scale, height / scale
	local compact = canvasHeight < 560
	return {
		scale = scale,
		width = canvasWidth,
		height = canvasHeight,
		compact = compact,
		topHeight = if compact then 100 else 130,
		menuY = if compact then 124 else 154,
		attackY = canvasHeight - 236,
		potionY = canvasHeight - 220,
	}
end

return table.freeze(HUDLayout)
