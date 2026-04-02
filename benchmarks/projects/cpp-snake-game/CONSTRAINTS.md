# Project Constraints

## App Description

A classic snake game with smooth controls, collision detection, scoring, and clean rendering using SDL2.

## Tech Stack

- **Language:** C++17
- **Runtime:** N/A
- **Framework:** SDL2

## UI

- **Type:** Desktop (SDL2 window)
- **UI Framework:** SDL2
- **Design System:** N/A

## Database

- **Type:** None

## Auth

- **Type:** None

## Deployment

- **Target:** Local binary

## Back-Pressure Commands

- **Build:** `cmake --build build`
- **Test:** `ctest --test-dir build --output-on-failure`
- **Lint:** `clang-tidy src/*.cpp -- -std=c++17 -I/usr/local/include/SDL2`
- **Typecheck:** (built into compiler)
- **Format:** `clang-format --dry-run --Werror src/*.cpp src/*.h`

## Hard Requirements

- Must use C++17 standard
- Must use SDL2 for rendering and input
- Must use CMake as build system
- Must compile on macOS (SDL2 via Homebrew)
- No Objective-C required (pure C++ with SDL2)
