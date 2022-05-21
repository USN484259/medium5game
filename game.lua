#!/usr/bin/env lua

local util = require("util")
local core = require("core")
local hexagon = require("hexagon")
local cli = require("cli")

local function show_layer(map, layer)
	local i = 1
	local function color_print(str)
		if i % 2 == 0 then
			str = cli.color(str)
		end
		print(str)
		i = i + 1
	end
	local layer_dump = {
		ether = function(layer)
			for k, v in pairs(layer.source) do
				color_print(hexagon.print(v.pos) .. "\t能量源 " .. v.energy)
			end

			for k, v in pairs(layer.blackhole) do
				color_print(hexagon.print(v.pos) .."\t黑洞\t队 " .. v.team)
			end
		end,
		air = function(layer)
			for k, v in pairs(layer.wind) do
				color_print(hexagon.print(v.pos) .. "\t风\t方向 " .. v.direction)
			end

			for k, v in pairs(layer.storm) do
				color_print(hexagon.print(v.center) .. "\t风暴\t队 " .. v.team .. "\t半径 " .. v.range)
			end
		end,
		fire = function(layer)
			for k, v in pairs(layer.fire) do
				color_print(hexagon.print(v.pos) .. "\t火\t队 " .. v.team)
			end
		end,
		water = function(layer)
			for k, v in pairs(layer.depth) do
				color_print(hexagon.print(v.pos) .. "\t水深 " .. v.depth)
			end

			for k, v in pairs(layer.downpour) do
				color_print(hexagon.print(v.pos) .. "\t暴雨\t队 ", v.team)
			end
		end,
	}

	local l = map.layer_map[layer]
	if not l then
		return
	end
	print(cli.color("\n--------层 ", "green") .. cli.translate(layer) .. cli.color("--------", "green"))
	layer_dump[layer](l:get())
	print("")
end

local function show_map(map, tid)
	print(cli.color("\n--------场地--------", "green"))
	local team = {}
	for k, e in pairs(map.entities) do
		local str = ""
		if e.team == tid then
			table.insert(team, e)
			str = tostring(#team) .. '\t'
		else
			str = "-\t"
		end
		str = str .. hexagon.print(e.pos) .. "\t" .. cli.translate(e.name) .. "\t生命 " .. e.health .. '/' .. e.health_cap

		for k, v in pairs(e.status) do
			str = str .. '\t' .. cli.translate(k)
		end
		print(str)
	end

	return team
end

local function show_entity(entity)
	print(cli.color("\n--------角色--------", "green"))
	local str = cli.translate(entity.name) .. "（" .. cli.translate(entity.element) .. "）\t位置 " .. hexagon.print(entity.pos) .. "\t生命 " .. entity.health .. '/' .. entity.health_cap .. "\t能量 " .. entity.energy .. '/' .. entity.energy_cap .. "\t理智 " .. entity.sanity .. "\t力量 " .. entity.power .. "\t速度 " .. entity.speed .. "\t精准 " .. entity.accuracy
	print(str)

	str = ""
	for k, v in pairs(entity.status) do
		str = str .. '\t' .. cli.translate(k)
		if type(v) ~= "boolean" then
			str = str .. '(' .. v .. ')'
		end
	end
	if str ~= "" then
		print("状态\t" .. str)
	end

	print(cli.color("\n--------物品--------", "green"))
	for k, item in pairs(entity.inventory) do
		local str = cli.translate(item.name, entity.name)
		if item.remain then
			str = str .. "\t冷却 " .. item.remain .. '/' .. item.cooldown
		elseif item.modes then
				str = str .. '\t'
			for i = 1, #item.modes, 1 do
				local m = item.modes[i]
				if type(m) == "table" then
					m = cli.translate(m.name, entity.name)
				else
					m = cli.translate(m, entity.name)
				end
				if i == item.select then
					str = str .. '[' .. m .. "] "
				else
					str = str .. m .. ' '
				end
			end
		else
			for k, v in pairs(item) do
				if k ~= "name" and k ~= "owner" then
					if type(v) == "table" then
						str = str .. '\t' .. cli.translate(k, entity.name) .. ' ' .. hexagon.print(v)
					elseif type(v) ~= "function" then
						str = str .. '\t' .. cli.translate(k, entity.name) .. ' ' .. v .. '\t'
					end
				end
			end
		end
		print(str)
	end

	print(cli.color("\n--------技能--------", "green"))
	for i = 1, #entity.skills, 1 do
		local sk = entity.skills[i]
		sk:update()

		local name = cli.translate(sk.name, entity.name)
		if string.len(name) < 8 then
			name = name .. '\t'
		end

		local str = tostring(i) .. '\t' .. name .. "\t" .. cli.translate(sk.type)
		if sk.type == "multitarget" then
			str = str .. '(' .. sk.shots .. ')'
		end
		str = str .. "\t冷却 " .. sk.remain .. '/' .. sk.cooldown .. "\t需要能量 " .. (sk.cost) .. '\t'
		if sk.water_cost then
			str = str .. "需要水 " .. sk.water_cost .. '\t'
		end
		if sk.enable then
			str = str .. "可用"
		else
			str = str .. "不可用"
		end
		if i % 2 == 0 then
			str = cli.color(str)
		end
		print(str)
	end
end


local function action_menu(entity)

	local sk
	local args
	while true do
		print(cli.color("\n选择技能，0返回，?显示帮助", "green"))
		local cmd = io.read()

		if cmd == "?" then
			print("技能编号 [参数1] [参数2] ...")
			print("路径\t方向1 [方向2] ...")
			print("目标\t坐标d值 坐标i值")
			print("多重目标\t坐标1_d值 坐标1_i值 [坐标2_d值 坐标2_i值] ...")
			print("方向\t方向")
			print("切换")
			print("效果")
			print("直线\t方向 距离")
			print("矢量\t坐标d值 坐标i值 方向")
		else
			sk = nil
			args = nil
			for s in string.gmatch(cmd, '([^%s]+)') do
				if args then
					local val = tonumber(s)
					table.insert(args, val or s)
				else
					local index = tonumber(s)
					if index == 0 then
						return false
					end
					sk = entity.skills[index]
					args = {}
				end
			end

			if sk then
				break
			end
		end
	end

	local res
	if sk.type == "target" or sk.type == "waypoint" then
		res = entity:action(sk, args)
	elseif sk.type == "vector" then
		res = entity:action(sk, { args[1], args[2] }, args[3])
	elseif sk.type == "multitarget" then
		local list = {}
		for i = 1, #args, 2 do
			table.insert(list, {args[i], args[i + 1]})
		end

		res = entity:action(sk, list)
	else
		res = entity:action(sk, table.unpack(args))
	end

	if not res then
		error("技能 " .. cli.translate(sk.name, entity.name) .. " 失败")
	end

	return true
end

local function player_control(map, tid)
	while true do
		local team = show_map(map, tid)
		if #team == 0 then
			print(cli.color("游戏结束", "green"))
			os.exit()
		end
		local selection
		while true do
			print(cli.color("\n选择角色，0结束回合", "green"))
			selection = tonumber(io.read())
			if math.type(selection) == "integer" and selection >= 0 and selection <= #team then
				break
			end
		end

		if selection == 0 then
			break
		end

		local entity = team[selection]
		show_layer(map, entity.element)
		show_entity(entity)
		if not entity.active then
			print(cli.color("\n没有可用操作", "green"))
		else
			while true do
				local suc, res = pcall(action_menu, entity)
				if suc then
					if not res or not entity.active then
						break
					end
					show_entity(entity)
				else
					print(res)
				end
			end

		end
	end

end

local function enemy_control(map, tid)
	local team = map:get_team(tid)
	if #team == 0 then
		print(cli.color("游戏结束", "green"))
		os.exit()
	end
	for k, e in pairs(team) do
		e:action(e.skills[1])
	end
end

local function main()
	local map_scale = 8

	util.random_setup("lcg")

	local map = require("map")(map_scale, {
		"ether",
		"air",
		"fire",
		"water",
		-- "earth",
	})
	local player_team = map:new_team(util.merge_table(util.copy_table(cli.ui_table), {ui = player_control}))

	map:spawn(player_team, "shian", {1, 5})
	map:spawn(player_team, "chiyu", {0, 0})
	map:spawn(player_team, "cangqiong", {1, 0})
	map:spawn(player_team, "stardust", {1, 4})
	map:spawn(player_team, "haiyi", {1, 1})

	local enemy_team = map:new_team(util.merge_table(util.copy_table(cli.ui_table), {ui = enemy_control}))
	for n = 1, 10, 1 do
		local d = util.random("uniform", 0, map_scale)
		local i = util.random("uniform", 0, math.max(d * 6 - 1, 0))
		map:spawn(enemy_team, "toolman", {d, i})
	end

	map:run()
end

main()
