--[[
LuCI - Utility library

Description:
Several common useful Lua functions

License:
Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]--

local io = require "io"
local math = require "math"
local table = require "table"
local debug = require "debug"
local ldebug = require "luci.debug"
local string = require "string"
local coroutine = require "coroutine"
local tparser = require "luci.template.parser"

local getmetatable, setmetatable = getmetatable, setmetatable
local rawget, rawset, unpack = rawget, rawset, unpack
local tostring, type, assert = tostring, type, assert
local ipairs, pairs, next, loadstring = ipairs, pairs, next, loadstring
local require, pcall, xpcall = require, pcall, xpcall
local collectgarbage, get_memory_limit = collectgarbage, get_memory_limit

--- LuCI utility functions.
module "luci.util"

--
-- Pythonic string formatting extension
--
getmetatable("").__mod = function(a, b)
	if not b then
		return a
	elseif type(b) == "table" then
		for k, _ in pairs(b) do if type(b[k]) == "userdata" then b[k] = tostring(b[k]) end end
		return a:format(unpack(b))
	else
		if type(b) == "userdata" then b = tostring(b) end
		return a:format(b)
	end
end


--
-- Class helper routines
--

-- Instantiates a class
local function _instantiate(class, ...)
	local inst = setmetatable({}, {__index = class})

	if inst.__init__ then
		inst:__init__(...)
	end

	return inst
end

--- Create a Class object (Python-style object model).
-- The class object can be instantiated by calling itself.
-- Any class functions or shared parameters can be attached to this object.
-- Attaching a table to the class object makes this table shared between
-- all instances of this class. For object parameters use the __init__ function.
-- Classes can inherit member functions and values from a base class.
-- Class can be instantiated by calling them. All parameters will be passed
-- to the __init__ function of this class - if such a function exists.
-- The __init__ function must be used to set any object parameters that are not shared
-- with other objects of this class. Any return values will be ignored.
-- @param base	The base class to inherit from (optional)
-- @return		A class object
-- @see			instanceof
-- @see			clone
function class(base)
	return setmetatable({}, {
		__call  = _instantiate,
		__index = base
	})
end

--- Test whether the given object is an instance of the given class.
-- @param object	Object instance
-- @param class		Class object to test against
-- @return			Boolean indicating whether the object is an instance
-- @see				class
-- @see				clone
function instanceof(object, class)
	local meta = getmetatable(object)
	while meta and meta.__index do
		if meta.__index == class then
			return true
		end
		meta = getmetatable(meta.__index)
	end
	return false
end


--
-- Scope manipulation routines
--

local tl_meta = {
	__mode = "k",

	__index = function(self, key)
		local t = rawget(self, coxpt[coroutine.running()]
		 or coroutine.running() or 0)
		return t and t[key]
	end,

	__newindex = function(self, key, value)
		local c = coxpt[coroutine.running()] or coroutine.running() or 0
		if not rawget(self, c) then
			rawset(self, c, { [key] = value })
		else
			rawget(self, c)[key] = value
		end
	end
}

--- Create a new or get an already existing thread local store associated with
-- the current active coroutine. A thread local store is private a table object
-- whose values can't be accessed from outside of the running coroutine.
-- @return	Table value representing the corresponding thread local store
function threadlocal(tbl)
	return setmetatable(tbl or {}, tl_meta)
end


--
-- Debugging routines
--

--- Write given object to stderr.
-- @param obj	Value to write to stderr
-- @return		Boolean indicating whether the write operation was successful
function perror(obj)
	return io.stderr:write(tostring(obj) .. "\n")
end

--- Recursively dumps a table to stdout, useful for testing and debugging.
-- @param t	Table value to dump
-- @param maxdepth	Maximum depth
-- @return	Always nil
function dumptable(t, maxdepth, i, seen)
	i = i or 0
	seen = seen or setmetatable({}, {__mode="k"})

	for k,v in pairs(t) do
		perror(string.rep("\t", i) .. tostring(k) .. "\t" .. tostring(v))
		if type(v) == "table" and (not maxdepth or i < maxdepth) then
			if not seen[v] then
				seen[v] = true
				dumptable(v, maxdepth, i+1, seen)
			else
				perror(string.rep("\t", i) .. "*** RECURSION ***")
			end
		end
	end
end


--
-- String and data manipulation routines
--

--- Create valid XML PCDATA from given string.
-- @param value	String value containing the data to escape
-- @return		String value containing the escaped data
function pcdata(value)
	return value and tparser.pcdata(tostring(value))
end

--- Strip HTML tags from given string.
-- @param value	String containing the HTML text
-- @return	String with HTML tags stripped of
function striptags(value)
	return value and tparser.striptags(tostring(value))
end

--- Splits given string on a defined separator sequence and return a table
-- containing the resulting substrings. The optional max parameter specifies
-- the number of bytes to process, regardless of the actual length of the given
-- string. The optional last parameter, regex, specifies whether the separator
-- sequence is interpreted as regular expression.
-- @param str		String value containing the data to split up
-- @param pat		String with separator pattern (optional, defaults to "\n")
-- @param max		Maximum times to split (optional)
-- @param regex 	Boolean indicating whether to interpret the separator
--					pattern as regular expression (optional, default is false)
-- @return			Table containing the resulting substrings
function split(str, pat, max, regex)
	pat = pat or "\n"
	max = max or #str

	local t = {}
	local c = 1

	if #str == 0 then
		return {""}
	end

	if #pat == 0 then
		return nil
	end

	if max == 0 then
		return str
	end

	repeat
		local s, e = str:find(pat, c, not regex)
		max = max - 1
		if s and max < 0 then
			t[#t+1] = str:sub(c)
		else
			t[#t+1] = str:sub(c, s and s - 1)
		end
		c = e and e + 1 or #str + 1
	until not s or max < 0

	return t
end

--- Remove leading and trailing whitespace from given string value.
-- @param str	String value containing whitespace padded data
-- @return		String value with leading and trailing space removed
function trim(str)
	return (str:gsub("^%s*(.-)%s*$", "%1"))
end

--- Count the occurences of given substring in given string.
-- @param str		String to search in
-- @param pattern	String containing pattern to find
-- @return			Number of found occurences
function cmatch(str, pat)
	local count = 0
	for _ in str:gmatch(pat) do count = count + 1 end
	return count
end

--- Return a matching iterator for the given value. The iterator will return
-- one token per invocation, the tokens are separated by whitespace. If the
-- input value is a table, it is transformed into a string first. A nil value
-- will result in a valid interator which aborts with the first invocation.
-- @param val		The value to scan (table, string or nil)
-- @return			Iterator which returns one token per call
function imatch(v)
	if type(v) == "table" then
		local k = nil
		return function()
			k = next(v, k)
			return v[k]
		end

	elseif type(v) == "number" or type(v) == "boolean" then
		local x = true
		return function()
			if x then
				x = false
				return tostring(v)
			end
		end

	elseif type(v) == "userdata" or type(v) == "string" then
		return tostring(v):gmatch("%S+")
	end

	return function() end
end

--- Parse certain units from the given string and return the canonical integer
-- value or 0 if the unit is unknown. Upper- or lower case is irrelevant.
-- Recognized units are:
--	o "y"	- one year   (60*60*24*366)
--  o "m"	- one month  (60*60*24*31)
--  o "w"	- one week   (60*60*24*7)
--  o "d"	- one day    (60*60*24)
--  o "h"	- one hour	 (60*60)
--  o "min"	- one minute (60)
--  o "kb"  - one kilobyte (1024)
--  o "mb"	- one megabyte (1024*1024)
--  o "gb"	- one gigabyte (1024*1024*1024)
--  o "kib" - one si kilobyte (1000)
--  o "mib"	- one si megabyte (1000*1000)
--  o "gib"	- one si gigabyte (1000*1000*1000)
-- @param ustr	String containing a numerical value with trailing unit
-- @return		Number containing the canonical value
function parse_units(ustr)

	local val = 0

	-- unit map
	local map = {
		-- date stuff
		y   = 60 * 60 * 24 * 366,
		m   = 60 * 60 * 24 * 31,
		w   = 60 * 60 * 24 * 7,
		d   = 60 * 60 * 24,
		h   = 60 * 60,
		min = 60,

		-- storage sizes
		kb  = 1024,
		mb  = 1024 * 1024,
		gb  = 1024 * 1024 * 1024,

		-- storage sizes (si)
		kib = 1000,
		mib = 1000 * 1000,
		gib = 1000 * 1000 * 1000
	}

	-- parse input string
	for spec in ustr:lower():gmatch("[0-9%.]+[a-zA-Z]*") do

		local num = spec:gsub("[^0-9%.]+$","")
		local spn = spec:gsub("^[0-9%.]+", "")

		if map[spn] or map[spn:sub(1,1)] then
			val = val + num * ( map[spn] or map[spn:sub(1,1)] )
		else
			val = val + num
		end
	end


	return val
end

-- also register functions above in the central string class for convenience
string.pcdata      = pcdata
string.striptags   = striptags
string.split       = split
string.trim        = trim
string.cmatch      = cmatch
string.parse_units = parse_units


--- Appends numerically indexed tables or single objects to a given table.
-- @param src	Target table
-- @param ...	Objects to insert
-- @return		Target table
function append(src, ...)
	for i, a in ipairs({...}) do
		if type(a) == "table" then
			for j, v in ipairs(a) do
				src[#src+1] = v
			end
		else
			src[#src+1] = a
		end
	end
	return src
end

--- Combines two or more numerically indexed tables and single objects into one table.
-- @param tbl1	Table value to combine
-- @param tbl2	Table value to combine
-- @param ...	More tables to combine
-- @return		Table value containing all values of given tables
function combine(...)
	return append({}, ...)
end

--- Checks whether the given table contains the given value.
-- @param table	Table value
-- @param value	Value to search within the given table
-- @return		Boolean indicating whether the given value occurs within table
function contains(table, value)
	for k, v in pairs(table) do
		if value == v then
			return k
		end
	end
	return false
end

--- Update values in given table with the values from the second given table.
-- Both table are - in fact - merged together.
-- @param t			Table which should be updated
-- @param updates	Table containing the values to update
-- @return			Always nil
function update(t, updates)
	for k, v in pairs(updates) do
		t[k] = v
	end
end

--- Retrieve all keys of given associative table.
-- @param t	Table to extract keys from
-- @return	Sorted table containing the keys
function keys(t)
	local keys = { }
	if t then
		for k, _ in kspairs(t) do
			keys[#keys+1] = k
		end
	end
	return keys
end

--- Clones the given object and return it's copy.
-- @param object	Table value to clone
-- @param deep		Boolean indicating whether to do recursive cloning
-- @return			Cloned table value
function clone(object, deep)
	local copy = {}

	for k, v in pairs(object) do
		if deep and type(v) == "table" then
			v = clone(v, deep)
		end
		copy[k] = v
	end

	return setmetatable(copy, getmetatable(object))
end


--- Create a dynamic table which automatically creates subtables.
-- @return	Dynamic Table
function dtable()
        return setmetatable({}, { __index =
                function(tbl, key)
                        return rawget(tbl, key)
                         or rawget(rawset(tbl, key, dtable()), key)
                end
        })
end


-- Serialize the contents of a table value.
function _serialize_table(t, seen)
	assert(not seen[t], "Recursion detected.")
	seen[t] = true

	local data  = ""
	local idata = ""
	local ilen  = 0

	for k, v in pairs(t) do
		if type(k) ~= "number" or k < 1 or math.floor(k) ~= k or ( k - #t ) > 3 then
			k = serialize_data(k, seen)
			v = serialize_data(v, seen)
			data = data .. ( #data > 0 and ", " or "" ) ..
				'[' .. k .. '] = ' .. v
		elseif k > ilen then
			ilen = k
		end
	end

	for i = 1, ilen do
		local v = serialize_data(t[i], seen)
		idata = idata .. ( #idata > 0 and ", " or "" ) .. v
	end

	return idata .. ( #data > 0 and #idata > 0 and ", " or "" ) .. data
end

--- Recursively serialize given data to lua code, suitable for restoring
-- with loadstring().
-- @param val	Value containing the data to serialize
-- @return		String value containing the serialized code
-- @see			restore_data
-- @see			get_bytecode
function serialize_data(val, seen)
	seen = seen or setmetatable({}, {__mode="k"})

	if val == nil then
		return "nil"
	elseif type(val) == "number" then
		return val
	elseif type(val) == "string" then
		return "%q" % val
	elseif type(val) == "boolean" then
		return val and "true" or "false"
	elseif type(val) == "function" then
		return "loadstring(%q)" % get_bytecode(val)
	elseif type(val) == "table" then
		return "{ " .. _serialize_table(val, seen) .. " }"
	else
		return '"[unhandled data type:' .. type(val) .. ']"'
	end
end

--- Restore data previously serialized with serialize_data().
-- @param str	String containing the data to restore
-- @return		Value containing the restored data structure
-- @see			serialize_data
-- @see			get_bytecode
function restore_data(str)
	return loadstring("return " .. str)()
end


--
-- Byte code manipulation routines
--

--- Return the current runtime bytecode of the given data. The byte code
-- will be stripped before it is returned.
-- @param val	Value to return as bytecode
-- @return		String value containing the bytecode of the given data
function get_bytecode(val)
	local code

	if type(val) == "function" then
		code = string.dump(val)
	else
		code = string.dump( loadstring( "return " .. serialize_data(val) ) )
	end

	return code -- and strip_bytecode(code)
end

--- Strips unnescessary lua bytecode from given string. Information like line
-- numbers and debugging numbers will be discarded. Original version by
-- Peter Cawley (http://lua-users.org/lists/lua-l/2008-02/msg01158.html)
-- @param code	String value containing the original lua byte code
-- @return		String value containing the stripped lua byte code
function strip_bytecode(code)
	local version, format, endian, int, size, ins, num, lnum = code:byte(5, 12)
	local subint
	if endian == 1 then
		subint = function(code, i, l)
			local val = 0
			for n = l, 1, -1 do
				val = val * 256 + code:byte(i + n - 1)
			end
			return val, i + l
		end
	else
		subint = function(code, i, l)
			local val = 0
			for n = 1, l, 1 do
				val = val * 256 + code:byte(i + n - 1)
			end
			return val, i + l
		end
	end

	local function strip_function(code)
		local count, offset = subint(code, 1, size)
		local stripped = { string.rep("\0", size) }
		local dirty = offset + count
		offset = offset + count + int * 2 + 4
		offset = offset + int + subint(code, offset, int) * ins
		count, offset = subint(code, offset, int)
		for n = 1, count do
			local t
			t, offset = subint(code, offset, 1)
			if t == 1 then
				offset = offset + 1
			elseif t == 4 then
				offset = offset + size + subint(code, offset, size)
			elseif t == 3 then
				offset = offset + num
			elseif t == 254 or t == 9 then
				offset = offset + lnum
			end
		end
		count, offset = subint(code, offset, int)
		stripped[#stripped+1] = code:sub(dirty, offset - 1)
		for n = 1, count do
			local proto, off = strip_function(code:sub(offset, -1))
			stripped[#stripped+1] = proto
			offset = offset + off - 1
		end
		offset = offset + subint(code, offset, int) * int + int
		count, offset = subint(code, offset, int)
		for n = 1, count do
			offset = offset + subint(code, offset, size) + size + int * 2
		end
		count, offset = subint(code, offset, int)
		for n = 1, count do
			offset = offset + subint(code, offset, size) + size
		end
		stripped[#stripped+1] = string.rep("\0", int * 3)
		return table.concat(stripped), offset
	end

	return code:sub(1,12) .. strip_function(code:sub(13,-1))
end


--
-- Sorting iterator functions
--

function _sortiter( t, f )
	local keys = { }

	local k, v
	for k, v in pairs(t) do
		keys[#keys+1] = k
	end

	local _pos = 0

	table.sort( keys, f )

	return function()
		_pos = _pos + 1
		if _pos <= #keys then
			return keys[_pos], t[keys[_pos]], _pos
		end
	end
end

--- Return a key, value iterator which returns the values sorted according to
-- the provided callback function.
-- @param t	The table to iterate
-- @param f A callback function to decide the order of elements
-- @return	Function value containing the corresponding iterator
function spairs(t,f)
	return _sortiter( t, f )
end

--- Return a key, value iterator for the given table.
-- The table pairs are sorted by key.
-- @param t	The table to iterate
-- @return	Function value containing the corresponding iterator
function kspairs(t)
	return _sortiter( t )
end

--- Return a key, value iterator for the given table.
-- The table pairs are sorted by value.
-- @param t	The table to iterate
-- @return	Function value containing the corresponding iterator
function vspairs(t)
	return _sortiter( t, function (a,b) return t[a] < t[b] end )
end


--
-- System utility functions
--

--- Test whether the current system is operating in big endian mode.
-- @return	Boolean value indicating whether system is big endian
function bigendian()
	return string.byte(string.dump(function() end), 7) == 0
end

--- Execute given commandline and gather stdout.
-- @param command	String containing command to execute
-- @return			String containing the command's stdout
function exec(command)
	local pp   = io.popen(command)
	local data = pp:read("*a")
	pp:close()

	return data
end

--- Return a line-buffered iterator over the output of given command.
-- @param command	String containing the command to execute
-- @return			Iterator
function execi(command)
	local pp = io.popen(command)

	return pp and function()
		local line = pp:read()

		if not line then
			pp:close()
		end

		return line
	end
end

-- Deprecated
function execl(command)
	local pp   = io.popen(command)
	local line = ""
	local data = {}

	while true do
		line = pp:read()
		if (line == nil) then break end
		data[#data+1] = line
	end
	pp:close()

	return data
end

--- Returns the absolute path to LuCI base directory.
-- @return		String containing the directory path
function libpath()
	return require "nixio.fs".dirname(ldebug.__file__)
end


--
-- Coroutine safe xpcall and pcall versions modified for Luci
-- original version:
-- coxpcall 1.13 - Copyright 2005 - Kepler Project (www.keplerproject.org)
--
-- Copyright © 2005 Kepler Project.
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
-- OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
-- DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
-- OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local performResume, handleReturnValue
local oldpcall, oldxpcall = pcall, xpcall
coxpt = {}
setmetatable(coxpt, {__mode = "kv"})

-- Identity function for copcall
local function copcall_id(trace, ...)
  return ...
end

--- This is a coroutine-safe drop-in replacement for Lua's "xpcall"-function
-- @param f		Lua function to be called protected
-- @param err	Custom error handler
-- @param ...	Parameters passed to the function
-- @return		A boolean whether the function call succeeded and the return
--				values of either the function or the error handler
function coxpcall(f, err, ...)
	local res, co = oldpcall(coroutine.create, f)
	if not res then
		local params = {...}
		local newf = function() return f(unpack(params)) end
		co = coroutine.create(newf)
	end
	local c = coroutine.running()
	coxpt[co] = coxpt[c] or c or 0

	return performResume(err, co, ...)
end

--- This is a coroutine-safe drop-in replacement for Lua's "pcall"-function
-- @param f		Lua function to be called protected
-- @param ...	Parameters passed to the function
-- @return		A boolean whether the function call succeeded and the returns
--				values of the function or the error object
function copcall(f, ...)
	return coxpcall(f, copcall_id, ...)
end

-- Handle return value of protected call
function handleReturnValue(err, co, status, ...)
	if not status then
		return false, err(debug.traceback(co, (...)), ...)
	end

	if coroutine.status(co) ~= 'suspended' then
		return true, ...
	end

	return performResume(err, co, coroutine.yield(...))
end

-- Resume execution of protected function call
function performResume(err, co, ...)
	return handleReturnValue(err, co, coroutine.resume(co, ...))
end


function get_api_error(errorcode)
	local error_list = {}
	error_list[0] = "successfully"
	error_list[1] = "两次输入密码不匹配"
	error_list[2] = "未知错误，密码修改不成功"
	error_list[3] = "固件检验失败请重新上传文件"
	
	error_list[20] = "缺少参数"
	error_list[80] = "api 地址错误"
	error_list[300] = "no this language"
	error_list[310] = "需要 SSID 或 密码至少一项"
	error_list[311] = "SSID 不能为空"
	error_list[312] = "SSID 需要是 1 至 32个英文字符,或 10 个中文字符"
	error_list[100] = "非法请求"
	error_list[110] = "升级失败请重试.  code:110"
	error_list[120] = "软件文件格式错误"
	error_list[301] = "密码不能为空"
	error_list[302] = "原密码不正确"
	error_list[303] = "密码长度需要在 5-64 位之间"
	error_list[401] = "No this device"
	error_list[402] = "Encryption error"
	error_list[403] = "wpa 密码长度大于 8 位"
	error_list[404] = "wep-open 密码需要 5位 或 13 位"
	error_list[405] = "密码长度应为  8-63  位字符"
	error_list[406] = "如果设置密码,请选择安全级别"
	error_list[407] = "需要将此设备接网线到LAN口,才能关闭 WIFI"
	error_list[408] = "至少需要填写一个 MAC 地址"
	error_list[409] = "最多只能填写 64 个  MAC 地址"
	error_list[410] = "终止地址不能小于起始地址"
	error_list[411] = "IP 地址需要在 1-254 之间"
	error_list[412] = "开始和终止地址不能为空"
	error_list[500] = "检查软件版本错误，网络是否正常或稍后再尝试"
	error_list[510] = "App Store to accelerate need ‘One word direction’"
	error_list[511] = "没有 lan 或 wan 口"
	error_list[512] = "IP 地址格式不正确"
	error_list[513] = "子网掩码格式不正确"
	error_list[514] = "需要传 mobile_type 和 mobile_dev_usb"
	error_list[515] = "没有接上3g 设备"
	error_list[516] = "mobile_dev_usb 有误"
	error_list[517] = "不支持这个拨号方式 ，只支持 10086,10000,10010"
	error_list[518] = "Adsl 的用户名密码不能为空"
	error_list[519] = "DNS 格式不正确"
	error_list[520] = "网关格式不正确"
	error_list[521] = "MAC 地址格式错误"
	error_list[522] = "MTU 不能为空"
	error_list[523] = "Channel 必须是 0-13 的整数"
	error_list[524] = "上传失败."
	error_list[525] = "图片已经存在."
	error_list[526] = "至少填写一个有效的 mac 地址."
	error_list[527] = "请选择 允许 , 或者禁止 以下 mac 地址."
	error_list[528] = "无可用更新."
	error_list[529] = "请选择 允许 或 禁止以下 MAC 地址选项."
	error_list[530] = "MTU 必须是 576-1492 之间的数字 ."
	error_list[531] = "MTU 必须是 576-1500 之间的数字 ."
	error_list[532] = "服务器错误 ."
	error_list[533] = "WAN IP与LAN IP不能在同一网段."
	error_list[534] = "WAN IP的范围必须是ABC类地址."
	error_list[535] = "主机号不能全0，也不能全1."
	error_list[536] = "DHCP 租用时间 的范围 是  2-2880 分钟 ，或  1-48 小时."
	error_list[537] = "IP 分配范围 和 租用时间 必须为正整数."
	error_list[538] = "非法 MAC 地址."
	error_list[540] = "LAN IP的范围必须是ABC类地址."
	error_list[541] = "172.31 为保留的 ip 段."
	error_list[542] = "设备认证失败."
	error_list[543] = "LCP请求发送间隔  范围 0-120 秒."
	error_list[544] = "升级失败请重试. code:544"
	error_list[545] = "设备名称不能为空."
	error_list[546] = "设备名称不能超过30个字符."
	error_list[547] = "当前路由器ROM不支持此功能，请升级路由器固件."
	error_list[548] = "请填写正确的 MAC 与 IP 地址."
	error_list[549] = "说明防火墙无法设置，终止操作."
	error_list[550] = "限速数值需要为大于等于 0 KB"
	error_list[551] = "未传入设备名称."
	error_list[552] = "密码为默认不安全."
	error_list[601] = "授权码必须是 16位字符."
	error_list[602] = "用户名和密码不能为空."
	error_list[603] = "用户名和密码长度小于 64 位."
	error_list[604] = "时间参数不正确."
	error_list[605] = "开始与结束时间不能相同."
	local out_put = "";
	if (error_list[errorcode] == nil) then
		out_put = 'unkown error'
	else
		out_put = error_list[errorcode]
	end
	return out_put
end

