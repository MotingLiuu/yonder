local M = {}
-- local means M only can be accessed from this file

M.config = {
	python = nil,
    -- nil is python's None. This is the path of the python executable.
	notes = vim.fn.expand("~/notes/japanese/vocab.md"),
    -- vim.fn is the bridge to vimscript's built-in function
    -- expand is used to expand the path of the file, ~ will be expanded to the home directory, Users/mutyuu
}

local function backend_path()
	local paths =
		vim.api.nvim_get_runtime_file(
            -- Question: what does runtimepath contain?
            -- jsut like $PATH 
            -- it contains User config folder ~/.config/nvim
            -- root folder of the plugins installed
            -- neovim's runtime pakcage path
			"python/yonder_backend.py",
			false
		)

	return paths[1]
    -- Question: what does paths contain? why return paths[1]?
    -- paths contains all of the path
    -- paths[1] is the first path, lua starts from index 1 not 0
end


-- get the content of the visual selection
local function get_visual_selection()
    -- local function means this is a local function, not a global function
	-- 用 z 寄存器，避免破坏默认 unnamed register
	vim.cmd('normal! "zy')
    -- vim.cmd() means execute vimscript command
    -- Question: what is zy? what is register z?
    -- in vim this is an unnamed register, y copy and d cut, the content is stored in this register 
    -- vim provides 26 registers a-z, z is the 26th register

	return vim.fn.getreg("z")
    -- vim.fn.getreg() means get the content of register z
end

local function get_cursor_context()
	local pos = vim.api.nvim_win_get_cursor(0)
    -- get the cursor position of the current window(0)
    -- pos {row_num, col_num}

	return {
		line = vim.api.nvim_get_current_line(),
        -- get the string of the current line
		col = pos[2], -- 0-based BYTE offset
	}
end


local function show_result(data)
	local lines = {}

	table.insert(
		lines,
		"# " .. (data.query or "")
	)

	table.insert(lines, "")

	if data.term then
		table.insert(
			lines,
			"**辞書形:** " .. data.term
		)

		table.insert(
			lines,
			"**読み:** " .. (data.reading or "")
		)
	end

	if data.tokens and #data.tokens > 0 then
		table.insert(lines, "")
		table.insert(lines, "## 形態素解析")

		for _, token in ipairs(data.tokens) do
			table.insert(
				lines,
				string.format(
					"- `%s` → **%s** (%s)",
					token.surface,
					token.dictionary_form,
					token.reading
				)
			)
		end
	end

	if data.entries and #data.entries > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Dictionary")

		for i, entry in ipairs(data.entries) do
			table.insert(
				lines,
				string.format(
					"%d. %s",
					i,
					entry
				)
			)
		end
	else
		table.insert(lines, "")
		table.insert(lines, "_No entry found_")
	end

	local bufnr, winid = vim.lsp.util.open_floating_preview(
		lines,
		"markdown",
		{
			border = "rounded",
			max_width = 80,
			max_height = 30,
            foucusable = true,
		}
	)

    if winid and vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_set_current_win(winid)

        vim.keymap.set("n", "q", "<cmd>close<CR>", {
            buffer = bufnr,
            silent = true,
            nowait = true,
        })
        vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", {
            buffer = bufnr,
            silent = true,
            nowait = true,
        })
    end
end


local function lookup_cursor(line, col, callback)
	local script = backend_path()

	vim.system(
		{
			M.config.python,
			script,
			"cursor",
			line,
			tostring(col),
		},
		{
			text = true,
		},
		function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					vim.notify(
						result.stderr,
						vim.log.levels.ERROR
					)
					return
				end

				local ok, data =
					pcall(
						vim.json.decode,
						result.stdout
					)

				if not ok then
					vim.notify(
						"jpdict: invalid JSON",
						vim.log.levels.ERROR
					)
					return
				end

				callback(data)
			end)
		end
	)
end


function M.lookup_cursor()
    -- Question: what does M mean? what is the relationship of local M and M used in here?
	local ctx = get_cursor_context()

	lookup_cursor(ctx.line, ctx.col, show_result)
end


-- 1.call python backend to parse the text and return the result
-- 2.callback(show_result) to open a new floating window to show the result
local function lookup(text, callback)
	local script = backend_path()

	if not script then
		vim.notify(
			"yonder: backend not found",
			vim.log.levels.ERROR
		)
		return
	end

	vim.system(
        -- background job vim.system({cmd, ...}, opts, on_exit)
        -- loading a python script comsumes 0.1-0.5s
		{
			M.config.python,
			script,
			text,
		},
        -- thie equals to python3 /path/to/yonder_backend.py "text"
		{
			text = true,
		},
        -- transform the result from Raw Bytes to a String
		function(result)
            -- when Python exits, the table including the result is passed to this function
            -- result.code exit code
            -- result.stdout stdout writted by Python
            -- result.stderr stderr writted by Python(Traceback)
			vim.schedule(function()
				if result.code ~= 0 then
                    -- result.code is not 0, it means Python exited with error
					vim.notify(
						result.stderr,
						vim.log.levels.ERROR
					)
					return
				end

				local ok, data =
                -- lua's pcall is similar to Python's try...catch
                -- if success, ok is true, else ok is false
					pcall(
						vim.json.decode,
						result.stdout
					)

				if not ok then
					vim.notify(
						"yonder: invalid JSON",
						vim.log.levels.ERROR
					)
					return
				end

				callback(data)
                -- Question: what does callback(data) do exactly?
                -- show_reusult is a pointer to show_result()
			end)
		end
	)
end


function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    -- merge the opts into M.config

	vim.keymap.set("x", "<leader>jd", function()
        -- "x" means the mode is visual mode
		local text = get_visual_selection()
        lookup(text, show_result)
	end, {
		desc = "Japanese dictionary lookup",
	})

    vim.keymap.set("n", "<leader>jd", function()
        require("yonder").lookup_cursor()
    end, {
        desc = "Japanese dictionary lookup",
    })
end

return M
