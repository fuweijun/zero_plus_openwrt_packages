--[[
api for app set ap_mode

/t/get_aplist

/t/set_bridge
param:ssid  key  encryption  bssid  channel

]]--
require ("luci")
require ("luci.sys")

module("luci.hekr.mode", package.seeall)
local ltn12 = require("luci.ltn12")

--- Send the given data as JSON encoded string.
-- @param data		Data to send
function print_json(x)
	if x == nil then
		print("null")
	elseif type(x) == "table" then
		local k, v
		if type(next(x)) == "number" then
			print("[ ")
			for k, v in ipairs(x) do
				print_json(v)
				if next(x, k) then
					print(", ")
				end
			end
			print(" ]")
		else
			print("{ ")
			for k, v in pairs(x) do
			print("%q: " % k)
				print_json(v)
				if next(x, k) then
					print(", ")
				end
			end
			print(" }")
		end
	elseif type(x) == "number" or type(x) == "boolean" then
		if (x ~= x) then
			-- NaN is the only value that doesn't equal to itself.
			print("Number.NaN")
		else
			print(tostring(x))
		end
	else
		print('"%s"' % tostring(x):gsub('["%z\1-\31]', function(c)
			return '\\u%04x' % c:byte(1)
		end))
	end
end



function scanlist(iw,times)
	local i, k, v
	local l = { }
	local s = { }
	for i = 1, times do
		for k, v in ipairs(iw.scanlist or { }) do
			if not s[v.bssid] then
				l[#l+1] = v
				s[v.bssid] = true
			end
		end
	end
	return l
end

function get_ifname()
	return luci.util.trim(luci.util.exec("uci get wireless.@wifi-iface[0].device"))
end
-- 获取AP列表
function get_aplist()
	--local http = require "luci.http"	
	local sys = require "luci.sys"	
	local aplistResp
	local codeResp = 0
	local msgResp = ""
	local aplist
	local ifname = get_ifname()	
	local iw = sys.wifi.getiwinfo("wlan0")	
	aplist = scanlist(iw,3)	
	print("Content-Type: text/json\n")	
	print_json(aplist)
end

 

-- Limited source to avoid endless blocking
local function limitsource(handle, limit)
	limit = limit or 0
	local BLOCKSIZE = ltn12.BLOCKSIZE

	return function()
		if limit < 1 then
			handle:close()
			return nil
		else
			local read = (limit > BLOCKSIZE) and BLOCKSIZE or limit
			limit = limit - read

			local chunk = handle:read(read)
			if not chunk then handle:close() end
			return chunk
		end
	end
end

function set_bridge()

	local util = require "luci.util"
	local http = require "luci.http"
	http.context.request = luci.http.Request(
		luci.sys.getenv(),
		limitsource(io.stdin, tonumber(luci.sys.getenv("CONTENT_LENGTH"))),
		ltn12.sink.file(io.stderr)
	)	
	print("Content-Type: text/json; charset=UTF-8\n") 
	--http.prepare_content(json)
	local ssidReq = luci.http.formvalue("ssid")
	local keyReq = luci.http.formvalue("key")
	local encryptionReq = luci.http.formvalue("encryption")
	local bssidReq = luci.http.formvalue("bssid")
	local channelReq = luci.http.formvalue("channel")
	local codeResp = 0
	local msgResp = "OK"
	local arr_out_put={}
 
	if(encryptionReq == "open")then
		keyReq = ""
	end
	
	if (ssidReq == nil or ssidReq == "") then
		codeResp = 311
		elseif (ssidReq:len()>32) then
			codeResp = 312
		
	end
	if (ssidReq == nil or ssidReq == "") and (encryptionReq == nil or encryptionReq == "") and (keyReq == nil or keyReq == "") then
		codeResp = 310
	end
	if encryptionReq ~= nil and encryptionReq ~= "open" and encryptionReq ~= "mixed-psk" and encryptionReq ~= "mixed-psk-tkip" and encryptionReq ~= "psk" and encryptionReq ~= "psk-tkip" and encryptionReq ~= "psk2" and encryptionReq ~= "psk2-tkip" and encryptionReq ~= "wep" and encryptionReq ~= "wep-open" and encryptionReq ~= "wep-share" then
		codeResp = 402
	end
	if encryptionReq ~= nil then
		if encryptionReq == "psk" or encryptionReq == "psk-tkip" or encryptionReq == "psk2" or encryptionReq == "psk2-tkip"then
			if  keyReq:len()<8 then
				codeResp = 403
			end
		elseif encryptionReq == "mixed-psk" or encryptionReq == "mixed-psk-tkip" then
			if  keyReq:len()<8 or keyReq:len()>63 then
				codeResp = 405
			end
		elseif encryptionReq == "wep" or encryptionReq == "wep-open" or encryptionReq == "wep-share" then
			if  keyReq:len()~=5 and keyReq:len()~=13 then
				codeResp = 404
			end
		end
	end
	if(keyReq == nil or keyReq == "") then
		odeResp = 406
		elseif keyReq:len()>0 and encryptionReq == "open" then
			codeResp = 406		
	end
	if not tonumber(channelReq) or tonumber(channelReq)<0 and tonumber(channelReq)>13 then
		codeResp = 523
	end
	
	--open 修改为 none
	if(encryptionReq == "open")then
		encryptionReq = "none"
	end
	
 
	if codeResp == 0 then

		arr_out_put["code"] = codeResp
		arr_out_put["msg"] = msgResp

		print_json(arr_out_put)


		luci.sys.exec("sleep 2")

		--set wifi bridge		
		--set firewall		
		luci.sys.exec('uci set firewall.@zone[1].network="wan wan6 wwan"')
		luci.sys.exec("uci commit firewall")
		
		--set network
		luci.sys.exec("uci set network.wwan=interface")
		luci.sys.exec("uci set network.wwan.proto=dhcp")
		luci.sys.exec("uci commit network")
		
		--set wireless
		luci.sys.exec("uci set wireless.@wifi-device[0].channel='%s'" % channelReq)
		luci.sys.exec("uci set wireless.@wifi-iface[0].network='lan'")	
		--luci.sys.exec("uci set wireless.@wifi-iface[0].ssid='Zero+'")
		
		--add new interface
		local rc=''
		rc = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[1].network"))
		if rc ~='wwan' then 
			luci.sys.exec("uci add wireless wifi-iface")
		end
		
		--set bridge info
		luci.sys.exec("uci set wireless.@wifi-iface[1].network='wwan'")
		luci.sys.exec("uci set wireless.@wifi-iface[1].mode='sta'")
		luci.sys.exec("uci set wireless.@wifi-iface[1].device='radio0'")
		luci.sys.exec("uci set wireless.@wifi-iface[1].ssid='%s'" % ssidReq)
		luci.sys.exec("uci set wireless.@wifi-iface[1].encryption='%s'" % encryptionReq)
		luci.sys.exec("uci set wireless.@wifi-iface[1].key='%s'" % keyReq)
		luci.sys.exec("uci set wireless.@wifi-iface[1].bssid='%s'" % bssidReq)
		--luci.sys.exec("uci set wireless.@wifi-iface[1].ssid='" .. ssidReq .."'")
		luci.sys.exec("uci commit wireless")	
		luci.sys.exec("wifi")

	else
		msgResp = get_api_error(codeResp)
		arr_out_put["code"] = codeResp
		arr_out_put["msg"] = msgResp
		print_json(arr_out_put)
	end	
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
	error_list[523] = "Channel 必须是 0-13 的整数"
	local out_put = "";
	if (error_list[errorcode] == nil) then
		out_put = 'unkown error'
	else
		out_put = error_list[errorcode]
	end
	return out_put
end


