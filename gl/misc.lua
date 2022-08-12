local element_color_table = {
	physical = {0.3, 0.3, 0.3, 1},
	mental = {0.788, 0.212, 0.882, 1},
	fire = {0.969, 0.227, 0.227, 1},
	water = {0.416, 0.788, 0.980, 1},
	air = {0.502, 0.973, 0.894, 1},
	light = {0.980, 0.996, 0.451, 1},
	earth = {1.000, 0.847, 0.361, 1},
}

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
	element_color = function(element, default)
		if not element_color_table[element] then
			return default
		end
		local res = {}
		for i, c in ipairs(element_color_table[element]) do
			res[i] = c
		end

		return res
	end,
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
