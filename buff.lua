
local table = {
	generate = function()
		return {
			name = "generate",
			hidden = true,
			order = 9999,	-- should be last
			func = function(self, entity)
				entity.energy = math.min(entity.energy_cap, entity.energy + entity.generator)
				return true
			end,
		}
	end,
}

return function(name)
	return table[name]()
end
