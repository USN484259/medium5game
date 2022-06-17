#!/usr/bin/env lua

local version = { 0, 0, 1 }

local ui_color = "green"
local input_color = {fg = "red", bg = "cyan"}

local defaults = {
	locale = "zh-cn",
	color = true,
	map_folder = "maps",
	rng = "os",
	seed = nil,
}

local platform = require("lua_platform")
local cli = require("cli")

local map = require("core/map")
local util = require("core/util")
local core = require("core/core")

local function show_version()
	return version[1] .. '.' .. version[2] .. '.' .. version[3]
end

local function show_banner(name, postfix)
	local sep = "--------"
	local str = '\n' .. cli.color(ui_color) .. sep .. cli.translate(name)
	if postfix then
		str = str .. cli.color() .. ' ' .. postfix .. cli.color(ui_color)
	end
	str = str .. sep .. cli.color()
	print(str)
end

local function show_detail(entity)
	show_banner("lang.entity")
	cli.show_entity(entity, print)

	show_banner("lang.item")
	cli.show_item(entity, function(str, item)
		print(str)
	end)

	for i, sk in ipairs(entity.skills) do
		sk:update()
	end

	show_banner("lang.skill")
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
			print(cli.color(ui_color) .. cli.translate("ui.skill_select") .. cli.color())
			io.write(cli.color(input_color))
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

		print(cli.color(ui_color) .. cli.translate("ui.skill_failed") .. cli.color() .. ' ' .. cli.translate(sk.name))
	end
end

local function player_control(map, tid, round)
	while true do
		local team = {}
		show_banner("lang.map")
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
			print(cli.color(ui_color) .. cli.translate("ui.game_lose") .. cli.color())
			return false
		end
		local selection
		while true do
			print(cli.color(ui_color) .. cli.translate("ui.entity_select") .. cli.color())
			io.write(cli.color(input_color))
			local str = io.read()
			print(cli.color())

			if str == "x" then
				print(cli.color(ui_color) .. cli.translate("ui.map_exit") .. cli.color())
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
		show_banner("lang.layer", cli.translate(entity.element, "element"))
		cli.show_layer(map, entity.element, function(str)
			if i % 2 == 0 then
				str = cli.color({}) .. str .. cli.color()
			end
			print(str)
			i = i + 1
		end)

		show_detail(entity)

		if not entity.active then
			print(cli.color(ui_color) .. cli.translate("ui.entity_inactive") .. cli.color())
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

local function enemy_control(map, tid, round)
	local team = map:get_team(tid)
	if #team == 0 then
		print(cli.color(ui_color) .. cli.translate("ui.game_win") .. cli.color())
		return false
	end
	for k, e in pairs(team) do
		for i, sk in ipairs(e.skills) do
			e:action(sk)
		end
	end
	return true
end

local function main_menu(map_folder, map_list)
	show_banner("ui.game_menu")

	for i, v in ipairs(map_list) do
		local str = i .. '\t' .. v
		if i % 2 == 0 then
			str = cli.color({}) .. str .. cli.color()
		end
		print(str)
	end

	print(cli.color(ui_color) .. cli.translate("ui.map_select") .. cli.color())
	io.write(cli.color(input_color))
	local str = io.read()
	print(cli.color())
	if str == "x" then
		return false
	elseif str == "?" then
		print(cli.translate("ui.game_title") .. ' v' .. show_version() .. '\n' .. cli.translate("ui.game_about"))
	else
		local sel = tonumber(str)
		if map_list[sel] then
			local name = map_folder
			local sep = string.sub(package.config, 1, 1)
			if string.sub(name, -1) ~= sep then
				name = name .. sep
			end
			name = name .. map_list[sel]
			print(cli.color(ui_color) .. cli.translate("ui.map_load") .. name .. cli.color())

			local res, map_info = pcall(require, name)
			if res and type(map_info) == "table" then
				for i, v in ipairs(map_info.teams) do
					util.merge_table(v, cli.event_table)
					if type(v.round) == "string" then
						if v.round == "player" then
							v.round = player_control
						elseif v.round == "enemy" then
							v.round = enemy_control
						else
							error(v.round)
						end
					end
				end

				map(map_info):run()
			else
				print(cli.color(ui_color) .. cli.translate("ui.map_failed") .. name .. " (" .. map_info .. ')' .. cli.color())
			end
		end
	end

	return true
end

local function main(args)
	-- for windows platform
	os.setlocale(".utf8")

	local cfg = util.copy_table(defaults)
	for i = 1, #args, 1 do
		local option = args[i]
		if option == "-h" then
			print(args[0] .. ' ' .. "[options]")
			print("\t-l <locale>\tset locale")
			print("\t-c <on/off>\ttoggle color mode")
			print("\t-m <path>\tset map folder path")
			print("\t-r <rng>[,<seed>]\tset random source & seed")
			print("\t-h\tshow this help")
			-- print help
			return
		elseif option == "-l" then
			i = i + 1
			cfg.locale = args[i]
		elseif option == "-c" then
			i = i + 1
			local v = string.lower(args[i])
			if v == "on" or v == "true" or v == "yes" then
				cfg.color = true
			elseif v == "off" or v == "false" or v == "no" then
				cfg.color = false
			end
		elseif option == "-m" then
			i = i + 1
			cfg.map_folder = args[i]
		elseif option == "-r" then
			i = i + 1
			local v = args[i]
			local seed = nil
			local pos = string.find(v, ',')
			if pos then
				seed = tonumber(string.sub(v, pos + 1))
				v = string.sub(v, 1, pos - 1)
			end
			cfg.rng = v
			cfg.seed = seed
		else
			error("unknown option " .. option)
		end
	end

	util.random_setup(cfg.rng, cfg.seed or os.time())
	cli.set("locale", cfg.locale)
	cli.set("color", cfg.color)

	print(cli.color(ui_color) .. cli.translate("ui.game_title") .. ' v' .. show_version() .. cli.color())

	while true do
		local l = platform.ls(cfg.map_folder)
		local map_list = {}
		for k, v in pairs(l) do
			if v == "FILE" and string.lower(string.sub(k, -4)) == ".lua" then
				table.insert(map_list, string.sub(k, 1, -5))
			end
		end

		table.sort(map_list)
		if not main_menu(cfg.map_folder, map_list) then
			break
		end
	end

	print(cli.color(ui_color) .. cli.translate("ui.game_exit") .. cli.color())
end

main(arg)
