local hexagon = require("hexagon")


local color_table = {
	black = 0,
	red = 1,
	green = 2,
	yellow = 3,
	blue = 4,
	magenta = 5,
	cyan = 6,
	white = 7,
}

local function color(str, fg, bg)
	local res = "\x1B[1"
	if fg and color_table[fg] then
		res = res .. ';' .. (30 + color_table[fg])
	end
	if bg and color_table[bg] then
		res = res .. ';' .. (40 + color_table[bg])
	end
	return  res .. 'm' .. str .. "\x1B[0m"
end

local name_table = {
	default = {
		-- element & damage type
		ether = color("以太", "magenta"),
		air = color("气", "cyan"),
		fire = color("火", "red"),
		water = color("水", "blue"),
		earth = color("岩", "yellow"),

		physical = "物理",
		mental = "精神",

		-- entity names
		stardust = color("星尘", "magenta"),
		haiyi = color("海伊", "blue"),
		cangqiong = color("苍穹", "cyan"),
		chiyu = color("赤羽", "red"),
		shian = color("诗岸", "yellow"),

		bubble_entity = color("水泡", "blue"),
		toolman = "工具人",

		-- skill names & types
		attack = "攻击",
		move = "移动",

		waypoint = "路径\t",
		target = "目标\t",
		multitarget = "多重目标",
		direction = "方向\t",
		toggle = "切换\t",
		effect = "效果\t",
		line = "直线\t",
		vector = "矢量\t",

		-- status names
		ultimate = "终极技能",
		fly = "飞行",
		down = "击倒",
		block = "阻碍",
		drown = "溺水",
		burn = "点燃",
		wet = "潮湿",
		bubble = "水泡",
	},
	stardust = {
		attack = "星辰双矛",
		hover = "引力漂浮",
		teleport = "空间跃迁",
		blackhole = "终焉归零",
		lazer = "终极棱镜",
		starfall = "恒星坠落之时",

		stars_lance = color("星辰双矛", "magenta"),
		stars_mirror = color("星光之镜", "magenta"),
		stars_prism = color("星光四面体", "magenta"),

		energy = "充能",
		energy_cap = "充能上限",
	},
	haiyi = {
		attack = "水流冲击",
		convert = "祈雨",
		make_bubble = "海之摇篮",
		revive = "复苏之触",
		downpour = "泡影的咏叹调",

		wand_of_sea = color("绀海之源", "blue"),
		jellyfish = color("水母\t", "blue"),

		water = "蓄水",
		water_cap = "蓄水上限",
	},
	cangqiong = {
		attack = "驭灵风矢",
		select_arrow = "元素附魔",
		probe = "风暴之眼",
		wind_control = "气流控制",
		arrow_rain = "群青之空",
		storm = "自由之风的轻吟",

		lanyu = color("岚语", "cyan"),
		butterfly = color("蝴蝶", "cyan"),
	},
	chiyu = {
		attack = "流刃若火",
		charge = "闪焰冲锋",
		ignition = "焚尽之羽",
		sweep = "烈焰风暴",
		nirvana = "涅槃",
		phoenix = "火凤焚天",

		ember = color("业火余烬", "red"),
		feather = color("菲尼克斯之羽", "red"),

		temperature = "温度",
	},
	shian = {
		smash = "重锤",
		spike = "尖石攻击",
		transform = "形态切换",
		rock_cannon = "岩石加农炮",
		eat_apple = "禁忌Apple Dance",
		final_guard = "最后的守护",

		yankai = color("岩铠三号", "yellow"),
		apple = color("禁忌Apple", "yellow"),

		hammer = "锤形态",
		shield = "盾形态",
	},
}

local function translate(name, category)
	if category and name_table[category] and name_table[category][name] then
		return name_table[category][name]
	end
	return name_table["default"][name] or name
end

local ui_table = {
	spawn = function(map, obj)
		print(translate(obj.name) .. hexagon.print(obj.pos) .. "登场")
	end,
	kill = function(map, obj)
		print(translate(obj.name) .. hexagon.print(obj.pos) .. "退场")
	end,
	move = function(map, obj, waypoint)
		print(translate(obj.name) .. "移动" .. hexagon.print(obj.pos) .. "===>" .. hexagon.print(waypoint[#waypoint]))
	end,
	teleport = function(map, obj, target)
		print(translate(obj.name) .. "移动" .. hexagon.print(obj.pos) .. "--|>" .. hexagon.print(target))
	end,
	heal = function(map, obj, heal)
		print(translate(obj.name) .. hexagon.print(obj.pos) .. "治疗" .. heal)
	end,
	damage = function(map, obj, damage, element)
		print(translate(obj.name) .. hexagon.print(obj.pos) .. "受到伤害（" .. translate(element) .. '）'.. damage)
	end,
	miss = function(map, obj)
		print(translate(obj.name) .. hexagon.print(obj.pos) .. "闪避了攻击")
	end,
	shield = function(map, obj, blk, sh)
		local str
		if sh then
			str = translate(sh.name, obj.name)
		else
			str = translate(obj.name)
		end
		print(str .. "阻挡攻击" .. blk)
	end,
	generate = function(map, obj, power)
		print(translate(obj.name) .. hexagon.print(obj.pos) .. "获得能量" .. power)
	end,
	skill = function(map, obj, skill)
		print(translate(obj.name) .. hexagon.print(obj.pos) .. "使用技能 " .. translate(skill.name, obj.name))
	end,
	seed = function(map, obj, orig_pos)
		print(translate(obj.name) .. "移动" .. hexagon.print(orig_pos) .. "===>" .. hexagon.print(obj.pos))
	end,
}

return {
	color = color,
	translate = translate,
	ui_table = ui_table,

}
