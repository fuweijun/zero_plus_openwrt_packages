#!/bin/sh
uci batch <<-EOF
	set uhttpd.main.cgi_prefix=/t
	commit uhttpd
EOF
/etc/init.d/uhttpd restart