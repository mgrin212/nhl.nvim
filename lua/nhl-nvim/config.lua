local M = {}

M.default_config = {
	update_interval = 10000,
	window_size = "40",
	colors = {
		bg = "#1e1e1e",
		fg = "#ffffff",
		period_bg = "#4CAF50",
		time_bg = "#2c2c2c",
		sog = "#888888",
		border = "#3a3a3a",
	},
}

M.config = M.default_config

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.default_config, opts or {})
end

function M.get()
	return M.config
end

return M
