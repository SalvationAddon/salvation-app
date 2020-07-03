
local json = require "json"
local debug = require "debug"
local deferred = require('deferred')

-- utility function, because lua sucks
function split(str, pat)
    local t = {}
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
       if s ~= 1 or cap ~= "" then
          table.insert(t,cap)
       end
       last_end = e+1
       s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
       cap = str:sub(last_end)
       table.insert(t, cap)
    end
    return t
 end


local Salvation = {
	isStopped = false,
    rateLimitReached = false,
}
------
-- Wire up the modules..
------
local heartbeatModule = require('heartbeat')(Salvation)
Salvation.SendHeartbeat = heartbeatModule.SendHeartbeat

------
-- Init is the bootstrapper for the addon, it determines the current configuration before starting up
------
Salvation.Init = function()
    debug.enabled = false
    print("[|cFF00D0FFSalvation|r]: Loaded - Version: 1.0.0")

    -- If salvation doesn't have a license code abort
    if SalvationSettings.password == "" then
        print "[|cFF00D0FFSalvation|r]: Please activate the addon using the \"/salvation password\" command."
        return
    end

    Salvation.Start()

end

------
-- Start runs the actual addon logic, creating longpolling handlers and starts monitoring the character that is online
-- heartbeats are also sent from this point on a recurring basis (every few seconds)
------
Salvation.Start = function()

	local x1, y1, z1
	if __LB__ and __LB__.ObjectPosition then
		x1, y1, z1 = __LB__.ObjectPosition("player")
	else
		x1, y1, z1 = ObjectPosition("player")
	end

	local playerClass, englishClass = UnitClass("player")
	local englishFaction, localizedFaction = UnitFactionGroup("player")
	local msgPayload = {
		name = UnitName("player"),
		faction = string.lower(englishFaction),
		class = string.lower(englishClass),
		level = UnitLevel("player"),
        realm = GetRealmName(),
		locale = GetLocale(),
		coins = GetMoney(),
        xp = UnitXP("player"),
		max_xp = UnitXPMax("player"),
		cords = x1 .. "," .. y1 .. "," .. z1,
		zone = GetZoneText(),
		sub_zone = GetSubZoneText(),
	}
	local postData = json.encode(msgPayload)

    -- Check if license is valid
    Salvation.HTTPSPostRequest(SalvationSettings.api_endpoint, '/api/addon/login/' .. SalvationSettings.password, postData, function(body)
        local parsedBody = json.decode(body)

        if parsedBody.code and parsedBody.code ~= 200 then
            print("[|cFF00D0FFSalvation|r]: connection rejected, password is invalid or your Salvation url is wrong.")
            print("[|cFF00D0FFSalvation|r]: you can change your passwprd using the '/salvation password' command")
            return
        end

        -- Start heartbeats
        Salvation.SendHeartbeat()

        -- Start longpolling
        Salvation.LongPoll()

        local f = CreateFrame("Frame")
        f:RegisterEvent("CHAT_MSG_WHISPER")
        f:SetScript("OnEvent", Salvation.HandleWhisper)

    end, function(err)
        print("[|cFF00D0FFSalvation|r]: Failed to validate license, please try again (or reload ui)")
    end)

end

Salvation.Stop = function()
    Salvation.isStopped = true
end

------
-- HandleWhisper processes whispers as they occur
------
Salvation.HandleWhisper = function(self, event, message, sender)
	if Salvation.rateLimitReached then
		print("[|cFF00D0FFSalvation|r]: |cFF00D0FFSkipping Alert|r: Rate Limit Exceeded")
		return
	end

	if Salvation.isStopped then
		return
	end

    local msgPayload = {
		name = UnitName("player"),
        realm = GetRealmName(),
        sender = sender,
		message = message,
	}

	local payloadString = json.encode(msgPayload)
    print("[|cFF00D0FFSalvation|r]: Sending whisper alert")
	Salvation.HTTPSPostRequest(SalvationSettings.api_endpoint, '/api/addon/whisper?password=' .. SalvationSettings.password, payloadString, function(body)
		-- nothing
	end, function(err)
		print("[|cFF00D0FFSalvation|r]: |cFF00D0FFError|r: Failed to send whisper notice to API")
	end)

end

------
-- RouteCommand determines what kind of command this is and fires off the right handler
------
Salvation.RouteCommand = function(commandObject)
	debug.print("[|cFF00D0FFSalvation|r]: |cFF00D0FFReceived Command|r: " .. commandObject["command"])

	if commandObject["command"] == "logout" then
		Logout()
	end

	if commandObject["command"] == "send-whisper" then
		SendChatMessage(commandObject["message"], "WHISPER", GetDefaultLanguage("player"), commandObject["to"]);
	end
end

------
-- LongPoll fires long running requests to the API that will hold the connection open until new commands come down the wire
-- from the user on discord
------
Salvation.LongPoll = function()
	if Salvation.isStopped then
		return
	end

    -- Figure out if the last timestamp is available, this will help fetch messages the system missed
    debug.print(" - polling for commands")
    local category = UnitName("player") .. '-' .. GetRealmName()
    category = urlencode(category)
  
    Salvation.HTTPSGetRequest(SalvationSettings.api_endpoint, '/api/addon/events?topic=' .. category .. "&password=" .. SalvationSettings.password, function(body)
		-- If this endpoint is running on the Glitch free plan there is a 4k an hour rate limit, enough characters would hit this easily..
		if string.match(body, "too many requests") then
			Salvation.rateLimitReached = true
			print "[|cFF00D0FFSalvation|r]: Hourly rate limit reached, delaying before connecting again..."
			return C_Timer.After(60, function()
				Salvation.LongPoll()
			end)
		end

		-- If it hits here then no more rate limit issues! hooray
		Salvation.rateLimitReached = false

        if string.match(body, "Failed to complete tunnel") then
            return Salvation.LongPollDelay()
        end

        -- If the body contains "no events before timeout" then it came from LUABox
		if string.match(body, "no events before timeout") then
			Salvation.LongPoll()
			return
        end
        -- If the body response contains an events key (so hacky...)
        if string.match(body, '"events"') then

            local parsedBody = json.decode(body)
            debug.print("Found " .. table.getn(parsedBody["events"]) .. " events")

            -- Iterate over the command(s) and route them
            for _, command in ipairs(parsedBody["events"]) do
                Salvation.RouteCommand(command)
			end

            return Salvation.LongPoll()

		end

		-- Some error..so delay a little before retrying...
        Salvation.LongPollDelay()

	end, function(err)

        -- If the error message contains "period of time" then its a normal timeout (this is the EWT response on timeout)
        if err and string.match(err, "period of time") then
            C_Timer.After(5, function()
                Salvation.LongPoll()
			end)
			return
		end

		if err then
			print("Salvation Error:")
			print(err)
			Salvation.LongPollDelay()
			return
        end

    end)
end

------
-- LongPollDelay is simply used to re-start the longpolling after a delay
------
Salvation.LongPollDelay = function()
    print "[|cFF00D0FFSalvation|r]: unable to connect, attempting reconnect in 15 seconds..."
    return C_Timer.After(15, function()
        Salvation.LongPoll()
    end)
end

------
-- HTTPSGetRequest is a wrapper for LuaBox and EWT http requests, because they are magically different..
------
Salvation.HTTPSGetRequest = function(host, path, successCallback, failureCallback)

    -- LUABox
    if __LB__ and __LB__.HttpAsyncGet then
        __LB__.HttpAsyncGet(host, 443, true, path, function(body)
            return successCallback(body)
        end,
        function(err)
            return failureCallback(err)
        end)
    end

    if SendHTTPRequest then
        SendHTTPRequest('https://' .. host .. path, nil,
        function(body, code, req, res, err)
            if err then
                return failureCallback(err)
            end
            return successCallback(body)
        end, "User-Agent: Mozilla/5.0 (compatible; Salvation/1.0.0)\n")
    end

    return d
end

------
-- HTTPSPostRequest is a wrapper for LuaBox and EWT http requests, because they are magically different..
------
Salvation.HTTPSPostRequest = function(host, path, data, successCallback, failureCallback)

    -- LUABox
    if __LB__ and __LB__.HttpAsyncPost then
        __LB__.HttpAsyncPost(host, 443, true, path, data, function(body)
            return successCallback(body)
        end,
        function(err)
            return failureCallback(err)
        end, "Content-Type", "application/json")
    end

    if SendHTTPRequest then
        SendHTTPRequest('https://' .. host .. path, data,
        function(body, code, req, res, err)
            if err then
                return failureCallback(err)
            end
            return successCallback(body)
        end, "Content-Type: application/json\nUser-Agent: Mozilla/5.0 (compatible; Salvation/1.0.0)\n")
    end

    return d
end

-- Now that all that is out of the way, init the addon!
Salvation.Init()

------
--  Wire up the chat commands
------
SLASH_SALVATION1 = "/salvation"
SlashCmdList["SALVATION"] = function(msg, editbox)

    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")

    if cmd == "activate" then
        Salvation.ProcessActivation(args)
    elseif cmd == "disable" then
	print "[|cFF00D0FFSalvation|r]: Disabled for this session! Please /reload the game to re-enable Salvation."
	Salvation.isStopped = true



    else
      -- If not handled above, display some sort of help message
      print("[|cFF00D0FFSalvation|r] Commands: \nDisable Salvation: /salvation disable");
    end
  end

function urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end

function char_to_hex(c)
  return string.format("%%%02X", string.byte(c))
end