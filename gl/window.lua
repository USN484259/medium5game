local util = require("core/util")
local gl = require("moongl")
local glfw = require("moonglfw")
local misc = require("gl/misc")
local motion = require("gl/motion")


local element_table = {
	-- basic elements
	hub = {
		new = function(element)
			return element
		end,
	},
	map = require("gl/map"),
	image = require("gl/image"),
	text = require("gl/text"),
	box = require("gl/box"),
	hexagon = require("gl/hexagon"),

	-- combined elements
	button = require("gl/button"),
	-- list = require("gl/list"),
	-- progress = require("gl/progress"),
}

local window_record = {}

local function close_element(element)
	for i, e in ipairs(element.children) do
		close_element(e)
	end

	element.signalled = true
	element.handler = nil
	element.children = nil
	element:close()
end


local function new_element(window, parent, info)
	return util.merge_table({
		window = window,
		parent = parent,
		layer = parent and parent.layer or nil,
		signalled = false,
		hidden = false,
		children = {},
		motion_list = {},
		signal = function(self)
			self.signalled = true
		end,
		is_signalled = function(self)
			return self.signalled
		end,
		close = function(self) end,
		remove = function(self, obj)
			if not obj then return end

			for i, v in ipairs(self.children) do
				if obj == v then
					table.remove(self.children, i)
					break
				end
			end
			close_element(obj)
		end,
		add = function(self, element_info)
			local func

			if element_table[element_info.type] then
				func = element_table[element_info.type].new
			else
				error("unknown element type " .. element_info.type)
			end

			local element = func(new_element(self.window, self, element_info))

			table.insert(self.children, element)

			if element.handler then
				table.insert(self.window.handler_table, element)
				util.stable_sort(self.window.handler_table, function(a, b)
					return a.layer < b.layer
				end)
			end

			return element
		end,
		clear = function(self)
			for i, e in ipairs(self.children) do
				close_element(e)
			end
			self.children = {}
		end,
	}, info)
end

local function clear(self, color)
	close_element(self.root)

	self.handler_table = {}
	self.schedule_table = {}
	self.root = new_element(self, nil, {
		type = "root",
	})

	glfw.make_context_current(self.window)
	gl.clear_color(table.unpack(color or {1, 1, 1, 1}))
end

local function schedule(self, func, ...)
	table.insert(self.schedule_table, table.pack(func, ...))
end

local function step(queue, element, t, aspect_ratio)
	local count = motion.apply(element, t, aspect_ratio)

	if element.hidden then
		return count
	end

	if element.offset then
		local ref = element.parent and element.parent.pos or {0, 0}
		element.pos = {
			ref[1] + element.offset[1],
			ref[2] + element.offset[2],
		}
	end

	if element.render then
		table.insert(queue, element)
	end

	for i, e in ipairs(element.children) do
		count = count + step(queue, e, t, aspect_ratio)
	end

	return count
end

local function run(self, func, ...)
	while true do
		local window = self.window
		if glfw.window_should_close(window) then
			return
		end

		glfw.make_context_current(window)
		gl.clear("color")

		local w, h = glfw.get_window_size(window)
		local aspect_ratio = h / w
		local t = glfw.get_time()
		local queue = {}

		self.motion_count = step(queue, self.root, t, aspect_ratio)

		util.stable_sort(queue, function(a, b)
			return a.layer < b.layer
		end)

		for i, e in ipairs(queue) do
			e:render(aspect_ratio)
		end

		glfw.swap_buffers(window)
		glfw.poll_events()

		local sched = self.schedule_table
		self.schedule_table = {}

		for i, v in ipairs(sched) do
			v[1](table.unpack(v, 2))
		end

		if func then
			local res = func(self, ...)
			if type(res) ~= "nil" then
				return res
			end
		end
	end

end

local function on_resize(window, w, h)
	gl.viewport(0, 0, w, h)
end

local function on_event(wid, event, info)
	local window = window_record[wid]
	if type(window) ~= "table" or #window.handler_table == 0 then
		return
	end

	-- translate pos
	if info and info.pos then
		local x, y = table.unpack(info.pos)
		local w, h = glfw.get_window_size(wid)
		local ratio = h / (2 * misc.coordinate_radix)
		info.pos = {
			(x - w / 2) / ratio,
			misc.coordinate_radix - y / ratio,
		}
	end

	for i = #window.handler_table, 1, -1 do
		local e = window.handler_table[i]
		if not e.handler then
			table.remove(window.handler_table, i)
		elseif not e.hidden and e:handler(window, event, info) then
			break
		end
	end
end

local function on_key(window, key, scancode, action, shift, control, alt, super)
	local ev = "key_" .. action
	-- print(ev, key, action)

	local info = {
		key = key,
		scancode = scancode,
		shift = shift,
		control = control,
		alt = alt,
		super = super,
	}

	return on_event(window, ev, info)
end

local function on_mouse(window, button, action, shift, control, alt, super)
	local ev = "mouse_" .. action
	-- print(ev, button, action)

	local pos = table.pack(glfw.get_cursor_pos(window))
	local info = {
		button = button,
		pos = pos,
		shift = shift,
		control = control,
		alt = alt,
		super = super,
	}

	return on_event(window, ev, info)
end

local function on_move(window, x, y)
	local ev = "mouse_move"
	-- print(ev, x, y)

	local info = {
		pos = {x, y},
	}

	return on_event(window, ev, info)
end

local function on_scroll(window, x, y)
	local ev = "mouse_scroll"
	-- print(ev, x, y)

	local pos = table.pack(glfw.get_cursor_pos(window))
	local info = {
		pos = pos,
		offset = {x, y},
	}

	return on_event(window, ev, info)
end

local function on_enter(window, entered)
	local ev
	if entered then
		ev = "mouse_enter"
	else
		ev = "mouse_leave"
	end

	local pos = table.pack(glfw.get_cursor_pos(window))
	local info = {
		pos = pos,
		offset = {x, y},
	}

	return on_event(window, ev, info)
end

local function new_window(title, w, h)
	w = w or 800
	h = h or 600
	title = title or "moonglfw"

	glfw.window_hint('context version major', 3)
	glfw.window_hint('context version minor', 3)
	glfw.window_hint('opengl profile', 'core')
	glfw.window_hint('focused', false)
	-- glfw.window_hint('focus on show', false)
	local window = glfw.create_window(w, h, title)
	glfw.make_context_current(window)
	gl.init()
	gl.enable("blend")
	gl.blend_func("src alpha", "one minus src alpha")
	gl.pixel_store("unpack alignment", 1)
	gl.clear_color(1, 1, 1, 1)

	glfw.set_window_size_callback(window, on_resize)
	glfw.set_key_callback(window, on_key)
	glfw.set_mouse_button_callback(window, on_mouse)
	glfw.set_cursor_pos_callback(window, on_move)
	glfw.set_scroll_callback(window, on_scroll)
	glfw.set_cursor_enter_callback(window, on_enter)

	local res = {
		window = window,
		handler_table = {},
		schedule_table = {},

		clear = clear,
		schedule = schedule,
		run = run,
	}
	res.root = new_element(res, nil, {
		type = "root",
	})

	window_record[window] = res

	return res
end

return {
	new_window = new_window,
}
