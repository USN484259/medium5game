local cfg = require("base/config").layer.water
local util = require("core/util")
local core = require("core/core")
local hexagon = require("core/hexagon")
local buff = require("core/buff")

--[[
get:
	nil	ui, dump all
	pos	get water
	pos, "downpour"		internal, check downpour effect
set:
	"depth", pos, diff, limit	change water depth
	"downpour", {team, pos, radius, duration, power, bubble_duration}	downpour effect

--]]

return function(map, layer_info)
	local layer = {
		map = map,
		depth_table = {},
		downpour_list = {},
		tick = function(self, team)
			local new_list = {}
			for i = 1, #self.downpour_list, 1 do
				local v = self.downpour_list[i]
				if v.team == team and not core.common_tick(v) then
					-- noop
				else
					table.insert(new_list, v)
				end
			end

			self.downpour_list = new_list
		end,
		apply = function(self, entity)
			local depth = self:get(entity.pos)
			if depth then
				buff.insert_notick(entity, "wet", 1)
				if depth >= cfg.drown_depth then
					buff.insert_notick(entity, "drown")
				end
			end

			local l = self:get(entity.pos, "downpour")
			table.sort(l, function(a, b)
				if a.team == b.team then
					return false
				end
				return a.team == entity.team
			end)
			for i, f in ipairs(l) do
				buff.insert_notick(entity, "bubble", f.team, f.power, f.bubble_duration)
			end
		end,
		contact = function(self, seed)
			if seed.element == "fire" then
				local l = self:get(seed.pos, "downpour")
				for i, f in ipairs(l) do
					if f and f.team ~= seed.team then
						return nil
					end
				end
			end
			return seed
		end,
		get = function(self, pos, cmd)
			if not pos then
				return {
					depth = self.depth_table,
					downpour = self.downpour_list,
				}
			end

			if cmd == "downpour" then
				local res = {}
				for k, v in pairs(self.downpour_list) do
					if hexagon.distance(v.pos, pos, v.radius) then
						table.insert(res, v)
					end
				end
				return res
			else
				for k, v in pairs(self.depth_table) do
					if hexagon.cmp(v.pos, pos) and v.depth > 0 then
						return v.depth
					end
				end
			end
		end,
		set = function(self, cmd, ...)
			if cmd == "depth" then
				local pos, diff, limit = ...
				for k, v in pairs(self.depth_table) do
					if hexagon.cmp(pos, v.pos) then
						if diff < 0 then
							if limit and v.depth <= limit then
								return 0
							end

							diff = math.min(v.depth - limit or 0, -diff)

							v.depth = v.depth - diff

							if v.depth == 0 then
								table.remove(self.depth_table, k)
							end

							return diff
						else
							v.depth = v.depth + diff
							return diff
						end
					end
				end

				if diff > 0 then
					table.insert(self.depth_table, {
						pos = pos,
						depth = diff,
					})

					return diff
				else
					return 0
				end
			elseif cmd == "downpour" then
				local info = ...
				table.insert(self.downpour_list, info)
			else
				error(cmd)
			end
		end,
	}

	for i, v in ipairs(layer_info) do
		util.unique_insert(layer.depth_table, util.copy_table(v), function(a, b)
			return hexagon.cmp(a.pos, b.pos)
		end)
	end

	return layer
end
