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

		spawn = function(self, name, team, pos)
			if self:get(pos) then
				return nil
			end
			local obj = require(name)(team, pos)
			obj.map = self
			table.insert(self.entities, obj)
			return obj
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

		tick = function(self)
			local queue = {}
			for k, e in pairs(self.entities) do
				e.damage_hook = {}
				e.heal_hook = {}

				for k, v in pairs(e.template) do
					e[k] = v
				end

				for k, b in pairs(e.buff) do
					table.insert(queue, b)
				end
				e.buff = {}

			end

			table.sort(queue, function(a, b)
				return a.priority < b.priority
			end)

			for i = 1, #queue, 1 do
				if queue[i]:tick() then
					table.insert(queue[i].owner.buff, queue[i])
				end
			end

			for k, e in pairs(self.entities) do
				if not e:alive() then
					self:remove(e)
				else
					if e.generator then
						e.energy = math.floor(math.min(e.energy_cap, e.energy + e.generator))
					end
					if e.inventory then
						for k, v in pairs(e.inventory) do
							v:tick()
						end
					end
					if e.skills then
						for k, v in pairs(e.skills) do
							v:update(true)
						end
					end

					if e.action then
						e.active = true
					end
				end
			end

		end,

	}
end


