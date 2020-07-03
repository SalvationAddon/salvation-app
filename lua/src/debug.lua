local debug = {
    enabled = false
}

-- todo add decoration
debug.print = function(msg)
    if debug.enabled == true then
        print('|cFFf1b3ff[Salvation-Debug] ' .. msg .. '|r')
    end
end

return debug
