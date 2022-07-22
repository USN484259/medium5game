local util = require("core/util")
local gl = require("moongl")
local glfw = require("moonglfw")
local misc = require("gl/misc")
local motion = require("gl/motion")

local window_record = {}

local function step(self)
	local window = self.window
	if glfw.window_should_close(window) then
		return false
	end

	gl.clear("color")

	local w, h = glfw.get_window_size(window)
	local t = glfw.get_time()

	for i, e in ipairs(self.element_table) do
		e:render(t, w, h)
	end

	glfw.swap_buffers(window)

	glfw.poll_events()
	return true
end

local function clear(self)
	self.element_table = {}
	self.handler_table = {}
	self.schedule_table = {}
	self.motion_group:reset()
end

local function add(self, element)
	local layer_cmp = function(a, b)
		return a.layer < b.layer
	end

	table.insert(self.element_table, element)
	util.stable_sort(self.element_table, layer_cmp)

	if element.handler then
		table.insert(self.handler_table, element)
		util.stable_sort(self.handler_table, layer_cmp)
	end
end

local function remove(self, element)
	for i, e in ipairs(self.element_table) do
		if e == element then
			e.handler = nil
			table.remove(self.element_table, i)
			break
		end
	end
end

local function schedule(self, func, ...)
	table.insert(self.schedule_table, table.pack(func, ...))
end

local function run(self, func, ...)
	while true do
		if not step(self) then
			return
		end

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

local function motion_group()
	return {
		list = {},
		add = function(self, element, motion)
			local orig_done = motion.done
			motion.done = function(s, e, t)
				if orig_done then
					orig_done(s, e, t)
				end
				self.count = self.count - 1
			end
			table.insert(self.list, {element, motion})
		end,
		commit = function(self)
			local time = glfw.get_time()
			self.count = #self.list
			for i, v in ipairs(self.list) do
				motion.add(v[1], v[2], time)
			end

			self.list = nil
		end,
		check = function(self)
			return self.count == 0
		end,
		reset = function(self)
			self.list = {}
			self.count = nil
		end,
	}
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
		elseif e:handler(window, event, info) then
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
	-- print(ev)

	return on_event(window, ev)
end

local function new_window(title, w, h)
	w = w or 800
	h = h or 600
	title = title or "moonglfw"

	glfw.window_hint('context version major', 3)
	glfw.window_hint('context version minor', 3)
	glfw.window_hint('opengl profile', 'core')
	local window = glfw.create_window(w, h, title)
	glfw.make_context_current(window)
	gl.init()
	gl.clear_color(1, 1, 1, 1)

	gl.enable("blend")
	gl.blend_func("src alpha", "one minus src alpha")
	gl.pixel_store("unpack alignment", 1)

	glfw.set_window_size_callback(window, on_resize)
	glfw.set_key_callback(window, on_key)
	glfw.set_mouse_button_callback(window, on_mouse)
	glfw.set_cursor_pos_callback(window, on_move)
	glfw.set_scroll_callback(window, on_scroll)
	glfw.set_cursor_enter_callback(window, on_enter)

	local res = {
		window = window,
		element_table = {},
		handler_table = {},
		schedule_table = {},
		motion_group = motion_group(),

		clear = clear,
		add = add,
		remove = remove,
		schedule = schedule,
		run = run,
	}
	window_record[window] = res

	return res
end

return {
	new_window = new_window,
}
