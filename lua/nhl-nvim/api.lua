local plenary = require("plenary.curl")
local Utils = require("nhl-nvim.utils")

local M = {}

function M.fetch_games()
	local res = plenary.get("https://api-web.nhle.com/v1/score/2024-10-09")
	return Utils.parse_games(res.body)
end

return M
