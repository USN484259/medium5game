return {
	coordinate_radix = 0x400,
	layer = {
		bottom = 0,
		background = 0,
		common = 0x40,
		overlay = 0x80,
		hud = 0xC0,
		top = 0x100,
--[[
		grid = 1,
		effect_under = 2,
		entity = 3,
		effect_over = 3,
		overlay = 4,
		gui = 5,
		front = 0x0F,
--]]
	},
	align = function(element, mode, value, ref)
		if mode == "left" then
			element.offset[1] =
				(ref and ref.offset[1] + ref.scale * ref.width / 2 or 0)
				+ value + element.scale * element.width / 2
		elseif mode == "right" then
			element.offset[1] =
				(ref and ref.offset[1] - ref.scale * ref.width / 2 or 0)
				- value - element.scale * element.width / 2
		elseif mode == "top" then
			element.offset[2] =
				(ref and ref.offset[2] - ref.scale * ref.height / 2 or 0)
				- value - element.scale * element.height / 2
		elseif mode == "bottom" then
			element.offset[2] =
				(ref and ref.offset[2] + ref.scale * ref.height / 2 or 0)
				+ value + element.scale * element.height / 2
		else
			error("unsupported mode " .. mode)
		end
	end,
	fit = function(element, mode, w, h)
		if not (element.width > 0 and element.height > 0) then return end
		if mode == "scale" then
			element.scale = math.min(w / element.width, h / element.height)
		else
			error("unsupported mode " .. mode)
		end
	end,
}
