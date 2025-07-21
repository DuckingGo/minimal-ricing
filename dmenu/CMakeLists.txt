cmake_minimum_required(VERSION 3.15)
project(dmenu VERSION 5.3 LANGUAGES C DESCRIPTION "Dynamic menu for X11")

#-----------------------------------------------------------------------------
# Configuration Options
#-----------------------------------------------------------------------------
option(WITH_XINERAMA "Build with Xinerama support" ON)
option(WITH_STEST "Build stest utility" ON)
option(WITH_PANGO "Build with Pango support (alternative to Xft)" OFF)

#-----------------------------------------------------------------------------
# System Configuration
#-----------------------------------------------------------------------------
set(PREFIX "/usr/local" CACHE PATH "Installation prefix")
set(MANPREFIX "${PREFIX}/share/man" CACHE PATH "Man page installation directory")

#-----------------------------------------------------------------------------
# Compiler Settings
#-----------------------------------------------------------------------------
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_compile_options(
    -pedantic
    -Wall
    -Wextra
    $<$<CONFIG:RELEASE>:-Os>
)

#-----------------------------------------------------------------------------
# Dependencies
#-----------------------------------------------------------------------------
find_package(PkgConfig REQUIRED)
find_package(X11 REQUIRED)

# Font rendering backend selection
if(WITH_PANGO)
    pkg_check_modules(PANGO REQUIRED pango)
    add_definitions(-DPANGO)
else()
    find_library(XFT_LIB Xft REQUIRED)
    find_library(FONTCONFIG_LIB fontconfig REQUIRED)
    find_package(Freetype REQUIRED)
endif()

# Xinerama support
if(WITH_XINERAMA)
    find_library(XINERAMA_LIB Xinerama)
    if(XINERAMA_LIB)
        message(STATUS "Found Xinerama: ${XINERAMA_LIB}")
        add_definitions(-DXINERAMA)
    else()
        message(WARNING "Xinerama not found - building without support")
        set(WITH_XINERAMA OFF)
    endif()
endif()

#-----------------------------------------------------------------------------
# File Configuration
#-----------------------------------------------------------------------------
configure_file(
    ${CMAKE_SOURCE_DIR}/include/config.def.h
    ${CMAKE_BINARY_DIR}/config.h
    COPYONLY
)

#-----------------------------------------------------------------------------
# Include Directories
#-----------------------------------------------------------------------------
include_directories(
    ${CMAKE_BINARY_DIR}
    ${CMAKE_SOURCE_DIR}/include
    ${X11_INCLUDE_DIR}
)

if(WITH_PANGO)
    include_directories(${PANGO_INCLUDE_DIRS})
else()
    include_directories(${FREETYPE_INCLUDE_DIRS})
endif()

#-----------------------------------------------------------------------------
# Source Files
#-----------------------------------------------------------------------------
set(DMENU_SOURCES
    src/dmenu.c
    src/drw.c
    src/util.c
)

set(STEST_SOURCES
    src/stest.c
)

#-----------------------------------------------------------------------------
# Build Targets
#-----------------------------------------------------------------------------
add_executable(dmenu ${DMENU_SOURCES})
target_compile_definitions(dmenu PRIVATE
    -D_DEFAULT_SOURCE
    -D_BSD_SOURCE
    -D_XOPEN_SOURCE=700
    -D_POSIX_C_SOURCE=200809L
    -DVERSION="${PROJECT_VERSION}"
    $<$<BOOL:${WITH_XINERAMA}>:-DXINERAMA>
)

if(WITH_PANGO)
    target_link_libraries(dmenu
        ${X11_LIBRARIES}
        ${PANGO_LIBRARIES}
        $<$<BOOL:${WITH_XINERAMA}>:${XINERAMA_LIB}>
    )
else()
    target_link_libraries(dmenu
        ${X11_LIBRARIES}
        ${XFT_LIB}
        ${FONTCONFIG_LIB}
        $<$<BOOL:${WITH_XINERAMA}>:${XINERAMA_LIB}>
    )
endif()

if(WITH_STEST)
    add_executable(stest ${STEST_SOURCES})
    target_compile_definitions(stest PRIVATE
        -D_DEFAULT_SOURCE
        -D_BSD_SOURCE
        -D_XOPEN_SOURCE=700
        -D_POSIX_C_SOURCE=200809L
    )
    target_link_libraries(stest ${X11_LIBRARIES})
endif()

#-----------------------------------------------------------------------------
# Installation
#-----------------------------------------------------------------------------
install(TARGETS dmenu
    DESTINATION ${PREFIX}/bin
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)

if(WITH_STEST)
    install(TARGETS stest
        DESTINATION ${PREFIX}/bin
        PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE
            WORLD_READ WORLD_EXECUTE
    )
endif()

install(FILES
    man/dmenu.1
    DESTINATION ${MANPREFIX}/man1
)

if(WITH_STEST)
    install(FILES
        man/stest.1
        DESTINATION ${MANPREFIX}/man1
    )
endif()

install(PROGRAMS
    scripts/dmenu_path
    scripts/dmenu_run
    DESTINATION ${PREFIX}/bin
)

#-----------------------------------------------------------------------------
# Packaging
#-----------------------------------------------------------------------------
include(InstallRequiredSystemLibraries)
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_CONTACT "DuckingGo")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "DuckingGo")
set(CPACK_GENERATOR "TGZ;DEB")
include(CPack)

#-----------------------------------------------------------------------------
# Custom Targets
#-----------------------------------------------------------------------------
add_custom_target(distclean
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_BINARY_DIR}
    COMMENT "Cleaning all build files"
)

add_custom_target(dist
    COMMAND git archive --prefix=dmenu-${PROJECT_VERSION}/ HEAD | gzip > dmenu-${PROJECT_VERSION}.tar.gz
    COMMENT "Creating source distribution package"
)

#-----------------------------------------------------------------------------
# Dependency Checks
#-----------------------------------------------------------------------------
include(FeatureSummary)
feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)


#-----------------------------------------------------------------------------
# Testing (optional)
#-----------------------------------------------------------------------------
if(WITH_STEST)
    enable_testing()
    add_test(NAME stest_test COMMAND stest -v)
endif()