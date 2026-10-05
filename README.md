# BG3-fix-stragglers
🐌 Baldur's Gate 3 mod that circumvents bad companion pathfinding.

## Run tests

With DribbleSpec loaded, reload the server Lua VM and run `!fs_tests --context server --quiet` in the BG3SE console.

For the isolated teleport-dispatch test, run `lua tests/TeleportDispatch.test.lua` with Lua 5.1 from the `Fix Stragglers` directory.
