cmake_minimum_required(VERSION 3.24)

project(picsu-plasmoid VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Mqtt)

set(PICSU_BACKEND_IMPORT_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/plasmoid/org.mraus.picsu/contents/imports/org/mraus/picsu/backend"
)

add_library(picsubackendplugin MODULE
    src/picsubackendplugin.cpp
    src/picsuimagesource.cpp
    src/picsuimagesource.h
)

target_link_libraries(picsubackendplugin
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Mqtt
)

set_target_properties(picsubackendplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${PICSU_BACKEND_IMPORT_DIR}"
)
