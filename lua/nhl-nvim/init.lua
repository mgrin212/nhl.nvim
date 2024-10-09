local M = {}

-- Configuration
M.config = {
	update_interval = 10000,
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.toggle_scoreboard()
	require("nhl.nvim").toggle_scoreboard()
end

-- Create the user command
vim.api.nvim_create_user_command("HockeyScoreboard", M.toggle_scoreboard, {})

return M
