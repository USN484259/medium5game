local gl = require("moongl")
local glfw = require("moonglfw")


local function step(self)
	if glfw.window_should_close(self.window) then
		return false
	end

	glfw.poll_events()
	gl.clear("color")

	local w, h = glfw.get_window_size(self.window)

	for i, v in ipairs(self.layers) do
		v:render(w, h)
	end

	glfw.swap_buffers(self.window)
	return true
end

local function add(self, obj, pos)
	if pos then
		table.insert(self.layers, pos, obj)
	else
		table.insert(self.layers, obj)
	end
end

local function on_resize(window, w, h)
	gl.viewport(0, 0, w, h)
end

local function new_window(w, h, title)
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
	glfw.set_window_size_callback(window, on_resize)

	return {
		window = window,
		layers = {},
		step = step,
		add = add,
	}
end

return {
	new_window = new_window,
}
