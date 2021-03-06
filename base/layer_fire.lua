local cfg = require("base/config").layer.fire
local util = require("core/util")
local core = require("core/core")
local hexagon = require("core/hexagon")
local buff = require("core/buff")

--[[
get:
	nil	ui, dump all
	team, pos	internal, get total strength
set:
	team, area, duration, strength		put fire on the ground

--]]

return function(map, layer_info)
	return {
		map = map,
		fire_list = {},
		tick = function(self, team)
			local new_list = {}
			for i = 1, #self.fire_list, 1 do
				local v = self.fire_list[i]
				if v.team == team and not core.common_tick(v) then
					-- noop
				else
					table.insert(new_list, v)
				end
			end

			self.fire_list = new_list
		end,
		apply = function(self, entity)
			local strength = self:get(entity.team, entity.pos)
			if strength and strength > 0 then
				buff.insert_notick(entity, "burn", strength, cfg.burn_duration)
			end
		end,
		contact = function(self, seed)
			if seed.element == "fire" then
				seed.power = seed.power * cfg.power_fire
			elseif seed.element == "water" then
				seed.power = seed.power * cfg.power_water
			end

			return seed
		end,
		get = function(self, team, pos)
			if not team then
				return {
					fire = self.fire_list,
				}
			end

			local res = 0
			for k, v in pairs(self.fire_list) do
				if hexagon.cmp(v.pos, pos) and v.team ~= team then
					res = res + v.strength
				end
			end

			return res
		end,
		set = function(self, team, area, duration, strength)
			for k, p in pairs(area) do
				table.insert(self.fire_list, {
					team = team,
					pos = p,
					duration = duration,
					strength = strength,
				})
			end
		end,
	}
end
