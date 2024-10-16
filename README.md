# Installation

- clone the repository

- run `git submodule update --init --recursive`

- install zig

  - macOS

    - `brew install zig`

  - Windows
    - https://ziglang.org/learn/getting-started/

- install probe-rs using the below instructions

  - macOS

    - `curl --proto '=https' --tlsv1.2 -LsSf https://github.com/probe-rs/probe-rs/releases/download/v0.22.0/probe-rs-installer.sh | sh`

  - Windows
    - `irm https://github.com/probe-rs/probe-rs/releases/download/v0.22.0/probe-rs-installer.ps1 | iex`

# Build the project

First add the names of the executables (all .c files with a `main` function) to the `executables`
list in `build.zig`.

run `zig build {name of executable without .c}`

Example: `zig build lab1`

# Build and flash the project

run `zig build flash-{name of executable without .c}`

Example: `zig build flash-lab1`

then press the reset button on the device

# Usage

Make sure to add your FreeRTOSConfig.h file to the `include` folder. (freertos is currently
disabled)

The build.zig file defines where includes go (.h files) and where the source files (.c files) go. By
default source files go in the `src` folder and header files go in the `include` folder.

Zig also has a `-Doptimize=ReleaseFast` flag to enable optimizations. This significantly reduces the
binary size which makes flashing significantly faster.

`zig build lab1 -Doptimize=ReleaseFast`

`zig build flash-lab1 -Doptimize=ReleaseFast`
