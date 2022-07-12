local function haiyi_action(entity, round)
	local action_table = {{
		-- round 1
		{ "skill.haiyi.convert", },
		{ "skill.haiyi.attack", { {2, 7}, }, },
	}, {
		-- round 2
		{ "skill.haiyi.move", {3, 3}, },
		{ "skill.haiyi.bubble", { {4, 10}, {2, 4},}, },
	}, {
		-- round 3
		{ "skill.haiyi.move", {4, 13}, },
		{ "skill.haiyi.attack", { {4, 10}, {4, 12}, {2, 2}, {2, 7},}, },
	}, {
		-- round 4
		{ "skill.haiyi.bubble", { {4, 10}, {4, 12},}, },
	}, {
		-- round 5
		{ "skill.haiyi.move", {1, 3}, },
		{ "skill.haiyi.downpour", },
	}, {
		-- round 6
		{ "skill.haiyi.move", {3, 13}, },
		{ "skill.haiyi.attack", { {2, 7},}, },
	}, {
		-- round 7
		{ "skill.haiyi.attack", { {2, 7}, {4, 12},}, },
	}}

	if round > #action_table then
		return {{
			cmd = "quit",
		}}
	end

	local actions = {}
	for i, v in ipairs(action_table[round]) do
		local skill
		for i, sk in ipairs(entity.skills) do
			if sk.name == v[1] then
				skill = sk
				break
			end
		end
		assert(skill)
		table.insert(actions, {
			cmd = "action",
			entity = entity,
			skill = skill,
			args = table.pack(table.unpack(v, 2)),
		})
	end

	table.insert(actions, {
		cmd = "round_end",
	})

	return actions
end

return {
	scale = 4,

	layers = {{
		name = "light",
	}, {
		name = "air",
	}, {
		name = "fire",
	}, {
		name = "water",

		{ pos = {3, 6}, depth = 1200 },
		{ pos = {3, 7}, depth = 2000 },
		{ pos = {3, 8}, depth = 2000 },
		{ pos = {3, 9}, depth = 1200 },
		{ pos = {4, 10}, depth = 1000 },
		{ pos = {2, 5}, depth = 1000 },
		{ pos = {4, 11}, depth = 800 },
		{ pos = {2, 6}, depth = 800 },
		{ pos = {4, 9}, depth = 800 },
		{ pos = {2, 4}, depth = 800 },
		{ pos = {4, 8}, depth = 500 },
		{ pos = {4, 7}, depth = 500 },
		{ pos = {3, 5}, depth = 500 },
		{ pos = {4, 12}, depth = 500 },
		{ pos = {3, 10}, depth = 500 },
		{ pos = {4, 13}, depth = 500 },

	}},

	teams = {{
		{ "haiyi", {0, 0}, {energy = 400} },
		{ "chiyu", {4, 10} },
		round = function(map, tid, round)
			local team = map:get_team(tid)
			local haiyi = nil
			for i, e in ipairs(team) do
				if e.name == "entity.haiyi" then
					haiyi = e
					break
				end
			end
			return haiyi_action(haiyi, round)
		end,
	}, {
		{ "toolman", {2, 7} },
		{ "toolman", {4, 12} },
		{ "toolman", {2, 2} },
		round = function(map, tid, round)
			local team = map:get_team(tid)
			local actions = {}
			for k, e in ipairs(team) do
				for i, sk in ipairs(e.skills) do
					if sk.enable then
						table.insert(actions, {
							cmd = "action",
							entity = e,
							skill = sk,
							args = nil,
						})
					end
				end
			end

			table.insert(actions, {
				cmd = "round_end",
			})
			return actions
		end,
	}},
}
