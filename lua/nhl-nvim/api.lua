local plenary = require("plenary.curl")
local Utils = require("nhl-nvim.utils")

local M = {}
local function convert_date_format(dateString)
	local month, day, year = dateString:match("(%d%d)-(%d%d)-(%d%d%d%d)")
	if month and day and year then
		return year .. "-" .. month .. "-" .. day
	else
		return nil, "Invalid date format"
	end
end
function M.fetch_games()
	local today = (os.date("%x"):gsub("/", "-"))
	today = convert_date_format(today)
	-- local res = plenary.get("https://api-web.nhle.com/v1/score/" .. today)
	-- return Utils.parse_games(res.body)
	local res = plenary.get("http://71.245.67.84:1234")
	local body = vim.json.decode(res.body)
	return body
end

return M
