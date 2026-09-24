local M = {}
-- local means M only can be accessed from this file

M.config = {
	python = nil,
    -- nil is python's None. This is the path of the python executable.
	notes = vim.fn.expand("~/notes/japanese/vocab.md"),
    -- vim.fn is the bridge to vimscript's built-in function
    -- expand is used to expand the path of the file, ~ will be expanded to the home directory, Users/mutyuu
}

-- get the content of the visual selection
local function get_visual_selection()
    -- local function means this is a local function, not a global function
	-- 用 z 寄存器，避免破坏默认 unnamed register
	vim.cmd('normal! "zy')
    -- vim.cmd() means execute vimscript command
    -- Question: what is zy? what is register z?

	return vim.fn.getreg("z")
    -- vim.fn.getreg() means get the content of register z
end

-- 
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    -- merge the opts into M.config

	vim.keymap.set("x", "<leader>jd", function()
        -- "x" means the mode is visual mode
		local text = get_visual_selection()
		print("selected:", text)
	end, {
		desc = "Japanese dictionary lookup",
	})
end

return M
