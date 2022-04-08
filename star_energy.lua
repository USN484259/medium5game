local util = require("util")
local hexagon = require("hexagon")

local function star_get(map, pos)
	local layer = map.star_energy
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

local function star_detonate(map, pos, power)
	local area = hexagon.range(pos, 2)
	map:damage(0, area, {
		damage = power,
		element = "star",
	})

	local layer = map.star_energy
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
		star_detonate(map, v.pos, 4 * v.energy)
	end

end

local function star_cmd(map, pos, cmd, ...)
	cmd = cmd or "get"
	if cmd == "get" then
		return star_get(map, pos, ...)
	elseif cmd == "detonate" then
		return star_detonate(map, pos, ...)
	end
end

return function(map)
	local layer = {}
	for i = 1, map.scale, 1 do
		local d = util.random("uniform", 0, map.scale)
		local i = util.random("uniform", 0, math.max(d * 6 - 1, 0))
		local e = util.random("uniform", 100, 400)
		util.unique_insert(layer, { pos = {d, i}, energy = e }, function(a, b)
			return hexagon.cmp(a.pos, b.pos)
		end)
	end
	map.layers.star_energy = star_cmd
	map.star_energy = layer
end
