local util = require("util")
local hexagon = require("hexagon")

local function star_get(layer, pos)
	local energy = 0
	for k, v in pairs(layer) do
		local dis = hexagon.distance(v.pos, pos, 4)
		if dis then
			energy = energy + v.energy / (dis + 1) ^ 2
		end
	end
	return math.floor(energy)
end

return function(map)
	local layer = {}
	for i = 1, 2 * map.scale, 1 do
		local d = util.random("uniform", 0, map.scale)
		local i = util.random("uniform", 0, math.max(d * 6 - 1, 0))
		local e = util.random("uniform", 0, 400)
		table.insert(layer, { pos = {d, i}, energy = e })
	end
	map.layers.star_energy = star_get
	map.star_energy = layer
end
