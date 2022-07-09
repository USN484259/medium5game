local gl = require("moongl")
local glfw = require("moonglfw")
local misc = require("gl/misc")

local element_table = {}
local handler_table = {}

local function step(self)
	local window = self.window
	if glfw.window_should_close(window) then
		return false
	end

	glfw.poll_events()
	gl.clear("color")

	local elements = element_table[window]

	local w, h = glfw.get_window_size(window)
	local t = glfw.get_time()

	for i, e in ipairs(elements) do
		e:render(t, w, h)
	end

	glfw.swap_buffers(window)
	return true
end

local function clear(self)
	local window = self.window
	element_table[window] = {}
	handler_table[window] = {}
end

local function add(self, element)
	local window = self.window
	local layer_cmp = function(a, b)
		return a.layer < b.layer
	end

	table.insert(element_table[window], element)
	table.sort(element_table[window], layer_cmp)

	if element.handler then
		table.insert(handler_table[window], element)
		table.sort(handler_table[window], layer_cmp)
	end
end

local function remove(self, element)
	local window = self.window
	local elements = element_table[window]
	for i, e in ipairs(elements) do
		if e == element then
			e.handler = nil
			table.remove(elements, i)
			break
		end
	end
end

local function on_resize(window, w, h)
	gl.viewport(0, 0, w, h)
end

local function on_event(window, event, info)
	local elements = handler_table[window]
	if #elements == 0 then
		return
	end

	-- translate pos
	if info and info.pos then
		local x, y = table.unpack(info.pos)
		local w, h = glfw.get_window_size(window)
		local ratio = h / (2 * misc.coordinate_radix)
		info.pos = {
			(x - w / 2) / ratio,
			misc.coordinate_radix - y / ratio,
		}
	end

	for i = #elements, 1, -1 do
		local e = elements[i]
		if not e.handler then
			table.remove(elements, i)
		elseif e:handler(event, info) then
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

	element_table[window] = {}
	handler_table[window] = {}

	return {
		window = window,
		step = step,
		clear = clear,
		add = add,
		remove = remove,
	}
end

return {
	new_window = new_window,
	get_time = glfw.get_time,
}
