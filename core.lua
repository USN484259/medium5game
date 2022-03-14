local util = require("util")
local skill = require("skill")
local buff = require("buff")

local function new_entity(name, team, pos, template)
	return {
		name = name,
		pos = pos,
		team = team,
		template = template,

		health = template.health_cap,
		buff = {},

		on_damage = function(self, val, element)
			local ratio = 1 - (self.resistance[element] or 0)
			self.health = self.health - val * ratio
		end,
		on_heal = function(self, val)
			self.health = math.max(self.health_cap, self.health + val)
		end,
		on_death = function(self)
			self.map:remove(self)
			return true
		end,

		tick = function(self)
			if self.health <= 0 and self:on_death() then
				return
			end

			local new_buff = {}
			for k, v in pairs(template) do
				self[k] = v
			end
			table.sort(self.buff)
			for i = 1, #self.buff, 1 do
				if self.buff[i]:func(self) then
					table.insert(new_buff, self.buff[i])
				end
			end

			self.buff = new_buff
		end,

	}
end

local function new_character(name, team, pos, template)
	return util.merge_table(new_entity(name, team, pos, template), {
		status = {},
		--[[
		accuracy = 100,
		sanity = 80,
		resistance = {
			mental = 0,
		},
		speed = 1,
		sight = 2,
		energy = 100,
		energy_cap = 1000,
		generator = 100,
		--]]
		energy = template.generator,
		sanity = 80,
		inventory = {},
		buff = { buff("generate") },
		skills = {
			skill("move"),
			skill("attack"),
		},

	})
end

local entity_table = {
	target = {
		health_cap = 100,
		resistance = {},
	},
}

local character_table = {
	player = {
		health_cap = 100,
		resistance = { mental = 0 },
		accuracy = 1,
		speed = 2,
		sight = 3,
		energy_cap = 1000,
		generator = 100,
	},
}

return function(name, team, pos)
	if entity_table[name] then
		return new_entity(name, team, pos, entity_table[name])
	elseif character_table[name] then
		return new_character(name, team, pos, character_table[name])
	end
	return nil
end
