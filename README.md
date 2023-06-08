# dsk-lua
dsk-lua is a library which lets you write/read data to a DSK file (Amstrad CPC Diskette format), for use into SJASMPlus

in your SJASMPlus source, simply add :

```
; Wrapper for the DSK functions
    LUA
        package.path = "[where you want to put your LUA libs]/?.lua;"
        dsk = require("dsk")
    ENDLUA
    
    DEVICE AMSTRADCPC6128
start:

    ... Your code...
    
end:
  LUA PASS3
        dsk.create()
        dsk.save([Filename],[File type],[Start address],[End address],[Entry address])
        dsk.write("dist/mydsk.dsk")
  ENDLUA
```

- **Filename** in the AMSDOS format : 8 chars, a dot, then 3 chars for the extension. For example "TEST.BIN" is fine
- **File type** : 0=Basic, 1=Binary. Usually Binary
- **Start address** : Address where your program starts. Usually the same address than the ORG you set up at the start of your source
- **End address** : Address where your program ends.
- **Entry address** : The address where the CPC has to jump as soon as it has loaded your file. In most cases, it's the same address than the start address

...So the save line would look like :
```dsk.save("test.bin",1,sj.get_label("start"),sj.get_label("end"),sj.get_label("start"))```


