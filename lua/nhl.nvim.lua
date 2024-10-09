local api = vim.api
local Split = require("nui.split")
local event = require("nui.utils.autocmd").event
local plenary = require("plenary.curl")

local M = {}

local function parse_games(json_string)
	local data = vim.json.decode(json_string)
	local games = {}

	local function parse_utc_time(utc_string)
		local year, month, day, hour, min, sec = utc_string:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")
		return os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = sec })
	end

	local function parse_timezone_offset(offset_string)
		local sign, hours, minutes = offset_string:match("([+-])(%d%d):(%d%d)")
		local total_minutes = (sign == "-" and -1 or 1) * (tonumber(hours) * 60 + tonumber(minutes))
		return total_minutes * 60 -- Convert to seconds
	end

	local function format_time(timestamp, timezone_offset)
		local adjusted_time = timestamp + timezone_offset
		return os.date("%I:%M %p", adjusted_time)
	end

	for _, game in ipairs(data.games) do
		local eastern_offset = parse_timezone_offset(game.easternUTCOffset)
		local period, time
		if game.gameState == "LIVE" or game.gameState == "CRIT" then
			local period_num = game.period
			local suffix
			if period_num == 1 then
				suffix = "ST"
			elseif period_num == 2 then
				suffix = "ND"
			elseif period_num == 3 then
				suffix = "RD"
			else
				suffix = "TH"
			end
			period = tostring(period_num) .. suffix
			time = game.clock.timeRemaining
		elseif game.gameState == "PRE" or game.gameState == "FUT" then
			period = game.gameState
			local start_time = parse_utc_time(game.startTimeUTC)
			time = format_time(start_time, eastern_offset)
		else
			period = game.gameState
			time = "FINAL"
		end

		local home_logo = string.sub(game.homeTeam.abbrev, 1, 1)
		local away_logo = string.sub(game.awayTeam.abbrev, 1, 1)

		table.insert(games, {
			period = period,
			time = time,
			home_team = game.homeTeam.name.default,
			away_team = game.awayTeam.name.default,
			home_logo = home_logo,
			away_logo = away_logo,
			home_score = game.homeTeam.score or 0,
			away_score = game.awayTeam.score or 0,
			home_sog = game.homeTeam.sog or 0,
			away_sog = game.awayTeam.sog or 0,
		})
	end

	return games
end

-- Constants
local CONSTANTS = {
	UPDATE_INTERVAL = 10000,
	WINDOW_SIZE = "40",
	BG_COLOR = "#1e1e1e",
	FG_COLOR = "#ffffff",
	PERIOD_BG_COLOR = "#4CAF50",
	TIME_BG_COLOR = "#2c2c2c",
	SOG_COLOR = "#888888",
	BORDER_COLOR = "#3a3a3a",
}

-- Configuration
local config = {
	update_interval = CONSTANTS.UPDATE_INTERVAL,
}

-- Create a split for the scoreboard
local scoreboard = Split({
	relative = "editor",
	position = "right",
	size = CONSTANTS.WINDOW_SIZE,
	buf_options = {
		modifiable = false,
		readonly = true,
		filetype = "scoreboard",
	},
	win_options = {
		number = false,
		relativenumber = false,
		cursorline = false,
		cursorcolumn = false,
		foldcolumn = "0",
		signcolumn = "no",
		wrap = false,
	},
})

-- Function to create highlight groups
local function create_highlight_groups()
	local highlights = {
		ScoreboardBg = { bg = CONSTANTS.BG_COLOR, fg = CONSTANTS.FG_COLOR },
		ScoreboardPeriod = { fg = CONSTANTS.FG_COLOR, bg = CONSTANTS.PERIOD_BG_COLOR, bold = true },
		ScoreboardTime = { fg = CONSTANTS.FG_COLOR, bg = CONSTANTS.TIME_BG_COLOR, bold = true },
		ScoreboardTeamName = { fg = CONSTANTS.FG_COLOR, bg = CONSTANTS.BG_COLOR, bold = true },
		ScoreboardSOG = { fg = CONSTANTS.SOG_COLOR, bg = CONSTANTS.BG_COLOR },
		ScoreboardScore = { fg = CONSTANTS.FG_COLOR, bg = CONSTANTS.BG_COLOR, bold = true },
		ScoreboardBorder = { fg = CONSTANTS.BORDER_COLOR, bg = CONSTANTS.BG_COLOR },
	}

	for name, opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

-- Function to set a line with highlight
local function set_highlighted_line(bufnr, line_num, content, hl_group)
	api.nvim_buf_set_lines(bufnr, line_num, line_num + 1, false, { content })
	if hl_group then
		api.nvim_buf_add_highlight(bufnr, -1, hl_group, line_num, 0, -1)
	end
end

-- Function to draw a border
local function draw_border(bufnr, start_line, end_line)
	set_highlighted_line(
		bufnr,
		start_line,
		"╭──────────────────────────────────╮",
		"ScoreboardBorder"
	)
	for i = start_line + 1, end_line - 1 do
		set_highlighted_line(bufnr, i, "│                                  │", "ScoreboardBorder")
	end
	set_highlighted_line(
		bufnr,
		end_line,
		"╰──────────────────────────────────╯",
		"ScoreboardBorder"
	)
end

-- Function to update a single game
local function update_game(bufnr, game, current_line)
	draw_border(bufnr, current_line, current_line + 8)

	-- Header
	set_highlighted_line(
		bufnr,
		current_line + 1,
		string.format("│ %-32s │", string.format("%s  %s", game.period, game.time)),
		"ScoreboardBg"
	)
	api.nvim_buf_add_highlight(bufnr, -1, "ScoreboardPeriod", current_line + 1, 4, 4 + #game.period)
	api.nvim_buf_add_highlight(
		bufnr,
		-1,
		"ScoreboardTime",
		current_line + 1,
		6 + #game.period,
		6 + #game.period + #game.time
	)

	-- Function to set team info
	local function set_team_info(line, logo, team, score, sog)
		set_highlighted_line(
			bufnr,
			current_line + line,
			string.format("│ %s %-20s %8d  │", logo, team, score),
			"ScoreboardTeamName"
		)
		set_highlighted_line(
			bufnr,
			current_line + line + 1,
			string.format("│   SOG: %-25d │", sog),
			"ScoreboardSOG"
		)
		api.nvim_buf_add_highlight(bufnr, -1, "ScoreboardScore", current_line + line, 28, 30)
	end

	-- Away team
	set_team_info(3, game.away_logo, game.away_team, game.away_score, game.away_sog)

	-- Home team
	set_team_info(6, game.home_logo, game.home_team, game.home_score, game.home_sog)
	return current_line + 9
end

-- Function to update the scoreboard
local function update_scoreboard(games)
	local bufnr = scoreboard.bufnr

	api.nvim_buf_set_option(bufnr, "modifiable", true)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	local current_line = 0

	for _, game in ipairs(games) do
		current_line = update_game(bufnr, game, current_line)
	end

	api.nvim_buf_set_option(bufnr, "modifiable", false)
end

function M.toggle_scoreboard()
	if scoreboard.winid == nil then
		scoreboard:mount()
		create_highlight_groups()
		local res = plenary.get("https://api-web.nhle.com/v1/score/2024-10-08")

		local games = parse_games(res.body)
		update_scoreboard(games)

		-- Set up auto-updating    -- Set up auto-updating
		local timer = vim.loop.new_timer()
		timer:start(
			0,
			config.update_interval,
			vim.schedule_wrap(function()
				-- Simulate changing game state
				res = plenary.get("https://api-web.nhle.com/v1/score/2024-10-08")

				games = parse_games(res.body)
				update_scoreboard(games)
			end)
		)

		-- Stop the timer when the window is closed
		scoreboard:on(event.BufWinLeave, function()
			timer:stop()
		end)
	else
		scoreboard:unmount()
	end
end

return M
