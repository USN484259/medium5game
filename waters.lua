local util = require("util")
local hexagon = require("hexagon")

return function(map)
	local layer = {
		waters = {},
		dump = function(self)
			return self.waters
		end,
		func = function(self, pos, use)
			for k, v in pairs(self.waters) do
				if hexagon.cmp(v.pos, pos) then
					if use then
						use = math.min(v.water, use)
						v.water = v.water - use
						return use
					else
						return v.water
					end
				end
			end
		end
	}

	-- FIXME map generation algorithm

	for i = 1, math.max(1, map.scale // 4), 1 do
		local d = util.random("uniform", 0, map.scale)
		local i = util.random("uniform", 0, math.max(d * 6 - 1, 0))
		local r = util.random("uniform", 1, 2)
		local s = util.random("uniform", 100, 4000)

		local area = hexagon.ring({d, i}, r)

		for r = 1, #area, 1 do
			for k, p in pairs(area[r]) do
				if p[1] <= map.scale then
					local val = {
						pos = p,
						water = s // r,
					}
					local x, v = util.find(layer.waters, val, function(a, b)
						return hexagon.cmp(a.pos, b.pos)
					end)

					if x then
						v.water = v.water + val.water
					else
						table.insert(layer.waters, val)
					end
				end
			end
		end
	end

	return layer
end
