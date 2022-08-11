local element = {
	light = { "光", "magenta" },
	air = { "气", "cyan" },
	fire = { "火", "red" },
	water = { "水", "blue" },
	earth = { "岩", "yellow" },

	physical = { "物理", {} },
	mental = { "精神", {} },
}

return {
	game = {
		name = "五维介质同人游戏",
		author = "USN484259",
		homepage = "https://github.com/USN484259/medium5game",
	},
	ui = {
		game_exit = "退出游戏",
		game_about = "(还没有想好游戏名)\n"
			.. "作者 USN484259\n"
			.. "鸣谢 @朦朦的卡比兽\n"
			.. "项目页面 https://github.com/USN484259/medium5game\n"
			.. "本项目代码使用MIT协议\n"
			.. "‘五维介质’‘星尘’等注册商标为北京福托科技开发有限责任公司所有\n"
			.. "使用-h参数启动游戏查看游戏选项",
		game_win = "游戏结束",
		game_lose = "游戏结束",
		game_menu = "主菜单",
		map_select = "选择地图",
		map_load = "加载地图",
		map_failed = "无法加载地图",
		map_exit = "退出地图",
		round_start = "回合开始",
		round_end = "回合结束",
		entity_select = "选择角色，0结束回合，x退出地图",
		-- entity_help = "",
		entity_inactive = "没有可用操作",
		skill_select = "选择技能，0返回，?显示帮助",
		skill_failed = "技能失败",
		skill_help = "技能编号 [参数1] [参数2] ...\n"
			.. "路径\t方向1 [方向2] ...\n"
			.. "目标\t坐标1_d值 坐标1_i值 [坐标2_d值 坐标2_i值] ...\n"
			.. "方向\t方向\n"
			.. "切换\n"
			.. "效果\n"
			.. "矢量\t方向 距离\n"
			.. "直线\t坐标d值 坐标i值 方向\n"
	},
	lang = {
		["true"] = "是",
		["false"] = "否",
		version = "版本",
		author = "作者",
		homepage = "主页",
		map = "场地",
		layer = "层",
		entity = "角色",
		team = "队",
		round = "回合",
		position = "位置",
		direction = "方向",
		radius = "半径",
		status = "状态",
		item = "物品",
		skill = "技能",
	},
	event = {
		spawn = "登场",
		kill = "退场",
		move = "移动",
		teleport = "移动",
		heal = "受到治疗",
		damage = "受到伤害",
		miss = "闪避攻击",
		shield = "阻挡攻击",
		generate = "获得能量",
		skill = "使用技能",
		skill_fail = "技能失败",
		seed = "投掷物",
	},
	element = element,
	entity = {
		health = "生命值",
		energy = "能量值",
		sanity = "理智",
		power = "力量",
		speed = "速度",
		accuracy = "精准",

		stardust ="星尘",
		haiyi = "海伊",
		cangqiong = "苍穹",
		chiyu = "赤羽",
		shian = "诗岸",

		bubble = "水泡",
		toolman = "工具人",
	},
	status = {
		ultimate = "终极技能",
		fly = "飞行",
		down = "击倒",
		block = "阻碍",
		drown = "溺水",
		burn = "点燃",
		wet = "潮湿",
		bubble = "水泡",
	},
	skill = {
		cooldown = "冷却",
		cost = "需要能量",
		water_cost = "需要水",
		range = "射程",
		radius = "作用半径",
		enable = "可用",

		waypoint = "路径",
		target = "目标",
		multitarget = "目标",
		direction = "方向",
		toggle = "切换",
		effect = "效果",
		vector = "矢量",
		line = "直线",

		stardust = {
			move = "移动",
			attack = "星辰双矛",
			hover = "引力漂浮",
			teleport = "空间跃迁",
			blackhole = "终焉归零",
			lazer = "终极棱镜",
			starfall = "恒星坠落之时",
		},
		haiyi = {
			move = "移动",
			attack = "水流冲击",
			convert = "祈雨",
			bubble = "海之摇篮",
			revive = "复苏之触",
			downpour = "泡影的咏叹调",
		},
		cangqiong = {
			move = "移动",
			attack = "驭灵风矢",
			select_arrow = "元素附魔",
			probe = "风暴之眼",
			wind_control = "气流控制",
			arrow_rain = "群青之空",
			storm = "自由之风的轻吟",
		},
		chiyu = {
			move = "移动",
			attack = "流刃若火",
			charge = "闪焰冲锋",
			ignition = "焚尽之羽",
			sweep = "烈焰风暴",
			nirvana = "涅槃",
			phoenix = "火凤焚天",
		},
		shian = {
			move = "移动",
			smash = "重锤",
			spike = "尖石攻击",
			transform = "形态切换",
			cannon = "岩石加农炮",
			apple = "禁忌Apple Dance",
			final_guard = "最后的守护",
		},

		toolman = {
			attack = "攻击",
		},
	},
	item = {
		cooldown = "冷却",
		stardust = {
			lance = "星辰之矛",
			mirror = "星光之镜",
			prism = "星光四面体",

			energy = "充能",
			energy_cap = "充能上限",
		},
		haiyi = {
			wand = "绀海之源",
			jellyfish = "水母",

			water = "蓄水",
			water_cap = "蓄水上限",
		},
		cangqiong = {
			lanyu = "岚语",
			butterfly = "蝴蝶",

			quiver = element,
		},
		chiyu = {
			ember = "业火余烬",
			feather = "菲尼克斯之羽",

			heat = "热量",
		},
		shian = {
			yankai = "岩铠三号",
			apple = "禁忌Apple",

			hammer = "锤形态",
			shield = "盾形态",
		},
	},
	buff = {
		bubble = "水泡",
	},
	seed = {
		feather = "菲尼克斯之羽",
		bubble = "水泡",
	},
	layer = {
		light = {
			source = "能量源",
			blackhole = "黑洞",
		},
		air = {
			wind = "风",
			storm = "风暴",
		},
		fire = {
			fire = "火",
		},
		water = {
			depth = "水深",
			downpour = "暴雨",
		},
	},
}
