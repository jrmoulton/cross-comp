# Installation

run `git submodule update --init --recursive`

install zig

`brew install zig`

install probe-rs

`curl --proto '=https' --tlsv1.2 -LsSf https://github.com/probe-rs/probe-rs/releases/download/v0.22.0/probe-rs-installer.sh | sh`

# Build the project

run `zig build`

# run and flash the project

run `zig build run`

then press the reset button on the device
