local M = {}
M.config = {
	max_line_length = 80,
	truncate_indicator = "...",
}
M.data = {
	trace_lines = nil,
}
local function parse_line(line)
	if #line <= M.config.max_line_length then
		return line
	end
	return line:sub(1, M.config.max_line_length - #M.config.truncate_indicator) .. M.config.truncate_indicator
end
function M.show_full_message()
	local lineno = vim.fn.line(".")
	local original_line = M.data.trace_lines[lineno]
	local buf = vim.api.nvim_create_buf(false, true)
	local width = vim.o.columns
	local height = vim.o.lines
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width - 10,
		height = height - 10,
		col = 5,
		row = 5,
		style = "minimal",
		border = "rounded",
	})
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { original_line })
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"q",
		":q<CR>",
		{ noremap = true, silent = true, desc = "close lsptrace full line window" }
	)
end
function M.view_lsptrace()
	local current_file = vim.fn.expand("%:p")
	local current_buffer = 0
	vim.print(vim.fn.expand("%:p"))
	vim.print(vim.fn.expand("%:t"))
	local buf_lines = vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false)
	M.data.trace_lines = buf_lines

	local view_buffer = vim.api.nvim_create_buf(true, true)
	local view_lines = {}
	for line in buf_lines do
		table.insert(view_lines, parse_line(line))
	end
	vim.api.nvim_buf_set_lines(view_buffer, 0, -1, false, view_lines)
	local win = vim.api.nvim_open_win(view_buffer, true, {
		split = "right",
		win = 0,
	})
	vim.api.nvim_buf_set_option(view_buffer, "modifiable", false)
	vim.api.nvim_buf_set_option(view_buffer, "buftype", "nofile")
	vim.api.nvim_buf_set_keymap(
		view_buffer,
		"n",
		"q",
		":q<CR>",
		{ noremap = true, silent = true, desc = "Close LSPTrace Viewer" }
	)

	vim.api.nvim_buf_set_keymap(
		view_buffer,
		"n",
		"<TAB>",
		':lua require("lsptrace").show_full_message()<CR>',
		{ noremap = true, silent = true, desc = "LSPTrace: Show full line" }
	)
end
function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)
	vim.api.nvim_create_user_command("LSPTraceView", M.view_lsptrace, {})
	vim.api.nvim_create_user_command("LSPTraceShowFullLine", M.show_full_message, {})
end
return M
