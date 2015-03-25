#
# Copyright (C) 2013-2014 
#
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-default-chinese
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
PKG_INSTALL_DIR:=$(PKG_BUILD_DIR)/ipkg-install

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

define Package/luci-default-chinese
	SECTION:=luci-default-chinese
	CATEGORY:=LuCI
	SUBMENU:=5. Translations
	TITLE:=Set Simplified Chinese as default language.
	DEPENDS:=luci-i18n-chinese
endef

define Package/luci-default-chinese/description
	Set Simplified Chinese as default language.
endef

define Build/Prepare
endef
     
define Build/Compile
endef

define Package/luci-default-chinese/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/ucidef.sh $(1)/etc/uci-defaults/99-luci-default-chinese
endef

$(eval $(call BuildPackage,luci-default-chinese))