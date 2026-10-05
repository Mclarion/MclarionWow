-- Synthetic-only lexer calibration fixture; no player data.
MclarionWowData = {
    ["key\000\255\\\""] = "value\010\x1f\t\r\\\"'é",
    [1] = { "a", "b" },
    ["nested"] = { [2] = false, ["empty"] = {} },
}
