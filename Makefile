TARGET := iphone:clang:latest:14.0   # <--- 原来是 7.0，现在改为 14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DisconnectAppNetwork

DisconnectAppNetwork_FILES = Tweak.xm
DisconnectAppNetwork_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
