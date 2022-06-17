local util = require("core/util")
local core = require("core/core")
local hexagon = require("core/hexagon")
local buff = require("core/buff")

--[[
get:
	nil		ui, dump all
	pos		get cooling
	pos, "wind"	internal, get wind
	pos, "storm"	internal, get storm
set:
	"wind", area, dir, duration	directed wind
	"storm", {team, pos, radius, duration, power}	storm
--]]

local function do_tick(team, list)
	local new_list = {}
	for i = 1, #list, 1 do
		local v = list[i]
		if v.team == team and not core.common_tick(v) then
			-- noop
		else
			table.insert(new_list, v)
		end
	end

	return new_list
end

return function(map, layer_info)
	return {
		map = map,
		wind_list = {},
		storm_list = {},
		tick = function(self, team)
			self.wind_list = do_tick(team, self.wind_list)
			self.storm_list = do_tick(team, self.storm_list)
		end,
		apply = function(self, entity)
			local l = self:get(entity.pos, "storm")
			for i, f in ipairs(l) do
				buff.insert_notick(entity, "storm", f.team, f.power)
			end
		end,
		contact = function(self, seed)
			local l = self:get(seed.pos, "storm")
			if #l > 0 then
				table.sort(l, function(a, b)
					return b.team == seed.team
				end)
				local storm = l[1]
				if seed.team == storm.team then
					seed.pos = storm.pos
					seed.radius = storm.radius
				else
					seed = nil
				end

			else
				local wind = self:get(seed.pos, "wind")
				if wind then
					seed.pos = hexagon.direction(seed.pos, wind.direction)
				end
			end

			return seed
		end,
		get = function(self, pos, cmd)
			if not pos then
				return {
					wind = self.wind_list,
					storm = self.storm_list,
				}
			end

			if cmd == "wind" then
				for k, v in pairs(self.wind_list) do
					if hexagon.cmp(v.pos, pos) then
						return v
					end
				end
			elseif cmd == "storm" then
				local res = {}
				for k, v in pairs(self.storm_list) do
					if hexagon.distance(v.pos, pos, v.radius) then
						table.insert(res, v)
					end
				end
				return res
			else
				local l = self:get(pos, "storm")
				if #l > 0 then
					return "storm"
				end

				local wind = self:get(pos, "wind")
				if wind then
					return "wind"
				end

				return nil
			end
		end,
		set = function(self, cmd, ...)
			if cmd == "wind" then
				local area, dir, duration = ...
				for k, p in pairs(area) do
					local wind = self:get(p, "wind")
					if wind then
						wind.direction = dir
						wind.duration = duration
					else
						table.insert(self.wind_list, {
							pos = p,
							direction = dir,
							duration = duration,
						})
					end
				end
			elseif cmd == "storm" then
				local info = ...
				table.insert(self.storm_list, info)
			else
				error(cmd)
			end
		end,
	}
end
