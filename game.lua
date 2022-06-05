#!/usr/bin/env lua

-- print(package.path)
package.path = package.path .. ';' .. "./core/?.lua" .. ';' .. "./base/?.lua"

local map = require("map")
local util = require("util")
local core = require("core")
local hexagon = require("hexagon")
local cli = require("cli")

local function show_detail(entity)
	cli.show_banner("lang.entity")
	cli.show_entity(entity, print)

	cli.show_banner("lang.item")
	cli.show_item(entity, function(str, item)
		print(str)
	end)

	for i, sk in ipairs(entity.skills) do
		sk:update()
	end

	cli.show_banner("lang.skill")
	local i = 1
	cli.show_skill(entity, function(str, sk)
		if i % 2 == 0 then
			str = cli.color({}) .. str .. cli.color()
		end
		print(i .. '\t' .. str)
		i = i + 1
	end)
end

local function action_menu(entity)
	while true do
		local sk
		local args
		while true do
			print(cli.color("green") .. cli.translate("ui.skill_select") .. cli.color())
			io.write(cli.color({fg = "red", bg = "green"}))
			local cmd = io.read()
			print(cli.color())
			if cmd == "?" then
				print(cli.translate("ui.skill_help"))
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
		elseif sk.type == "line" then
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

		if res then
			return true
		end

		print(cli.color("green") .. cli.translate("ui.skill_failed") .. cli.color() .. ' ' .. cli.translate(sk.name))
	end
end

local function player_control(map, tid)
	while true do
		local team = {}
		cli.show_banner("lang.map")
		cli.show_map(map, function(str, entity)
			if entity.team == tid then
				local i = #team + 1
				print(i .. '\t' .. str)
				team[i] = entity
			else
				print("-\t" .. str)
			end
		end)
		if #team == 0 then
			print(cli.color({fg = "red", bg = "cyan"}) .. cli.translate("ui.game_lose") .. cli.color())
			return false
		end
		local selection
		while true do
			print(cli.color("green") .. cli.translate("ui.entity_select") .. cli.color())
			io.write(cli.color({fg = "red", bg = "green"}))
			local str = io.read()
			print(cli.color())

			if str == "x" then
				print(cli.color({fg = "red", bg = "cyan"}) .. cli.translate("ui.map_exit") .. cli.color())
				return false
			end

			selection = tonumber(str)
			if math.type(selection) == "integer" and selection >= 0 and selection <= #team then
				break
			end
		end

		if selection == 0 then
			return true
		end

		local entity = team[selection]
		local i = 1
		cli.show_banner("lang.layer", cli.translate(entity.element, "element"))
		cli.show_layer(map, entity.element, function(str)
			if i % 2 == 0 then
				str = cli.color({}) .. str .. cli.color()
			end
			print(str)
			i = i + 1
		end)

		show_detail(entity)

		if not entity.active then
			print(cli.color("green") .. cli.translate("ui.entity_inactive") .. cli.color())
		else
			while true do
				local res = action_menu(entity)
				if not res or not entity.active then
					break
				end
				show_detail(entity)
			end

		end
	end

end

local function enemy_control(map, tid)
	local team = map:get_team(tid)
	if #team == 0 then
		print(cli.color({fg = "red", bg = "cyan"}) .. cli.translate("ui.game_win") .. cli.color())
		return false
	end
	for k, e in pairs(team) do
		e:action(e.skills[1])
	end
	return true
end

local function main(map_list)
	util.random_setup("lcg")

	for i = 1, #map_list, 1 do
		local name = map_list[i]
		if string.sub(name, -4) == ".lua" then
			name = string.sub(name, 1, -5)
		end

		print(cli.color({fg = "red", bg = "cyan"}) .. cli.translate("ui.map_load") .. name .. cli.color())
		local res, map_info = pcall(require, name)
		if res and type(map_info) == "table" then
			-- assume first team is player team

			for i = 1, #map_info.teams, 1 do
				local team = map_info.teams[i]
				local ui = util.copy_table(cli.event_table)
				if i == 1 then
					ui.ui = player_control
				else
					ui.ui = enemy_control
				end
				team.ui = ui
			end

			map(map_info):run()
		else
			print(cli.color({fg = "red", bg = "cyan"}) .. cli.translate("ui.map_failed") .. name .. " (" .. map_info .. ')' .. cli.color())
			break
		end
	end
end

-- for windows platform
os.setlocale(".utf8")
cli.set("locale", "zh-cn")
cli.set("color", true)

if #arg > 0 then
	main(arg)
else
	print(arg[0] .. " map_1 [map_2] ...")
end
