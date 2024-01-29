.PHONY: all clean format debug release duckdb_debug duckdb_release pull update

all: release

MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJ_DIR := $(dir $(MKFILE_PATH))

CMAKE_VARS ?=
OSX_BUILD_ARCH_FLAG=
ifneq (${OSX_BUILD_ARCH}, "")
	OSX_BUILD_ARCH_FLAG=-DOSX_BUILD_ARCH=${OSX_BUILD_ARCH}
endif
ifeq (${STATIC_LIBCPP}, 1)
	STATIC_LIBCPP=-DSTATIC_LIBCPP=TRUE
endif
ifeq (${DISABLE_EXTENSION_LOAD}, 1)
	CMAKE_VARS:=${CMAKE_VARS} -DDISABLE_EXTENSION_LOAD=1
endif

ifeq ($(GEN),ninja)
	GENERATOR=-G "Ninja"
	FORCE_COLOR=-DFORCE_COLORED_OUTPUT=1
endif

BUILD_FLAGS=-DEXTENSION_STATIC_BUILD=1 -DBUILD_EXTENSIONS="" ${OSX_BUILD_ARCH_FLAG} ${STATIC_LIBCPP} ${TOOLCHAIN_FLAGS}

CLIENT_FLAGS :=

# These flags will make DuckDB build the extension
EXTENSION_FLAGS=\
-DDUCKDB_EXTENSION_NAMES="arrow" \
-DDUCKDB_EXTENSION_ARROW_PATH="$(PROJ_DIR)" \
-DDUCKDB_EXTENSION_ARROW_LOAD_TESTS=1 \
-DDUCKDB_EXTENSION_ARROW_SHOULD_LINK=0 \
-DDUCKDB_EXTENSION_ARROW_TEST_PATH=$(PROJ_DIR)test \
-DDUCKDB_EXTENSION_ARROW_INCLUDE_PATH="$(PROJ_DIR)src/include"

pull:
	git submodule init
	git submodule update --recursive --remote

clean:
	rm -rf build
	rm -rf testext
	cd duckdb && make clean
	cd duckdb/tools/nodejs && make clean

# Main build
debug:
	mkdir -p  build/debug && \
	cmake $(GENERATOR) $(FORCE_COLOR) $(EXTENSION_FLAGS) ${CLIENT_FLAGS} ${CMAKE_VARS} -DEXTENSION_STATIC_BUILD=1 -DCMAKE_BUILD_TYPE=Debug ${BUILD_FLAGS} -S ./duckdb/ -B build/debug && \
	cmake --build build/debug --config Debug

release:
	mkdir -p build/release && \
	cmake $(GENERATOR) $(FORCE_COLOR) $(EXTENSION_FLAGS) ${CLIENT_FLAGS} ${CMAKE_VARS} -DEXTENSION_STATIC_BUILD=1 -DCMAKE_BUILD_TYPE=Release ${BUILD_FLAGS} -S ./duckdb/ -B build/release && \
	cmake --build build/release --config Release

# Main tests
test: test_release

test_release: release
	./build/release/test/unittest "$(PROJ_DIR)test/*"

test_debug: debug
	./build/debug/test/unittest "$(PROJ_DIR)test/*"

# Client tests
DEBUG_EXT_PATH='$(PROJ_DIR)build/debug/extension/arrow/arrow.duckdb_extension'
RELEASE_EXT_PATH='$(PROJ_DIR)build/release/extension/arrow/arrow.duckdb_extension'
test_js:
test_debug_js:
	ARROW_EXTENSION_BINARY_PATH=$(DEBUG_EXT_PATH) mocha -R spec --timeout 480000 -n expose-gc --exclude 'test/*.ts' -- "test/nodejs/**/*.js"
test_release_js:
	ARROW_EXTENSION_BINARY_PATH=$(RELEASE_EXT_PATH) mocha -R spec --timeout 480000 -n expose-gc --exclude 'test/*.ts' -- "test/nodejs/**/*.js"

format:
	find src/ -iname *.hpp -o -iname *.cpp | xargs clang-format --sort-includes=0 -style=file -i
	cmake-format -i CMakeLists.txt

update:
	git submodule update --remote --merge
