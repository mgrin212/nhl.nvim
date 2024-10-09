local api = vim.api
local Split = require("nui.split")
local Config = require("nhl-nvim.config")
local Utils = require("nhl-nvim.utils")

local M = {}

M.scoreboard = Split({
	relative = "editor",
	position = "right",
	size = Config.get().window_size,
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

local function create_highlight_groups()
	local colors = Config.get().colors
	local highlights = {
		ScoreboardBg = { bg = colors.bg, fg = colors.fg },
		ScoreboardPeriod = { fg = colors.fg, bg = colors.period_bg, bold = true },
		ScoreboardTime = { fg = colors.fg, bg = colors.time_bg, bold = true },
		ScoreboardTeamName = { fg = colors.fg, bg = colors.bg, bold = true },
		ScoreboardSOG = { fg = colors.sog, bg = colors.bg },
		ScoreboardScore = { fg = colors.fg, bg = colors.bg, bold = true },
		ScoreboardBorder = { fg = colors.border, bg = colors.bg },
	}

	for name, opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

local function set_highlighted_line(bufnr, line_num, content, hl_group)
	api.nvim_buf_set_lines(bufnr, line_num, line_num + 1, false, { content })
	if hl_group then
		api.nvim_buf_add_highlight(bufnr, -1, hl_group, line_num, 0, -1)
	end
end

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

function M.update_scoreboard(games)
	local bufnr = M.scoreboard.bufnr

	api.nvim_buf_set_option(bufnr, "modifiable", true)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

	local current_line = 0

	for _, game in ipairs(games) do
		current_line = update_game(bufnr, game, current_line)
	end

	api.nvim_buf_set_option(bufnr, "modifiable", false)
end

function M.mount_scoreboard()
	M.scoreboard:mount()
	create_highlight_groups()
end

function M.unmount_scoreboard()
	M.scoreboard:unmount()
end

return M
