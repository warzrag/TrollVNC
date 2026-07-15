ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BlackBridgeGallery
BlackBridgeGallery_FILES = Tweak.xm
BlackBridgeGallery_CFLAGS = -fobjc-arc
BlackBridgeGallery_OBJCCFLAGS = -std=c++17
BlackBridgeGallery_FRAMEWORKS = Foundation UIKit Photos

include $(THEOS_MAKE_PATH)/tweak.mk
