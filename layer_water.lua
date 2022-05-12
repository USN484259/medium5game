local util = require("util")
local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")

--[[
get:
	nil	ui, dump all
	pos	get water
	pos, "downpour"		internal, check downpour effect
set:
	"depth", pos, diff	change water depth
	"downpour", team, area, duration, power	downpour effect

--]]

return function(map)
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

				if depth > 1000 then
					buff.insert_notick(entity, "drown")
				end
			end

			local f = self:get(entity.pos, "downpour")
			if f then
				buff.insert_notick(entity, "bubble", f.team, f.power, 2)
			end
		end,
		contact = function(self, seed)
			if seed.element == "fire" then
				local f = self:get(seed.pos, "downpour")
				if f and f.team ~= seed.team then
					return nil
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
				for k, v in pairs(self.downpour_list) do
					if hexagon.cmp(v.pos, pos) then
						return v
					end
				end
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
				local pos, diff = ...
				for k, v in pairs(self.depth_table) do
					if hexagon.cmp(pos, v.pos) then
						local res = v.depth + diff
						if res > 0 then
							v.depth = res
							return math.abs(diff)
						else
							table.remove(self.depth_table, k)
							return v.depth
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
				local team, area, duration, power = ...
				for k, p in pairs(area) do
					local f = {
						team = team,
						pos = p,
						duration = duration,
						power = power,
					}
					local k, v = util.find(self.downpour_list, f, function(a, b)
						return hexagon.cmp(a.pos, b.pos)
					end)

					if not v then
						table.insert(self.downpour_list, f)
					elseif v.team == team then
						v.power = math.max(v.power, f.power)
						v.duration = v.duration + f.duration
					elseif v.power <= f.power then
						table.remove(self.downpour_list, k)
						f.power = f.power - v.power
						if f.power > 0 then
							table.insert(self.downpour_list, f)
						end
					else
						v.power = v.power - f.power
					end
				end
			else
				error(cmd)
			end
		end,
	}

	-- FIXME map generation
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
						depth = s // r,
					}
					local x, v = util.find(layer.depth_table, val, function(a, b)
						return hexagon.cmp(a.pos, b.pos)
					end)

					if x then
						v.depth = v.depth + val.depth
					else
						table.insert(layer.depth_table, val)
					end
				end
			end
		end
	end
	return layer
end
