local util = require("util")
local hexagon = require("hexagon")

local function stars_get(self, pos)
	local layer = self.stars_energy
	local energy = 0
	local is_source = false
	for k, v in pairs(layer) do
		local dis = hexagon.distance(v.pos, pos, 4)
		if dis then
			energy = energy + v.energy / (dis + 1) ^ 2
			if dis == 0 then
				is_source = true
			end
		end
	end
	return math.floor(energy), is_source
end

local function stars_detonate(self, pos, power)
	local map = self.map
	local area = hexagon.range(pos, 2)
	map:damage(0, area, {
		damage = power,
		element = "star",
	})

	local layer = self.stars_energy
	local queue = {}
	for i = #layer, 1, -1 do
		local v = layer[i]
		local dis = hexagon.distance(v.pos, pos, 1)
		if dis then
			table.insert(queue, v)
			table.remove(layer, i)
		end
	end
	for k, v in pairs(queue) do
		stars_detonate(self, v.pos, 4 * v.energy)
	end

end

return function(map)
	local layer = {
		map = map,
		stars_energy = {},
		dump = function(self)
			return self.stars_energy
		end,
		func = function(self, pos, power)
			if power then
				return stars_detonate(self, pos, power)
			else
				return stars_get(self, pos)
			end
		end,
	}
	for i = 1, map.scale, 1 do
		local d = util.random("uniform", 0, map.scale)
		local i = util.random("uniform", 0, math.max(d * 6 - 1, 0))
		local e = util.random("uniform", 100, 400)
		util.unique_insert(layer.stars_energy, { pos = {d, i}, energy = e }, function(a, b)
			return hexagon.cmp(a.pos, b.pos)
		end)
	end

	return layer
end
