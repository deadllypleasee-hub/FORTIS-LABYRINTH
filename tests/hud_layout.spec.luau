local Layout = require("../src/client/HUDLayout")

return function(test)
	test("HUD: modal and touch targets fit portrait and landscape safe areas", function()
		for _, viewport in
			{ { 320, 568 }, { 360, 640 }, { 412, 860 }, { 568, 280 }, { 640, 320 }, { 800, 360 }, { 1920, 1000 } }
		do
			local width, height = viewport[1], viewport[2]
			local layout = Layout.calculate(width, height)
			assert(420 * layout.scale <= width - 16, "modal exceeds safe width")
			assert(340 * layout.scale <= height - 16, "modal exceeds safe height")
			assert(64 * layout.scale >= 44, "menu or close touch target is too small")
			assert(layout.attackY >= 12 + layout.topHeight, "attack overlaps header")
			assert((layout.attackY + 86) * layout.scale <= height - 100, "attack overlaps default jump area")
			assert(layout.potionY >= 12 + layout.topHeight, "potion overlaps header")
		end
	end)

	test("HUD: short landscape menu stays left of combat controls", function()
		for _, viewport in { { 568, 280 }, { 640, 320 }, { 800, 360 } } do
			local layout = Layout.calculate(viewport[1], viewport[2])
			assert(layout.compact)
			assert(16 + 292 < layout.width - 196, "menu overlaps potion control")
			assert(layout.menuY >= layout.topHeight + 12)
		end
	end)
end
