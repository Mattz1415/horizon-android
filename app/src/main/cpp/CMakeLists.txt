cmake_minimum_required(VERSION 3.22.1)

project("horizon_bridge")

add_library(
    horizon_bridge
    SHARED
    horizon_bridge.cpp
)

find_library(log-lib log)
find_library(android-lib android)
find_library(vulkan-lib vulkan)

target_link_libraries(
    horizon_bridge
    ${log-lib}
    ${android-lib}
    ${vulkan-lib}
)
