    ifndef INCLUDE_DSK_ASM
    define INCLUDE_DSK_ASM

    ; Wrapper for the DSK functions
    LUA
        package.path = "./src/std/?.lua;"
        dsk = require("dsk")
    ENDLUA

    endif