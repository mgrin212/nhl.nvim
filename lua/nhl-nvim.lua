local Config = require("nhl-nvim.config")
local UI = require("nhl-nvim.ui")
local API = require("nhl-nvim.api")

local M = {}

function M.toggle_scoreboard()
	if UI.scoreboard.winid == nil then
		UI.mount_scoreboard()
		local games = API.fetch_games()
		UI.update_scoreboard(games)

		-- Set up auto-updating
		local timer = vim.uv.new_timer()
		timer:start(
			0,
			Config.get().update_interval,
			vim.schedule_wrap(function()
				games = API.fetch_games()
				UI.update_scoreboard(games)
			end)
		)

		-- Stop the timer when the window is closed
		UI.scoreboard:on(require("nui.utils.autocmd").event.BufWinLeave, function()
			timer:stop()
		end)
	else
		UI.unmount_scoreboard()
	end
end

function M.setup(opts)
	Config.setup(opts)
end

return M
