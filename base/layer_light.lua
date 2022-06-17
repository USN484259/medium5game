local util = require("core/util")
local core = require("core/core")
local hexagon = require("core/hexagon")
local buff = require("core/buff")

--[[
get:
	nil	ui, dump all
	pos, "source"	get energy sources
	pos, "blackhole"	internal, get blackhole
set:
	"blackhole", {team, pos, radius, duration, power, threshold}	place blackhole
	"detonate", pos, cfg, power	energy detonation
--]]

local function detonate(map, source_list, pos, cfg, power)
	local area = hexagon.range(pos, cfg.damage.radius)
	map:damage(nil, area, {
		damage = power * cfg.damage.ratio,
		element = cfg.damage.element,
	})

	local queue = {}
	for i = #source_list, 1, -1 do
		local v = source_list[i]
		local dis = hexagon.distance(v.pos, pos, cfg.trigger_radius)
		if dis then
			table.insert(queue, v)
			table.remove(source_list, i)
		end
	end

	for k, v in pairs(queue) do
		detonate(map, source_list, v.pos, cfg, v.energy)
	end
end

return function(map, layer_info)
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
			local l = self:get(entity.pos, "blackhole")
			for i, b in ipairs(l) do
				if b.team ~= entity.team and b.power / entity.health_cap > b.crush_threshold then
					entity.map:kill(entity)
					break
				else
					buff.insert_notick(entity, "blackhole", b.team, b.power)
				end
			end
		end,
		contact = function(self, seed)
			local l = self:get(seed.pos, "blackhole")
			for i, b in pairs(l) do
				if b and b.team ~= seed.team then
					return nil
				end
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
				local res = {}
				for k, v in pairs(self.blackhole_list) do
					if hexagon.distance(pos, v.pos, v.radius) then
						table.insert(res, v)
					end
				end
				return res
			elseif cmd == "source" then
				return self.source_list
			else
				error(cmd)
			end
		end,
		set = function(self, cmd, ...)
			if cmd == "blackhole" then
				local info = ...
				table.insert(self.blackhole_list, info)

			elseif cmd == "detonate" then
				local pos, cfg, power = ...

				detonate(self.map, self.source_list, pos, cfg, power)
			else
				error(cmd)
			end
		end,
	}

	for i, v in ipairs(layer_info) do
		util.unique_insert(layer.source_list, util.copy_table(v), function(a, b)
			return hexagon.cmp(a.pos, b.pos)
		end)
	end

	return layer
end
