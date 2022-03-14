local util = require("util")
local core = require("core")
local hexagon = require("hexagon")

return function(scale)
	return {
		scale = scale,
		entities = {},
		get = function(self, pos)
			for k, v in pairs(self.entities) do
				if hexagon.cmp(v.pos, pos) then
					return v
				end
			end
			return nil
		end,
		tick = function(self)
			-- do map ticking here
			for k, v in pairs(self.entities) do
				v:tick()
			end
		end,
		spawn = function(self, name, team, pos)
			if self:get(pos) then
				return false
			end
			local obj = core(name, team, pos)
			obj.map = self
			table.insert(self.entities, obj)
			return true
		end,

		remove = function(self, obj)
			for k, v in pairs(self.entities) do
				if v == obj then
					table.remove(self.entities, k)
					return true
				end
			end
			return false
		end,
	}
end


