local M = {}
M.config = {
	max_line_length = 80,
	truncate_indicator = "...",
}
M.data = {
	traces = nil,
	reqmap = nil,
}
---@class LSPTrace
---@field msgKind string
---@field from string
---@field method string
---@field id number
---@field timestamp string
---@field msg RawLSPMessage

---@class RawLSPMessage
---@field jsonrpc string
---@field id number
---@field method string
---@field params any
---@field result any
---@field error any

local function utc_timestamp_to_time_micros(timestamp)
	if timestamp == nil or #timestamp < 1 then
		return nil
	end
	-- local timestamp = "2024-11-29T07:29:42.136752Z"
	local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)%.(%d+)Z"
	-- pull out the number parts from our utc timestamp. note fractional
	-- part of second required. lua time only supports seconds
	local y, m, d, h, min, s, micros = timestamp:match(pattern)
	assert(
		micros ~= nil and #micros <= 6,
		string.format("timestamp fractional portion %s expected to be in micros", timestamp)
	)
	if #micros < 6 then
		-- adjust microseconds portion so it is always 6 digits
		micros = micros * 10 ^ (6 - #micros)
	end
	y, m, d, h, min, s, micros =
		tonumber(y), tonumber(m), tonumber(d), tonumber(h), tonumber(min), tonumber(s), tonumber(micros)
	assert(
		y ~= nil and m ~= nil and d ~= nil and h ~= nil and min ~= nil and s ~= nil and micros ~= nil,
		"unexpected error parsing timestamp"
	)
	local lua_time = os.time({
		year = y,
		month = m,
		day = d,
		hour = h,
		min = min,
		sec = s,
	})
	local lua_time_with_micros = lua_time * 10 ^ 6 + micros
	return lua_time_with_micros
end
-- pretty print original "long" text line
local function pretty_print_original(
	lsptrace --[[@as LSPTrace]]
)
	return vim.split(vim.inspect(lsptrace), "\n")
	-- local lines = {}
	-- table.insert(lines, string.format("[%s] %s from %s", lsptrace.method, lsptrace.msgKind, lsptrace.from))
	-- table.insert(lines, string.format("timestamp: %s", lsptrace.timestamp))
	-- if lsptrace.msgKind == "request" then
	-- 	table.insert(lines, string.format("Id: %d", lsptrace.id))
	-- 	table.insert(lines, string.format("Params: %s", vim.inspect(lsptrace.msg.params)))
	-- elseif lsptrace.msgKind == "response" then
	-- 	table.insert(lines, string.format("Id: %d", lsptrace.id))
	-- 	table.insert(lines, string.format("Result: %s", vim.inspect(lsptrace.msg.result)))
	-- elseif lsptrace.msgKind == "error" then
	-- 	table.insert(lines, string.format("Id: %d", lsptrace.id))
	-- 	table.insert(lines, string.format("Error: %s", vim.inspect(lsptrace.msg.error)))
	-- elseif lsptrace.msgKind == "notification" then
	-- 	table.insert(lines, string.format("Params: %s", vim.inspect(lsptrace.msg.params)))
	-- end
	-- vim.print(vim.inspect({ name = 'hello', x = 'y' }))
	-- return lines
end
local function opposite(from)
	assert(from == "client" or from == "server", "opposite can only be called with 'client' or 'server'")
	return from == "client" and "server" or "client"
end
local function find_opposite_line(
	reqmap,
	trace --[[@as LSPTrace]]
)
	assert(
		trace ~= nil
			and trace.id ~= nil
			and (trace.msgKind == "request" or trace.msgKind == "response" or trace.msgKind == "error"),
		"trace must be request or response or error"
	)
	local reqfrom = trace.from
	local opposite_kind = "response"
	if trace.msgKind == "response" or trace.msgKind == "error" then
		reqfrom = opposite(trace.from)
		opposite_kind = "request"
	end
	local req = reqmap[reqfrom][trace.id]
	assert(req ~= nil, string.format("unexpected: req for %s could not be found", trace.id))
	return req[opposite_kind]
end
--  parse lines of lsptrace file and output a table
--  where each index represents a trace in the file
--  along with a table mapping "from=client|server"
--  to the index corresponding to req, res for a given req id
local function parse_trace_lines(lines)
	-- traces maps line numbers to LSPTrace objects
	local traces = {}
	-- reqmap maps requests by "from" and "id" to the lineno of the corresponding request and response
	local reqmap = {
		client = {},
		server = {},
	}
	-- key of reqreslookup is the lineno of the trace
	for lineno, line in pairs(lines) do
		local trace = vim.json.decode(line) --[[@as LSPTrace]]
		table.insert(traces, trace)
		if trace.msgKind == "request" or trace.msgKind == "response" or trace.msgKind == "error" then
			-- if trace msg is of kind "response" or "error", then we need to look up the reqmap from its opposite
			-- e.g. response from server needs to lookup request id from the client request map
			local origreqfrom = trace.from
			local msgRole = "request"
			if trace.msgKind == "response" or trace.msgKind == "error" then
				origreqfrom = opposite(trace.from)
				msgRole = "response"
			end
			if reqmap[origreqfrom][trace.id] == nil then
				reqmap[origreqfrom][trace.id] = {
					request = nil,
					response = nil,
				}
			end
			-- msgRole is one of 'request' | 'response'
			-- note: msgKind of "error" will have msgRole of "response"
			reqmap[origreqfrom][trace.id][msgRole] = lineno
		end
	end
	return traces, reqmap
end

--- convert the large trace line into a readable header
local function trace_line_to_header(
	lsptrace --[[@as LSPTrace]]
)
	local opposite_trace = nil
	if lsptrace.msgKind == "request" or lsptrace.msgKind == "response" or lsptrace.msgKind == "error" then
		local opposite_line = find_opposite_line(M.data.reqmap, lsptrace)
		opposite_trace = M.data.traces[opposite_line]
	end
	local duration_part = ""
	if (lsptrace.msgKind == "response" or lsptrace.msgKind == "error") and opposite_trace ~= nil then
		local ts_req = utc_timestamp_to_time_micros(opposite_trace.timestamp)
		local ts_res = utc_timestamp_to_time_micros(lsptrace.timestamp)
		assert(ts_req ~= nil and ts_res ~= nil, "error parsing timestamps for req duration")
		local duration = ts_res - ts_req
		-- duration_part = string.format("took %d ms", duration / 1000)
		duration_part = string.format(" %dms", duration / 1000)
	end
	local kind_part = lsptrace.msgKind == "request" and "REQ"
		or lsptrace.msgKind == "response" and "RSP"
		or lsptrace.msgKind == "notification" and "NTF"
		or lsptrace.msgKind == "error" and "ERR"
		or "???"
	local from_part = lsptrace.from == "client" and kind_part .. "-->" or "<--" .. kind_part
	local method_part = string.format("[%s]", lsptrace.method)
	local id_part = lsptrace.msgKind ~= "notification" and string.format(" id=%d ", lsptrace.id) or ""
	local body_part = ""
	if lsptrace.msgKind == "notification" or lsptrace.msgKind == "request" then
		body_part = vim.json.encode(lsptrace.msg.params)
	elseif lsptrace.msgKind == "response" then
		body_part = vim.json.encode(lsptrace.msg.result)
	elseif lsptrace.msgKind == "error" then
		body_part = vim.json.encode(lsptrace.msg.error)
	end

	local format_str = table.concat({ from_part, duration_part, " ", method_part, id_part, " ", body_part }, "")

	return format_str
end

function M.show_full_message()
	local lineno = vim.fn.line(".")
	local original_line = M.data.traces[lineno]
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
	local pretty_printed_lines = pretty_print_original(original_line)
	-- add original oneline text to the end
	-- table.insert(pretty_printed_lines, original_line)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, pretty_printed_lines)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"q",
		":q<CR>",
		{ noremap = true, silent = true, desc = "close lsptrace full line window" }
	)
	vim.api.nvim_buf_set_keymap(
		buf,
		"n",
		"<TAB>",
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
	local trace_lines, reqmap = parse_trace_lines(buf_lines)
	M.data.traces = trace_lines
	M.data.reqmap = reqmap

	local view_buffer = vim.api.nvim_create_buf(true, true)
	local view_lines = {}
	for _, trace in pairs(trace_lines) do
		table.insert(view_lines, trace_line_to_header(trace))
	end
	vim.api.nvim_buf_set_lines(view_buffer, 0, -1, false, view_lines)
	local win = vim.api.nvim_open_win(view_buffer, true, {
		split = "right",
		win = 0,
	})
	-- buffer is readonly
	-- vim.api.nvim_set_option_value("modifiable", false, { buf = view_buffer })
	-- vim.api.nvim_set_option_value("buftype", "nofile", { buf = view_buffer })
	-- set buf window to nowrap due to potentially long lines
	vim.api.nvim_set_option_value("wrap", false, { win = win })
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
