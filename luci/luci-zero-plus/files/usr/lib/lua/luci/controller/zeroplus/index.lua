--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--

module("luci.controller.zeroplus.index", package.seeall)

function index()
	local root = node()
	if not root.target then
		root.target = alias("zeroplus")
		root.index = true
	end

	local page   = node("zeroplus")
	page.target  = firstchild()
	page.title   = _("ZeroPlus")
	page.order   = 10
	--page.sysauth = "root"
	--page.sysauth_authenticator = "htmlauth"
	page.ucidata = true
	page.index = true

	-- Empty services menu to be populated by addons
	--entry({"zeroplus", "services"}, firstchild(), _("Services"), 40).index = true

	entry({"zeroplus", "login"},alias("admin", "status", "overview"), _("Login"), 90)
end


