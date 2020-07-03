local debug = require("debug")
local json = require("json")
local Module = {}
local Salvation = {}
local heartbeatTicker
local heartbeatInterval = 5


Module.SendHeartbeat = function()
	Module.beat();
end

Module.beat = function()
	if Salvation.isStopped then
		return
	end

	debug.print("Sending heartbeat")

	if Salvation.rateLimitReached then
		return
	end

	if Salvation.isStopped then
		-- stop beating
        return
	end
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
    Salvation.HTTPSPostRequest(SalvationSettings.api_endpoint, '/api/addon/heartbeats?password=' .. SalvationSettings.password, postData, function(body)
        if string.match(body, "invalid password") then
            print "|cFF00D0FFSalvation|r: connection rejected, password is invalid or your Salvation endpoint is wrong."
            print "|cFF00D0FFSalvation|r: please check the salvation.lua script and enter any missing configs"
            Salvation.Stop()
            return
        end
		debug.print("Heartbeat success")
		return C_Timer.After(heartbeatInterval, function()
			Module.beat();
		end)
    end, function(err)
		print(err)
		return C_Timer.After(heartbeatInterval, function()
			Module.beat();
		end)

    end)
end

local init = function(salvationInstance)
    Salvation = salvationInstance
    return Module
end

return init
