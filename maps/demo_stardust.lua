return {
	scale = 4,

	layers = {{
		name = "light",

		{ pos = {0, 0}, energy = 1000 },
		{ pos = {2, 4}, energy = 400 },
		{ pos = {2, 8}, energy = 400 },
		{ pos = {2, 0}, energy = 400 },
	}, {
		name = "air",
	}, {
		name = "fire",
	}, {
		name = "water",
	}},
	
	teams = {{
		round = "player",
		{ "stardust", {4, 12} },
	}, {
		round = "enemy",
		{ "toolman", {4, 0} },
		{ "toolman", {4, 4} },
		{ "toolman", {4, 8} },
		{ "toolman", {4, 16} },
		{ "toolman", {4, 20} },
	}},
}
