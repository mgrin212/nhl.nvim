local M = {}

function M.parse_games(json_string)
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

return M
