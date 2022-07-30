local util = require("core/util")
local gl = require("moongl")
local glfw = require("moonglfw")
local misc = require("gl/misc")
local motion = require("gl/motion")


local element_table = {
	map = require("gl/map"),
	image = require("gl/image"),
	text = require("gl/text"),
}

local window_record = {}


local function new_element(window, parent)
	return {
		window = window,
		parent = parent,
		layer = misc.layer.common,
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
		render = function() end,
		close = function(self)
			for i, v in ipairs(self.children) do
				v:close()
			end
			self.signalled = true
			self.children = {}
		end,
		remove = function(self, obj)
			for i, v in ipairs(self.children) do
				if obj == v then
					table.remove(self.children, i)
					break
				end
			end
			obj:close()
			obj.handler = nil
		end,
		add = function(self, element_info)
			local func = element_table[element_info.type].new
			if not func then
				error("unknown element type " .. element_info.type)
			end

			local element = util.merge_table(new_element(self.window, self), func(table.unpack(element_info.args or {})))
			element = util.merge_table(element, element_info.overrides or {})

			table.insert(self.children, element)

			if element.handler then
				table.insert(self.window.handler_table, element)
				util.stable_sort(self.window.handler_table, function(a, b)
					return a.layer < b.layer
				end)
			end

			return element
		end,
	}
end


local function clear(self)
	self.root:close()

	self.handler_table = {}
	self.schedule_table = {}
	self.root = new_element(self)
end

local function schedule(self, func, ...)
	table.insert(self.schedule_table, table.pack(func, ...))
end

local function step(queue, element, hidden, t)
	local count = motion.apply(element, t)

	hidden = hidden or element.hidden
	if hidden then
		return count
	end

	-- element:render(t, w, h)
	table.insert(queue, element)

	for i, e in ipairs(element.children) do
		count = count + step(queue, e, hidden, t)
	end

	return count
end

local function run(self, func, ...)
	while true do
		local window = self.window
		if glfw.window_should_close(window) then
			return
		end

		gl.clear("color")

		local w, h = glfw.get_window_size(window)
		local t = glfw.get_time()
		local queue = {}

		self.motion_count = step(queue, self.root, false, t)

		util.stable_sort(queue, function(a, b)
			return a.layer < b.layer
		end)

		for i, v in ipairs(queue) do
			v:render(t, w, h)
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
		handler_table = {},
		schedule_table = {},

		clear = clear,
		schedule = schedule,
		run = run,
	}
	res.root = new_element(res)

	window_record[window] = res

	return res
end

return {
	new_window = new_window,
}
