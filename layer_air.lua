local util = require("util")
local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")

--[[
get:
	nil		ui, dump all
	pos		get cooling
	pos, "wind"	internal, get wind
	pos, "storm"	internal, get storm
set:
	"wind", area, dir, duration	directed wind
	"storm", team, center, range, duration, power	storm
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

return function(map)
	return {
		map = map,
		wind_list = {},
		storm_list = {},
		tick = function(self, team)
			self.wind_list = do_tick(team, self.wind_list)
			self.storm_list = do_tick(team, self.storm_list)
		end,
		apply = function(self, entity)
			local storm = self:get(entity.pos, "storm")
			if storm then
				buff.insert_notick(entity, "storm", storm.team, steam.power)
			end
		end,
		contact = function(self, seed)
			local storm = self:get(seed.pos, "storm")
			if storm then
				seed.pos = storm.center or seed.pos
				seed.range = storm.range or seed.range
				if seed.team ~= storm.team then
					seed.power = seed.power / 2
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
				local cnt = 0
				local res
				for k, v in pairs(self.storm_list) do
					if hexagon.distance(v.pos, pos, v.range) then
						cnt = cnt + 1
						if cnt > 2 then
							res.power = 0
							break
						end

						if res then
							if v.power <= res.power then
								res.power = res.power - v.power
							else
								local sub = res.power
								res = util.copy_table(v)
								v.power = v.power - sub
							end
						else
							res = util.copy_table(v)
						end
					end
				end

				if res and res.power == 0 then
					res.team = 0
					res.center = nil
					res.range = nil
				end

				return res
			else
				local storm = self:get(pos, "storm")
				if storm then
					return 2
				end

				local wind = self:get(pos, "wind")
				if wind then
					return 1
				end

				return 0
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
				local team, center, range, duration, power = ...
				local f = {
					center = center,
					team = team,
					range = range,
					duration = duration,
					power = power,
				}
				local k, v = util.find(self.storm_list, f, function(a, b)
					return hexagon.cmp(a.center, b.center)
				end)

				if not v then
					table.insert(self.storm_list, f)
				elseif v.power <= f.power then
					table.remove(self.storm_list, k)
					f.power = f.power - v.power
					if f.power > 0 then
						table.insert(self.storm_list, f)
					end
				else
					v.power = v.power - f.power
				end
			else
				error(cmd)
			end
		end,
	}
end
