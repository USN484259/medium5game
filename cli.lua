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

local color_enable = false
local locale_table = nil

local function color(arg)
	if not color_enable then
		return ""
	end

	if not arg then
		return "\x1B[0m"
	end

	local mode = 1
	local fg, bg

	if type(arg) ~= "table" then
		fg = arg
	else
		mode = arg.mode or 1
		fg = arg.fg
		bg = arg.bg
	end

	local res = "\x1B[" .. mode

	if fg and color_table[fg] then
		res = res .. ';' .. (30 + color_table[fg])
	end
	if bg and color_table[bg] then
		res = res .. ';' .. (40 + color_table[bg])
	end

	return res .. 'm'
end

local function translate(name, ...)
	local cnt = select("#", ...)
	if cnt > 0 then
		local prefix = ""
		for i = cnt, 1, -1 do
			prefix = prefix .. (select(i, ...)) .. '.'
		end
		name = prefix .. name
	end

	-- print("translating key: " .. name)

	local l = locale_table
	for k in string.gmatch(name, "([^%.]+)") do
		if type(l) ~= "table" then
			return name
		end
		l = l[k]
	end

	if type(l) == "string" then
		return l, name
	elseif type(l) == "table" and type(l[1]) == "string" then
		return color(l[2]) .. l[1] .. color(), name
	else
		return name
	end
end

local function kv_string(name, value)
	return translate(name) .. ' ' .. value
end

local event_table = {
	spawn = function(map, obj)
		print(translate(obj.name) .. ' ' .. translate("event.spawn") .. ' ' .. hexagon.print(obj.pos))
	end,
	kill = function(map, obj)
		print(translate(obj.name) .. ' ' .. translate("event.kill") .. ' ' .. hexagon.print(obj.pos))
	end,
	move = function(map, obj, waypoint)
		local pos = obj.pos
		local str = translate(obj.name) .. ' ' .. translate("event.move") .. ' ' .. hexagon.print(obj.pos)
		for i = 1, #waypoint, 1 do
			pos = hexagon.direction(pos, waypoint[i])
			str = str .. "===>" .. hexagon.print(pos)
		end
		print(str)
	end,
	teleport = function(map, obj, target)
		print(translate(obj.name) .. ' ' .. translate("event.teleport") .. ' ' .. hexagon.print(obj.pos) .. "--|>" .. hexagon.print(target))
	end,
	heal = function(map, obj, heal)
		print(translate(obj.name) .. ' ' .. hexagon.print(obj.pos) .. ' ' .. translate("event.heal") .. ' ' .. heal)
	end,
	damage = function(map, obj, damage, element)
		print(translate(obj.name) .. ' ' .. hexagon.print(obj.pos) .. ' ' .. translate("event.damage") .. ' ' .. translate(element, "element") .. ' '.. damage)
	end,
	miss = function(map, obj)
		print(translate(obj.name) .. ' ' .. hexagon.print(obj.pos) .. ' ' .. translate("event.miss"))
	end,
	shield = function(map, obj, blk)
		print(translate(obj.name) .. ' ' .. translate("event.shield") .. ' ' .. blk)
	end,
	generate = function(map, obj, power)
		print(translate(obj.name) .. ' ' .. hexagon.print(obj.pos) .. ' ' .. translate("event.generate") .. ' ' .. power)
	end,
	skill = function(map, obj, skill)
		print(translate(obj.name) .. ' ' .. hexagon.print(obj.pos) .. translate("event.skill") .. ' ' .. translate(skill.name))
	end,
	seed = function(map, obj, orig_pos)
		print(translate(obj.name) .. ' ' .. translate("event.seed") .. ' ' .. hexagon.print(orig_pos) .. "===>" .. hexagon.print(obj.pos))
	end,
}

local function show_banner(name, postfix)
	local sep = "--------"
	local str = '\n' .. color("green") .. sep .. translate(name)
	if postfix then
		str = str .. color() .. ' ' .. postfix .. color("green")
	end
	str = str .. sep .. color()
	print(str)
end

local function show_map(map, func)
	-- cli.show_banner("lang.map")
	for k, e in pairs(map.entities) do
		--[[
		local str = ""
		if e.team == tid then
			table.insert(team, e)
			str = tostring(#team) .. '\t'
		else
			str = "-\t"
		end
		--]]
		local str = hexagon.print(e.pos) .. "\t" .. translate(e.name) .. "\t" .. translate("entity.health") .. '\t' .. e.health .. '/' .. e.health_cap

		for k, v in pairs(e.status) do
			str = str .. '\t' .. translate(k, "status")
		end
		func(str, e)
	end
end

local function show_layer(map, layer, func)
	--[[
	local i = 1
	local function color_print(str)
		if i % 2 == 0 then
			str = color({mode = 1}) .. str .. color()
		end
		print(str)
		i = i + 1
	end
	--]]
	local layer_dump = {
		light = function(layer)
			for k, v in pairs(layer.source) do
				func(hexagon.print(v.pos) .. "\t" .. kv_string("layer.light.source", v.energy))
			end

			for k, v in pairs(layer.blackhole) do
				func(hexagon.print(v.pos) .. "\t" .. translate("layer.light.blackhole") .. '\t' .. kv_string("lang.team", v.team) .. "\t" .. kv_string("lang.radius", v.radius))
			end
		end,
		air = function(layer)
			for k, v in pairs(layer.wind) do
				func(hexagon.print(v.pos) .. "\t" .. translate("layer.air.wind") .. '\t' .. kv_string("lang.direction", v.direction))
			end

			for k, v in pairs(layer.storm) do
				func(hexagon.print(v.center) .. "\t" .. translate("layer.air.storm") .. '\t' .. kv_string("lang.team", v.team) .. "\t" .. kv_string("lang.radius", v.radius))
			end
		end,
		fire = function(layer)
			for k, v in pairs(layer.fire) do
				func(hexagon.print(v.pos) .. translate("layer.fire.fire") .. '\t' .. kv_string("lang.team", v.team))
			end
		end,
		water = function(layer)
			for k, v in pairs(layer.depth) do
				func(hexagon.print(v.pos) .. "\t" .. kv_string("layer.water.depth", v.depth))
			end

			for k, v in pairs(layer.downpour) do
				func(hexagon.print(v.pos) .. "\t" .. translate("layer.water.downpour") .. '\t' .. kv_string("lang.team", v.team) .. '\t' .. kv_string("lang.radius", v.radius))
			end
		end,
	}

	local l = map.layer_map[layer]
	if not l then
		return
	end

	-- show_banner("lang.layer", translate(layer, "element"))
	layer_dump[layer](l:get())
	-- print("")
end


local function show_entity(entity, func)
	-- show_banner("lang.entity")
	local str = translate(entity.name) .. " " .. translate(entity.element, "element") .. '\t' .. kv_string("lang.position", hexagon.print(entity.pos)) .. '\t' .. kv_string("entity.health", entity.health .. '/' .. entity.health_cap) .. '\t' .. kv_string("entity.energy", entity.energy .. '/' .. entity.energy_cap)
	func(str)

	str = '\t' .. kv_string("entity.sanity", entity.sanity) .. '\t' .. kv_string("entity.power", entity.power) .. '\t' .. kv_string("entity.speed", entity.speed) .. '\t' .. kv_string("entity.accuracy", entity.accuracy)
	func(str)

	str = ""
	for k, v in pairs(entity.status) do
		str = str .. '\t' .. translate(k, "status")
		if type(v) ~= "boolean" then
			str = str .. '(' .. v .. ')'
		end
	end
	if str ~= "" then
		func('\t' .. kv_string("lang.status", str))
	end
end

local function show_item(entity, func)
	-- show_banner("lang.item")
	local pure_name = string.gsub(entity.name, "entity%.([^%s]+)", "%1")
	for k, item in pairs(entity.inventory) do
		local str = translate(item.name)
		if item.remain then
			str = str .. "\t" .. kv_string("item.cooldown", item.remain .. '/' .. item.cooldown)
		elseif item.modes then
				str = str .. '\t'
			for i = 1, #item.modes, 1 do
				local m = item.modes[i]
				if type(m) == "table" then
					m = translate(m.name, pure_name, "item")
				else
					m = translate(m, pure_name, "item")
				end
				if i == item.select then
					str = str .. '[' .. m .. "] "
				else
					str = str .. m .. ' '
				end
			end
		else
			for k, v in pairs(item) do
				local n, x = translate(k, pure_name, "item")
				if x then
					str = str .. '\t' .. n .. ' ' .. v
				end
			end
		end
		func(str, item)
	end
end

local function show_skill(entity, func)
	-- show_banner("lang.skill")
	for i = 1, #entity.skills, 1 do
		local sk = entity.skills[i]
		-- sk:update()

		--[[
		local name = cli.translate(sk.name)
		if string.len(name) < 8 then
			name = name .. '\t'
		end

		local str = tostring(i) .. '\t' .. name .. "\t" .. cli.translate(sk.type)
		--]]
		local str = translate(sk.name) .. '\t' .. translate(sk.type, "skill")

		if sk.type == "multitarget" then
			str = str .. '(' .. sk.shots .. ')'
		elseif sk.type == "waypoint" then
			str = str .. '(' .. sk.step .. ')'
		end

		str = str .. "\t" .. kv_string("skill.cooldown", sk.remain .. '/' .. sk.cooldown) .. "\t" .. kv_string("skill.cost", sk.cost)
		if sk.water_cost then
			str = str .. "\t" .. kv_string("skill.water_cost", sk.water_cost)
		end
		if sk.range then
			local r
			if type(sk.range) == "table" then
				r = sk.range[1] .. '-' .. sk.range[2]
			else
				r = sk.range
			end
			str = str .. "\t" .. kv_string("skill.range", r)
		end
		if sk.radius then
			str = str .. "\t" .. kv_string("skill.radius", sk.radius)
		end

		str = str .. '\t' .. kv_string("skill.enable", translate(tostring(sk.enable), "lang"))
		func(str, sk)
	end
end

return {
	set = function(key, val)
		if key == "locale" then
			local res, l = pcall(require, "locale/" .. val)
			if res and type(l) == "table" then
				locale_table = l
				return
			end
			error("failed to load locale " .. val .. '\t' .. l)
		elseif key == "color" then
			color_enable = val
		else
			error(key)
		end
	end,
	color = color,
	translate = translate,
	event_table = event_table,
	show_banner = show_banner,
	show_map = show_map,
	show_layer = show_layer,
	show_entity = show_entity,
	show_item = show_item,
	show_skill = show_skill,
}
