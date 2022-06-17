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
		{ pos = {2, 0}, depth = 100 },
	}},

	teams = {{
		round = "player",
		{ "cangqiong", {0, 0}, {energy = 400} },
		{ "haiyi", {1, 0} },
		{ "chiyu", {1, 2} },
		{ "stardust", {1, 4} },
	}, {
		round = "enemy",
		{ "toolman", {4, 0} },
		{ "toolman", {4, 4} },
		{ "toolman", {4, 8} },
		{ "toolman", {4, 12} },
		{ "toolman", {4, 16} },
		{ "toolman", {4, 20} },
	}},
}
