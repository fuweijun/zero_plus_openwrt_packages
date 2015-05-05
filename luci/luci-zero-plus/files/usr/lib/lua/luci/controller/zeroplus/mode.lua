--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2011 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--

module("luci.controller.zeroplus.mode", package.seeall)

function index()
	entry({"zeroplus", "mode"}, alias("zeroplus", "mode", "sta"), _("Wi-Fi"), 1).index = true
	entry({"zeroplus", "mode","sta"}, template("zeroplus/sta"), _("Station(STA)"), 1)
	entry({"zeroplus", "mode", "ap"}, template("zeroplus/ap"), _("Access Point(AP)"), 2) --设置无线信息
	entry({"zeroplus", 'mode', "set_ak"}, call("set_ak"), _(""), 3) -- 设置云端accesskey
	entry({"zeroplus", 'mode', "get_aplist"}, call("get_aplist"), _(""), 4)
	entry({"zeroplus", 'mode', "get_bridge"}, call("get_bridge"), _(""), 5)  -- 获取中继信息
	entry({"zeroplus", 'mode', "set_bridge"}, call("set_bridge"), _(""), 6)
	entry({"zeroplus", 'mode', "set_ap"}, call("set_ap"), _(""), 7) 		  -- 设置ap信息
	entry({"zeroplus", 'mode', "view_detail"}, call("view_detail"), _(""), 8) -- 获取无线信息	
	entry({"zeroplus", 'mode', "wifi_status"}, call("wifi_status"), _(""), 9) -- 获取无线信息	
	entry({"zeroplus", 'mode', "del_bridge"}, call("del_bridge"), _(""), 10)

end

-- 设置云端accesskey
function set_ak()
--/cgi-bin/luci/zeroplus/mode/set_ak?ak=xxxxxxxx
	luci.http.prepare_content("application/json")	
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
 	local http = require "luci.http"
	local ak = luci.http.formvalue("ak")
	
	if ak == nil then --todo 合法性检测
		codeResp = 20
	else
		--luci.sys.exec("uci add ak xxxxx")
		luci.sys.exec("echo %s > /etc/config/ak" % ak)
	end
	msgResp = luci.util.get_api_error(codeResp)
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	http.write_json(arr_out_put)
end



function get_ifname()
	return luci.util.trim(luci.util.exec("uci get wireless.@wifi-iface[0].device"))
end

--解析加密模式

function format_wifi_encryption(info)
	if info.wep == true then
		return "WEP"
	elseif info.wpa > 0 then
		return translatef("<abbr title='Pairwise: %s / Group: %s'>%s - %s</abbr>",
			table.concat(info.pair_ciphers, ", "),
			table.concat(info.group_ciphers, ", "),
			(info.wpa == 3) and translate("mixed WPA/WPA2")
				or (info.wpa == 2 and "WPA2" or "WPA"),
			table.concat(info.auth_suites, ", ")
		)
	elseif info.enabled then
		return "<em>%s</em>" % translate("unknown")
	else
		return "<em>%s</em>" % translate("open")
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


-- 获取AP列表
function get_aplist()
	luci.http.prepare_content("application/json")	
	local http = require "luci.http"
	local aplistResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local aplist
	local ifname = get_ifname()
	local iw = luci.sys.wifi.getiwinfo(ifname)
	aplist = scanlist(iw,3)
	
	if(aplist) then
		arr_out_put["aplist"] = aplist
	end
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	http.write_json(arr_out_put)
end





--获得中继信息
function get_bridge()
	local http = require "luci.http"
	local statusResp = 0
	local ssidResp=''
	local keyResp=''
	local encryptionResp=''
	local channelResp=''
	local bssidResp=''
	local is_connectResp = 0
	local codeResp = 0
	local msgResp = "ok"
	local arr_out_put={}
	
	local mode=''
	mode = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[1].mode"))
	if mode == "sta" then
		statusResp = 1
		is_connectResp = bridge_sta()
		ssidResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[1].ssid"))
		keyResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[1].key"))
		encryptionResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[1].encryption"))	
		channelResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-device[0].channel"))
		bssidResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[1].bssid"))
	end	

	arr_out_put["status"] = statusResp	--  是否是 bridge 模式
	arr_out_put["is_connect"] = is_connectResp	--  是否联通
	arr_out_put["ssid"] = ssidResp
	arr_out_put["key"] = keyResp
	arr_out_put["encryption"] = encryptionResp
	arr_out_put["channel"] = channelResp
	arr_out_put["bssid"] = bssidResp

	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	arr_out_put["sta"] = bridge_sta()
	
	http.write_json(arr_out_put)
	http.close()
end

-- 设置中继信息
function set_bridge()
	local http = require "luci.http"
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
	end
	if (ssidReq:len()>32) then
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
	if keyReq:len()>0 and encryptionReq == "open" then
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

		http.write_json(arr_out_put)
		http.close()
		os.execute("sleep 2")
		
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
		luci.sys.exec("uci set wireless.@wifi-iface[1].disabled=0")
		--luci.sys.exec("uci set wireless.@wifi-iface[1].ssid='" .. ssidReq .."'")
		luci.sys.exec("uci commit wireless")

--[[ 			
		option network 'wwan'
        option ssid 'R&D_WiFi'
        option encryption 'psk2'
        option device 'radio0'
        option mode 'sta'
        option bssid '6C:E8:73:77:5B:2E'
        option key '0987654321'
        option channel '1'
]]

--(ssidReq, encryptionReq, keyReq, channelReq, bssidReq)
		
		local result=0
		if result == 0 then		
			os.execute("wifi")
		end
	else
		msgResp = luci.util.get_api_error(codeResp)
		arr_out_put["code"] = codeResp
		arr_out_put["msg"] = msgResp
		http.write_json(arr_out_put)
		http.close()
	end
	

end

function view_detail()
	local http = require "luci.http"
	local deviceReq = luci.http.formvalue("device")
	local deviceResp
	local ssidResp
	local ssidprefixResp
	local modeResp
	local encryptionResp
	local wifi_keyResp
	local statusResp
	local signalResp
	local qualityResp
	local speedResp
	local hiddenResp
	local channelResp
	local codeResp = 0
	local msgResp = ""
	local arr_out_put={}
	local uptime = luci.sys.uptime()


	deviceResp = "radio0.network1"
	ssidResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[0].ssid"))
	ssidprefixResp=''
	modeResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[0].mode"))
	encryptionResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[0].encryption"))	
	wifi_keyResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-iface[0].key"))
	statusResp=1
	signalResp=-52
	qualityResp=10
	channelResp = luci.util.trim(luci.sys.exec("uci get wireless.@wifi-device[0].channel"))
	hiddenResp=0
--	uptime=luci.sys.uptime()
	
	if (codeResp == 0) then
		arr_out_put["device"] = deviceResp
		arr_out_put["ssid"] = ssidResp
		arr_out_put["ssidprefix"] = ssidprefixResp
		arr_out_put["mode"] = modeResp
		arr_out_put["encryption"] = encryptionResp
		arr_out_put["wifi_key"] = wifi_keyResp
		arr_out_put["status"] = statusResp
		arr_out_put["signal"] = signalResp
		arr_out_put["quality"] = qualityResp
		arr_out_put["channel"] = channelResp
		arr_out_put["hidden"] = hiddenResp
		arr_out_put["uptime"] = uptime
	else
		msgResp = luci.util.get_api_error(codeResp)
	end
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	http.write_json(arr_out_put,true)
end


function wifi_status()
	local s    = require "luci.tools.status"
	local rv   = { }
	rv[#rv+1] = s.wifi_network('wlan0')	
	rv[#rv+1] = s.wifi_network('wlan0-1')
	if #rv > 0 then
		luci.http.prepare_content("application/json")
		luci.http.write_json(rv)
		return
	end
	luci.http.status(404, "No such device")
end


--获取wwan连接状态 根据连接时间判定
function bridge_sta()
	local netm = require "luci.model.network".init()	
	local net = netm:get_network("wwan")
	if net then
			local time = net:uptime()	
		if time > 0 then
			return 1
		end
	end
	return 0
end


function del_bridge()
	local http = require "luci.http"
	local codeResp = 0
	local msgResp = "OK"
	local arr_out_put={}	

	--del wifi bridge
	--del firewall		
	luci.sys.call('uci set firewall.@zone[1].network="wan wan6"')
	luci.sys.call("uci commit firewall")
		
	--del network wwan
	luci.sys.call("uci delete network.wwan")
	luci.sys.call("uci commit network")
	
	--del wireless interface		
	luci.sys.call("uci delete wireless.@wifi-iface[1]")
	luci.sys.call("uci commit wireless")
	luci.sys.call("wifi")
	--luci.sys.call("env -i /sbin/ifdown wwan >/dev/null 2>/dev/null")
	
	arr_out_put["code"] = codeResp
	arr_out_put["msg"] = msgResp
	http.write_json(arr_out_put)
	http.close()
end

--设置ap信息
function set_ap()
	luci.http.prepare_content("application/json")
	local http = require "luci.http"
	local ssidReq = luci.http.formvalue("ssid")
	local keyReq = luci.http.formvalue("key")
	local encryptionReq = luci.http.formvalue("encryption")
	local channelReq = luci.http.formvalue("channel")
	
	local codeResp = 0
	local msgResp = "OK"
	local arr_out_put={}

	--none 修改为 open  判断逻辑后改回
	if(encryptionReq == "none")then
		encryptionReq = "open"
	end
	
	if(encryptionReq == "open")then
		keyReq = ""
	end
	
	if (ssidReq == nil or ssidReq == "") then
		codeResp = 311
	end
	if (ssidReq:len()>32) then
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
	if keyReq:len()>0 and encryptionReq == "open" then
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
		http.write_json(arr_out_put)
		http.close()		
		os.execute("sleep 1")
		--set wireless interface
		luci.sys.exec("uci set wireless.@wifi-device[0].channel='%s'" % channelReq)
		luci.sys.exec("uci set wireless.@wifi-iface[0].network='lan'")
		luci.sys.exec("uci set wireless.@wifi-iface[0].mode='ap'")
		luci.sys.exec("uci set wireless.@wifi-iface[0].device='radio0'")
		luci.sys.exec("uci set wireless.@wifi-iface[0].ssid='%s'" % ssidReq)
		luci.sys.exec("uci set wireless.@wifi-iface[0].encryption='%s'" % encryptionReq)
		luci.sys.exec("uci set wireless.@wifi-iface[0].key='%s'" % keyReq)
		luci.sys.exec("uci commit wireless")		
		luci.sys.exec("wifi")
	else
		msgResp = luci.util.get_api_error(codeResp)
		arr_out_put["code"] = codeResp
		arr_out_put["msg"] = msgResp
		http.write_json(arr_out_put)
		http.close()
	end	

end