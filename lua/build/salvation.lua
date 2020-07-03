-- Bundled by luabundle {"version":"1.6.0"}
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)

local json = require("json")
local debug = require("debug")
local deferred = require("deferred")

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
local heartbeatModule = require("heartbeat")(Salvation)
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
end)
__bundle_register("heartbeat", function(require, _LOADED, __bundle_register, __bundle_modules)
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

end)
__bundle_register("json", function(require, _LOADED, __bundle_register, __bundle_modules)
--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
  return "null"
end


local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end


local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end


local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}


encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end


function json.encode(val)
  return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
   -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end


return json
end)
__bundle_register("debug", function(require, _LOADED, __bundle_register, __bundle_modules)
local debug = {
    enabled = false
}

-- todo add decoration
debug.print = function(msg)
    if debug.enabled == true then
        print('|cFFf1b3ff[Salvation-Debug] ' .. msg .. '|r')
    end
end

return debug

end)
__bundle_register("deferred", function(require, _LOADED, __bundle_register, __bundle_modules)
--- A+ promises in Lua.
--- @module deferred

local M = {}

local deferred = {}
deferred.__index = deferred

local PENDING = 0
local RESOLVING = 1
local REJECTING = 2
local RESOLVED = 3
local REJECTED = 4

local function finish(deferred, state)
	state = state or REJECTED
	for i, f in ipairs(deferred.queue) do
		if state == RESOLVED then
			f:resolve(deferred.value)
		else
			f:reject(deferred.value)
		end
	end
	deferred.state = state
end

local function isfunction(f)
	if type(f) == 'table' then
		local mt = getmetatable(f)
		return mt ~= nil and type(mt.__call) == 'function'
	end
	return type(f) == 'function'
end

local function promise(deferred, next, success, failure, nonpromisecb)
	if type(deferred) == 'table' and type(deferred.value) == 'table' and isfunction(next) then
		local called = false
		local ok, err = pcall(next, deferred.value, function(v)
			if called then return end
			called = true
			deferred.value = v
			success()
		end, function(v)
			if called then return end
			called = true
			deferred.value = v
			failure()
		end)
		if not ok and not called then
			deferred.value = err
			failure()
		end
	else
		nonpromisecb()
	end
end

local function fire(deferred)
	local next
	if type(deferred.value) == 'table' then
		next = deferred.value.next
	end
	promise(deferred, next, function()
		deferred.state = RESOLVING
		fire(deferred)
	end, function()
		deferred.state = REJECTING
		fire(deferred)
	end, function()
		local ok
		local v
		if deferred.state == RESOLVING and isfunction(deferred.success) then
			ok, v = pcall(deferred.success, deferred.value)
		elseif deferred.state == REJECTING and isfunction(deferred.failure) then
			ok, v = pcall(deferred.failure, deferred.value)
			if ok then
				deferred.state = RESOLVING
			end
		end

		if ok ~= nil then
			if ok then
				deferred.value = v
			else
				deferred.value = v
				return finish(deferred)
			end
		end

		if deferred.value == deferred then
			deferred.value = pcall(error, 'resolving promise with itself')
			return finish(deferred)
		else
			promise(deferred, next, function()
				finish(deferred, RESOLVED)
			end, function(state)
				finish(deferred, state)
			end, function()
				finish(deferred, deferred.state == RESOLVING and RESOLVED)
			end)
		end
	end)
end

local function resolve(deferred, state, value)
	if deferred.state == 0 then
		deferred.value = value
		deferred.state = state
		fire(deferred)
	end
	return deferred
end

--
-- PUBLIC API
--
function deferred:resolve(value)
	return resolve(self, RESOLVING, value)
end

function deferred:reject(value)
	return resolve(self, REJECTING, value)
end

--- Returns a new promise object.
--- @treturn Promise New promise
--- @usage
--- local deferred = require('deferred')
---
--- --
--- -- Converting callback-based API into promise-based is very straightforward:
--- --
--- -- 1) Create promise object
--- -- 2) Start your asynchronous action
--- -- 3) Resolve promise object whenever action is finished (only first resolution
--- --    is accepted, others are ignored)
--- -- 4) Reject promise object whenever action is failed (only first rejection is
--- --    accepted, others are ignored)
--- -- 5) Return promise object letting calling side to add a chain of callbacks to
--- --    your asynchronous function
---
--- function read(f)
---   local d = deferred.new()
---   readasync(f, function(contents, err)
---       if err == nil then
---         d:resolve(contents)
---       else
---         d:reject(err)
---       end
---   end)
---   return d
--- end
---
--- -- You can now use read() like this:
--- read('file.txt'):next(function(s)
---     print('File.txt contents: ', s)
---   end, function(err)
---     print('Error', err)
--- end)
function M.new(options)
	if isfunction(options) then
		local d = M.new()
		local ok, err = pcall(options, d)
		if not ok then
			d:reject(err)
		end
		return d
	end
	options = options or {}
	local d
	d = {
		next = function(self, success, failure)
			local next = M.new({success = success, failure = failure, extend = options.extend})
			if d.state == RESOLVED then
				next:resolve(d.value)
			elseif d.state == REJECTED then
				next:reject(d.value)
			else
				table.insert(d.queue, next)
			end
			return next
		end,
		state = 0,
		queue = {},
		success = options.success,
		failure = options.failure,
	}
	d = setmetatable(d, deferred)
	if isfunction(options.extend) then
		options.extend(d)
	end
	return d
end

--- Returns a new promise object that is resolved when all promises are resolved/rejected.
--- @param args list of promise
--- @treturn Promise New promise
--- @usage
--- deferred.all({
---     http.get('http://example.com/first'),
---     http.get('http://example.com/second'),
---     http.get('http://example.com/third'),
---   }):next(function(results)
---       -- handle results here (all requests are finished and there has been
---       -- no errors)
---     end, function(results)
---       -- handle errors here (all requests are finished and there has been
---       -- at least one error)
---   end)
function M.all(args)
	local d = M.new()
	if #args == 0 then
		return d:resolve({})
	end
	local method = "resolve"
	local pending = #args
	local results = {}

	local function synchronizer(i, resolved)
		return function(value)
			results[i] = value
			if not resolved then
				method = "reject"
			end
			pending = pending - 1
			if pending == 0 then
				d[method](d, results)
			end
			return value
		end
	end

	for i = 1, pending do
		args[i]:next(synchronizer(i, true), synchronizer(i, false))
	end
	return d
end

--- Returns a new promise object that is resolved with the values of sequential application of function fn to each element in the list. fn is expected to return promise object.
--- @function map
--- @param args list of promise
--- @param fn promise used to resolve the list of promise
--- @return a new promise
--- @usage
--- local items = {'a.txt', 'b.txt', 'c.txt'}
--- -- Read 3 files, one by one
--- deferred.map(items, read):next(function(files)
---     -- here files is an array of file contents for each of the files
---   end, function(err)
---     -- handle reading error
--- end)
function M.map(args, fn)
	local d = M.new()
	local results = {}
	local function donext(i)
		if i > #args then
			d:resolve(results)
		else
			fn(args[i]):next(function(res)
				table.insert(results, res)
				donext(i+1)
			end, function(err)
				d:reject(err)
			end)
		end
	end
	donext(1)
	return d
end

--- Returns a new promise object that is resolved as soon as the first of the promises gets resolved/rejected.
--- @param args list of promise
--- @treturn Promise New promise
--- @usage
--- -- returns a promise that gets rejected after a certain timeout
--- function timeout(sec)
---   local d = deferred.new()
---   settimeout(function()
---       d:reject('Timeout')
---     end, sec)
---   return d
--- end
---
--- deferred.first({
---     read(somefile), -- resolves promise with contents, or rejects with error
---     timeout(5),
---   }):next(function(result)
---       -- file was read successfully...
---     end, function(err)
---       -- either timeout or I/O error...
---   end)
function M.first(args)
	local d = M.new()
	for _, v in ipairs(args) do
		v:next(function(res)
			d:resolve(res)
		end, function(err)
			d:reject(err)
		end)
	end
	return d
end

--- A promise is an object that can store a value to be retrieved by a future object.
--- @type Promise

--- Wait for the promise object.
--- @function next
--- @tparam function cb resolve callback (function(value) end)
--- @tparam[opt] function errcb rejection callback (function(reject_value) end)
--- @usage
--- -- Reading two files sequentially:
--- read('first.txt'):next(function(s)
--- 	print('File file:', s)
--- 	return read('second.txt')
--- end):next(function(s)
--- 	print('Second file:', s)
--- end):next(nil, function(err)
--- 	-- error while reading first or second file
--- 	print('Error', err)
--- end)

--- Resolve promise object with value.
--- @function resolve
--- @param value promise value
--- @return resolved future result

--- Reject promise object with value.
--- @function reject
--- @param value promise value
--- @return rejected future result

return M
end)
return __bundle_require("__root")