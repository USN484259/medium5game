local util = require("util")
local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")

--[[
get:
	nil	ui, dump all
	pos	get energy
	pos, "blackhole"	internal, get blackhole
set:
	"blackhole", team, area, duration, power	place blackhole
	"detonate", pos, power	energy detonation
--]]

local function detonate(map, source_list, pos, power)
	local area = hexagon.range(pos, 2)
	map:damage(0, area, {
		damage = power,
		element = "ether",
	})

	local queue = {}

	for i = #source_list, 1, -1 do
		local v = source_list[i]
		local dis = hexagon.distance(v.pos, pos, 1)
		if dis then
			table.insert(queue, v)
			table.remove(source_list, i)
		end
	end

	for k, v in pairs(queue) do
		detonate(map, source_list, pos, 4 * v.energy)
	end
end

return function(map)
	local layer = {
		map = map,
		source_list = {},
		blackhole_list = {},
		tick = function(self, team)
			local new_list = {}
			for i = 1, #self.blackhole_list, 1 do
				local v = self.blackhole_list[i]
				if v.team == team and not core.common_tick(v) then
					-- noop
				else
					table.insert(new_list, v)
				end
			end

			self.blackhole_list = new_list
		end,
		apply = function(self, entity)
			local b = self:get(entity.pos, "blackhole")
			if b then
				if b.team ~= entity.team and entity.health_cap * 2 < b.power then
					entity.map:kill(entity)
				else
					buff.insert_notick(entity, "blackhole", b.team, b.power)
				end
			end
		end,
		contact = function(self, seed)
			local b = self:get(seed.pos, "blackhole")
			if b and b.team ~= seed.team then
				return nil
			end

			return seed
		end,
		get = function(self, pos, cmd)
			if not pos then
				return {
					source = self.source_list,
					blackhole = self.blackhole_list,
				}
			end

			if cmd == "blackhole" then
				for k, v in pairs(self.blackhole_list) do
					if hexagon.cmp(pos, v.pos) then
						return v
					end
				end
			else
				local energy = 0
				for k, v in pairs(self.source_list) do
					local dis = hexagon.distance(v.pos, pos, 4)
					if dis then
						energy = energy + v.energy / (dis + 1) ^ 2
					end
				end

				return math.floor(energy)
			end
		end,
		set = function(self, cmd, ...)
			if cmd == "blackhole" then
				local team, area, duration, power = ...
				for k, p in pairs(area) do
					local f = {
						team = team,
						pos = p,
						duration = duration,
						power = power
					}
					local k, v = util.find(self.blackhole_list, f, function(a, b)
						return hexagon.cmp(a.pos, b.pos)
					end)

					if k then
						self.blackhole_list[k] = f
					else
						table.insert(self.blackhole_list, f)
					end
				end
			elseif cmd == "detonate" then
				local pos, power = ...
				
				detonate(self.map, self.source_list, pos, power)
			else
				error(cmd)
			end
		end,
	}

	-- FIXME map generation
	for i = 1, map.scale, 1 do
		local d = util.random("uniform", 0, map.scale)
		local i = util.random("uniform", 0, math.max(d * 6 - 1, 0))
		local e = util.random("uniform", 100, 400)
		util.unique_insert(layer.source_list, { pos = {d, i}, energy = e }, function(a, b)
			return hexagon.cmp(a.pos, b.pos)
		end)
	end

	return layer
end
