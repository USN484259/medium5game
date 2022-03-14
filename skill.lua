local util = require("util")

local skill_table = {
	move = function()
		return {
			name = "move",
			cooldown = 1,
			remain = 0,
			func = function(entity, waypoint)
				local map = entity.map
				local pos = entity.pos
				if #waypoint > entity.speed then
					return false
				end
				for i = 1, #waypoint, 1 do
					pos = hexagon.direction(pos, waypoint[i])
					if pos[1] >= map.scale then
						return false
					end

					if map:get(pos) then
						return false
					end
				end
				entity.pos = pos
				return true
			end,
		}
	end,
	attack = function()
		return {
			name = "attack",
			cooldown = 1,
			remain = 0,
			func = function(entity, info)
				local map = entity.map
				local pos = entity.pos
				local cost = info.energy or 0
				local dis = info.distance or 1
				local width = info.width or 1
				local dir = info.direction
				local queue

				if entity.energy < cost then
					return false
				end

				if width >= 4 then
					queue = hexagon.range(pos, dis)
				else
					queue = hexagon.fan(pos, dis, (dir + 6 - width) % 6 + 1, (dir + width - 2) % 6 + 1)
				end
				
				for k, p in pairs(queue) do
					local tar = map:get(p)
					if tar and tar.team ~= entity.team then
						tar:on_damage(info.damage, info.element)
					end
				end
				return true
			end,
		}
	end,
}


return function(name)
	return skill_table[name]()
end
