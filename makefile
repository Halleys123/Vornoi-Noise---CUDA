WINDOWS_KIT_BASE_PATH := C:\Program Files (x86)\Windows Kits\10

WINDOWS_KIT_INCLUDE_PATH := $(WINDOWS_KIT_BASE_PATH)\Include\10.0.26100.0
WINDOWS_KIT_LIB_PATH := $(WINDOWS_KIT_BASE_PATH)\Lib\10.0.26100.0

MSVC_BASE_PATH := C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207

WINDOWS_KITS_INCLUDE_FOLDERS = \
	-I"$(WINDOWS_KIT_INCLUDE_PATH)\um" \
	-I"$(WINDOWS_KIT_INCLUDE_PATH)\shared" \
	-I"$(WINDOWS_KIT_INCLUDE_PATH)\winrt" \
	-I"$(WINDOWS_KIT_INCLUDE_PATH)\cppwinrt"
MSVC_INCLUDE_FOLDERS = \
	-I"$(MSVC_BASE_PATH)\include" \
	-I"$(MSVC_BASE_PATH)\atlmfc\include"

# Include Paths will be used in commmand
INCLUDE_FLAGS = -Iinclude $(WINDOWS_KIT_INCLUDE_FOLDERS) $(MSVC_INCLUDE_FOLDERS) 

LIBRARY_PATHS = \
	-L"$(WINDOWS_KIT_LIB_PATH)\um\x64" \
	-L"$(WINDOWS_KIT_LIB_PATH)\ucrt\x64" \
	-L"$(MSVC_BASE_PATH)\lib\x64" \
	-L"$(MSVC_BASE_PATH)\atlmfc\lib\x64"

LIBRARIES = -luser32 -lgdi32 -lopengl32 

#Include files
SRC_FILES = ./src/glad.c ./src/WndProc.cu ./src/PixelFormat.c

build:
	@echo "Building the project..."
	nvcc main.cu $(SRC_FILES) $(INCLUDE_FLAGS) $(LIBRARY_PATHS) $(LIBRARIES) -o build
	@echo "Build complete."