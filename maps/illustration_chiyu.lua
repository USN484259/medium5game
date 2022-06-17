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
	}},

	teams = {{
		round = "player",
		{ "chiyu", {0, 0}, {energy = 400} },
		round_start = function(map, tid, round)
			if round == 6 then
				print("****方便演示，充满能量，重置冷却****")
				local team = map:get_team(tid)
				for k, e in pairs(team) do
					e.energy = e.energy_cap
					for k, v in pairs(e.inventory) do
						if v.remain then
							v.remain = 0
						end
					end
				end
			end
		end,
	}, {
		round = "enemy",
		{ "toolman", {3, 2}, 800},
		round_end = function(map, tid, round)
			local list
			if round == 1 then
				list = {{
					{3, 1}, 100,
				}, {
					{1, 1}, 100,
				}, {
					{2, 1}, 100,
				}, {
					{1, 0}, 100,
				}}
			elseif round == 3 then
				list = {{
					{4, 10}, 300,
				}, {
					{3, 7}, 300,
				}, {
					{2, 5}, 300,
				}, {
					{2, 6}, 300,
				}, {
					{3, 9}, 300,
				}, {
					{4, 11}, 300,
				}, {
					{3, 8}, 300,
				}}
			elseif round == 5 then
				list = {{
					{1, 1},
				}, {
					{0, 0},
				}, {
					{1, 4},
				}, {
					{3, 12},
				}, {
					{1, 2},
				}, {
					{1, 5},
				}}
			end

			if list then
				for i, v in ipairs(list) do
					map:spawn(tid, "toolman", v[1], v[2])
				end
			end
		end,
	}},
}
