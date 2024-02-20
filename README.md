# Installation

run `git submodule update --init --recursive`

install zig

`brew install zig`

install probe-rs

## macOS

`curl --proto '=https' --tlsv1.2 -LsSf https://github.com/probe-rs/probe-rs/releases/download/v0.22.0/probe-rs-installer.sh | sh`

## Windows

`irm https://github.com/probe-rs/probe-rs/releases/download/v0.22.0/probe-rs-installer.ps1 | iex`

# Build the project

run `zig build`

# run and flash the project

run `zig build run`

then press the reset button on the device

# Usage

The build.zig file defines where includes go (.h files) and where the source files (.c files) go. By
default source files go in the `src` folder and header files go in the `include` folder.

The build.zig also defines what the "main" or "startup" file is. By default it is main.c
