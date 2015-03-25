#
# Copyright (C) 2013-2014 
#
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-zero-plus
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_INSTALL_DIR:=$(PKG_BUILD_DIR)/ipkg-install

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

define Package/luci-zero-plus
	SECTION:=luci-zero-plus
	CATEGORY:=LuCI
	SUBMENU:=2. Modules
	TITLE:=For Zero plus.
	DEPENDS:=luci-i18n-chinese
endef

define Package/luci-zero-plus/description
	Set STA/AP mode for Zero plus.
endef

define Build/Prepare
endef
     
define Build/Compile
endef

define Package/luci-zero-plus/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,luci-zero-plus))