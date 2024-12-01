local dsk = {}
dsk.verbose = false -- Displays various informations while reading/writing

dsk.AMSDOS_FILETYPE_BASIC=0     -- FILETYPE constants, thanks to Lordheavy
dsk.AMSDOS_FILETYPE_PROTECTED=1
dsk.AMSDOS_FILETYPE_BINARY=2

--=======================================================================================
function dsk.init()
    dsk.datafile = nil
    dsk.catalog = nil
    dsk.tracks = nil
    dsk.version = 1
end

dsk.init() -- This will be executed as soon as the file is parsed

--=======================================================================================
function dsk.read(filename)
    dsk.catalog = nil
    dsk.tracks={}
    dsk.datafile = io.open(filename, "rb")
    if(dsk.datafile==nil) then
        sj.error("File '"..filename.."' not found")
        return false
    end

    header = dsk.datafile:read(34)
    if(header == "MV - CPCEMU Disk-File\r\nDisk-Info\r\n") then
        dsk.version = 1
    else
        if(header == "EXTENDED CPC DSK File\r\nDisk-Info\r\n") then
            dsk.version = 5
        else
            sj.error("The file '"..filename.."' is not a DSK file")
            return false
        end
    end

    local creator = dsk.datafile:read(14)
    dsk.tracksnumber = string.byte(dsk.datafile:read(1))
    dsk.sidesnumber = string.byte(dsk.datafile:read(1))
    dsk.tracksize = string.byte(dsk.datafile:read(1))+string.byte(dsk.datafile:read(1))*256

    if(dsk.verbose==true) then
        print("Opening file : "..filename.." [Creator:'"..creator.."'/Tracks:"..dsk.tracksnumber.."/Sides:"..dsk.sidesnumber.."/Track size:"..dsk.tracksize.."]")
    end

    dsk.tracks={}

    dsk.datafile:seek("set",256)

    -- Tracks reading

    for cpt_tracks_sides = 0,(dsk.tracksnumber*dsk.sidesnumber)-1,1
    do
        local trackheader = dsk.datafile:read(12)
        dsk.datafile:seek("cur",4)
        local tracknum = string.byte(dsk.datafile:read(1))
        local sidenum = string.byte(dsk.datafile:read(1))

        dsk.datafile:seek("cur",2)

        dsk.tracks[tracknum]={}
        dsk.tracks[tracknum][sidenum]={}

        dsk.tracks[tracknum][sidenum].sectorssize = string.byte(dsk.datafile:read(1))
        dsk.tracks[tracknum][sidenum].sectorsnumber = string.byte(dsk.datafile:read(1))
        dsk.tracks[tracknum][sidenum].gap = string.byte(dsk.datafile:read(1))
        dsk.tracks[tracknum][sidenum].filler = string.byte(dsk.datafile:read(1))

        if(dsk.verbose==true) then
            print("Track : "..tracknum.." / side : "..sidenum.." / sectors size : "..dsk.tracks[tracknum][sidenum].sectorssize.." / nb of sectors : "..dsk.tracks[tracknum][sidenum].sectorsnumber)
        end

        dsk.tracks[tracknum][sidenum].sector={}

        for cpt_sectors = 0,dsk.tracks[tracknum][sidenum].sectorsnumber-1,1
        do
            dsk.tracks[tracknum][sidenum].sector[cpt_sectors]={}

            dsk.datafile:seek("cur",2)
            dsk.tracks[tracknum][sidenum].sector[cpt_sectors].id = string.byte(dsk.datafile:read(1))
            dsk.tracks[tracknum][sidenum].sector[cpt_sectors].size = string.byte(dsk.datafile:read(1))
            dsk.tracks[tracknum][sidenum].sector[cpt_sectors].fdc1 = string.byte(dsk.datafile:read(1))
            dsk.tracks[tracknum][sidenum].sector[cpt_sectors].fdc2 = string.byte(dsk.datafile:read(1))
            dsk.datafile:seek("cur",2)

            if(dsk.verbose==true) then
                print("Sector num : "..cpt_sectors.." / id : "..string.format("#%02x",dsk.tracks[tracknum][sidenum].sector[cpt_sectors].id).." / size : "..dsk.tracks[tracknum][sidenum].sector[cpt_sectors].size)
            end
    
        end

        local pos=((dsk.datafile:seek()>>8)+1)<<8
        dsk.datafile:seek("set",pos)
         
        for cpt_sectors = 0,dsk.tracks[tracknum][sidenum].sectorsnumber-1,1
        do
            dsk.tracks[tracknum][sidenum].sector[cpt_sectors].data = dsk.datafile:read(256<<(dsk.tracks[tracknum][sidenum].sector[cpt_sectors].size-1))
        end

    end

    dsk.datafile:close()
    dsk.datafile = nil

    return true
end

--============================================================================================
function dsk.writedsk1(filename)

    dsk.datafile = io.open(filename, "w")
    if(dsk.datafile==nil) then
        sj.error("File '"..filename.."' can't be opened for writing. Wrong path ?")
        return false
    end

    dsk.datafile:write("MV - CPCEMU Disk-File\r\nDisk-Info\r\n")
    dsk.datafile:write("DSKLua/Flush"..string.char(228).." ")

    dsk.datafile:write(string.char(dsk.tracksnumber))
    dsk.datafile:write(string.char(dsk.sidesnumber))
    dsk.datafile:write(string.char(dsk.tracksize&255))
    dsk.datafile:write(string.char(dsk.tracksize>>8))

    local nbrecords = 0

    dsk.datafile:write(string.rep(string.char(0),204-nbrecords))

    for cpt_tracks = 0,dsk.tracksnumber-1,1
    do
        for cpt_sides = 0,dsk.sidesnumber-1,1
        do
            dsk.datafile:write("Track-Info\r\n")
            dsk.datafile:write(string.rep(string.char(0),4))

            dsk.datafile:write(string.char(cpt_tracks))
            dsk.datafile:write(string.char(cpt_sides))

            dsk.datafile:write(string.rep(string.char(0),2))

            dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sectorssize))
            dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber))
            dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].gap))
            dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].filler))

            for cpt_sectors = 0,dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber-1,1
            do
                dsk.datafile:write(string.char(cpt_tracks))
                dsk.datafile:write(string.char(cpt_sides))
                    
                dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].id))
                dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].size))
                dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].fdc1))
                dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].fdc2))
                local sizeofsector=(256<<(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].size)-1)
                dsk.datafile:write(string.char(sizeofsector&255))
                dsk.datafile:write(string.char(sizeofsector>>8))
            end

            local pos=dsk.datafile:seek()
            dsk.datafile:write(string.rep(string.char(0),(((pos>>8)+1)<<8)-pos))
            
            local realtracksize = 256

            for cpt_sectors = 0,dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber-1,1
            do
                dsk.datafile:write(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].data)
                realtracksize = realtracksize + string.len(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].data)
            end

            if(realtracksize~=dsk.tracksize) then
                dsk.datafile:write(string.rep(string.char(0),dsk.tracksize-realtracksize))
            end
            
        end
    end

    return true

end

--============================================================================================
function dsk.writedsk5(filename)

    dsk.datafile = io.open(filename, "w")
    if(dsk.datafile==nil) then
        sj.error("File '"..filename.."' can't be opened for writing. Wrong path ?")
        return false
    end

    dsk.datafile:write("EXTENDED CPC DSK File\r\nDisk-Info\r\n")
    dsk.datafile:write("DSKLua/Flush"..string.char(228).." ")

    dsk.datafile:write(string.char(dsk.tracksnumber))
    dsk.datafile:write(string.char(dsk.sidesnumber))
    dsk.datafile:write(string.char(dsk.tracksize&255))
    dsk.datafile:write(string.char(dsk.tracksize>>8))

    local nbrecords = 0

    if(dsk.version == 5) then
        for cpt_sides = 0,dsk.sidesnumber-1,1 do
            for cpt_tracks = 0,dsk.tracksnumber-1,1 do
                local tracklength = 256
                for cpt_sectors = 0,dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber-1,1
                do
                    tracklength = tracklength+(string.len(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].data))
                end
                nbrecords = nbrecords+1
                dsk.datafile:write(string.char(math.ceil(tracklength/256)))
            end
        end
    end

    dsk.datafile:write(string.rep(string.char(0),204-nbrecords))

    for cpt_sides = 0,dsk.sidesnumber-1,1
    do
        for cpt_tracks = 0,dsk.tracksnumber-1,1
        do
            dsk.datafile:write("Track-Info\r\n")
            dsk.datafile:write(string.rep(string.char(0),4))

            dsk.datafile:write(string.char(cpt_tracks))
            dsk.datafile:write(string.char(cpt_sides))

            dsk.datafile:write(string.rep(string.char(0),2))

            dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sectorssize))
            dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber))
            dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].gap))
            dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].filler))

            for cpt_sectors = 0,dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber-1,1
            do
                dsk.datafile:write(string.char(cpt_tracks))
                dsk.datafile:write(string.char(cpt_sides))
                    
                dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].id))
                dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].size))
                dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].fdc1))
                dsk.datafile:write(string.char(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].fdc2))
                local sizeofsector=(string.len(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].data))
                dsk.datafile:write(string.char(sizeofsector&255))
                dsk.datafile:write(string.char(sizeofsector>>8))
            end

            local pos=dsk.datafile:seek()
            dsk.datafile:write(string.rep(string.char(0),(((pos>>8)+1)<<8)-pos))
            
            local realtracksize = 256

            for cpt_sectors = 0,dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber-1,1
            do
                dsk.datafile:write(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].data)
                realtracksize = realtracksize + string.len(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].data)
            end

            local effectivetracksize=math.ceil(realtracksize/256)*256 -- Rounding tracksize to multiple of 256

            if(realtracksize~=effectivetracksize) then
                dsk.datafile:write(string.rep(string.char(0),effectivetracksize-realtracksize))
            end  
        end
    end

    return true

end

--============================================================================================
function dsk.write(filename)

    if(dsk.tracks==nil) then
        sj.error("File '"..filename.."' can't be written because it hasn't been initialized")
        return false
    end

    if(dsk.catalog~=nil) then
        dsk.writecatalog()
    end

    if(dsk.version == 1) then
        return dsk.writedsk1(filename)
    else
        if(dsk.version == 5) then
            return dsk.writedsk5(filename)
        else
            sj.error("File '"..filename.."' can't be written because it hasn't been initialized. DSK version not set")
            return false
        end
    end
end

--=======================================================================================
function dsk.create()
    dsk.tracks = {}
    dsk.catalog = nil
    dsk.freeblocks = nil

    dsk.tracksnumber = 42
    dsk.sidesnumber = 1
    dsk.tracksize = 4864 -- 9*512 + 256

    for cpt_tracks = 0,dsk.tracksnumber-1,1
    do
        dsk.tracks[cpt_tracks] = {}
        for cpt_sides = 0,dsk.sidesnumber-1,1
        do
            dsk.tracks[cpt_tracks][cpt_sides] = {}
            dsk.tracks[cpt_tracks][cpt_sides].sectorssize = 2
            dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber = 9
            dsk.tracks[cpt_tracks][cpt_sides].gap = 0x04E
            dsk.tracks[cpt_tracks][cpt_sides].filler = 0x0E5

            dsk.tracks[cpt_tracks][cpt_sides].sector = {}
            for cpt_sectors = 0,dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber-1,1
            do
                dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors] = {}
                dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].id = 0x0C1+(cpt_sectors*5)%9
                dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].size = 2
                dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].fdc1 = 0
                dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].fdc2 = 0
                dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].data = string.rep(string.char(dsk.tracks[cpt_tracks][cpt_sides].filler),256<<(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].size-1))
            end
        end
    end

    return true
end

--=======================================================================================
function dsk.getsector(track,side,id)
    for num,sect in pairs(dsk.tracks[track][side].sector) do
        if sect.id == id then
            return sect.data
        end
    end
    return nil
end

--=======================================================================================
function dsk.setsector(track,side,id,data)
    for num,sect in pairs(dsk.tracks[track][side].sector) do
        if sect.id == id then
            sect.data = string.sub(data..string.rep(string.char(0),512),1,512)
            return true
        end
    end
    return false
end

--=====================================================================================================================
--=====================================================================================================================
--                                                      Here starts the AMSDOS management
--=====================================================================================================================
--=====================================================================================================================

--=======================================================================================
function dsk.setblock(blocknum,data)
    local sectornum = blocknum*2
    local tracknum = math.floor(sectornum/9)
    local sectorid = 0xc1+(sectornum%9)
    local res = dsk.setsector(tracknum,0,sectorid,string.sub(data,1,512))

    if(res == false) then
        return false
    end

    sectornum = sectornum + 1
    tracknum = math.floor(sectornum/9)
    sectorid = 0xc1+(sectornum%9)

    return dsk.setsector(tracknum,0,sectorid,string.sub(data,513,1024))
end

--=======================================================================================
function dsk.initializefreeblocks()
    dsk.freeblocks = {}
    for i = 2,(dsk.tracksnumber*dsk.tracksize)>>10,1 do
        dsk.freeblocks[i] = true
    end
    dsk.freeblocks[0] = false -- Room for the directory
    dsk.freeblocks[1] = false
end

--=======================================================================================
function dsk.cat()
    if(dsk.tracks==nil) then
        dsk.create()
    end

    dsk.initializefreeblocks()

    dsk.catalog={}

    local directory = dsk.getsector(0,0,0x0c1)..dsk.getsector(0,0,0x0c2)..dsk.getsector(0,0,0x0c3)..dsk.getsector(0,0,0x0c4)

    for entrynum=0,63,1 do
        if(string.byte(string.sub(directory,entrynum*32+1,entrynum*32+1)) ~= 0x0E5) then
            dsk.catalog[entrynum+1]={}

            dsk.catalog[entrynum+1].key = string.sub(directory,entrynum*32,entrynum*32+12)
            dsk.catalog[entrynum+1].user = string.byte(directory,entrynum*32+1,entrynum*32+1)
            dsk.catalog[entrynum+1].filename = string.sub(directory,entrynum*32+2,entrynum*32+12)
            dsk.catalog[entrynum+1].numextension = string.byte(directory,entrynum*32+13,entrynum*32+13)
            dsk.catalog[entrynum+1].nbrecords = string.byte(directory,entrynum*32+16,entrynum*32+16)
            local nbblockstoread = ((dsk.catalog[entrynum+1].nbrecords+7)>>3)

            if(nbblockstoread>16) then
                nbblockstoread=16
            end

            dsk.catalog[entrynum+1].nbblocks = nbblockstoread
            dsk.catalog[entrynum+1].blocks = {}

            for blocks = 1,nbblockstoread,1 do
                dsk.catalog[entrynum+1].blocks[blocks] = string.byte(directory,entrynum*32+16+blocks,entrynum*32+16+blocks)
                dsk.freeblocks[dsk.catalog[entrynum+1].blocks[blocks]] = false
            end
        end
    end

    if(dsk.verbose==true) then
        for num,direntry in pairs(dsk.catalog) do
            io.write(direntry.user.." "..direntry.numextension.." "..direntry.filename.." "..direntry.nbblocks.." (")
            for x,numblock in pairs(direntry.blocks) do
                io.write(" "..numblock) 
            end
            print(" )")
        end
    end
end

--============================================================================================
function dsk.writecatalog() -- Writes the catalog on the tracks of the dsk
    local pos = 0

    local sectorc1 = nil
    local sectorc2 = nil
    local sectorc3 = nil
    local sectorc4 = nil


    for num, sector in pairs(dsk.tracks[0][0].sector) do
        if (sector.id == 0x0c1) then
            sectorc1 = num
        end
        if (sector.id == 0x0c2) then
            sectorc2 = num
        end
        if (sector.id == 0x0c3) then
            sectorc3 = num
        end
        if (sector.id == 0x0c4) then
            sectorc4 = num
        end
    end

    if ((sectorc1 == nil)or(sectorc2 == nil)or(sectorc3 == nil)or(sectorc4 == nil)) then
        return false
    end

    local cat = ""

    for num,catalogentry in pairs(dsk.catalog) do

        local newcat = string.char(catalogentry.user)
            .. catalogentry.filename
            .. string.char(catalogentry.numextension,0,0,catalogentry.nbrecords)

        for blocks = 1,#(catalogentry.blocks),1 do
            newcat = newcat .. string.char(catalogentry.blocks[blocks])
        end

        newcat = newcat .. string.rep(string.char(0),32-string.len(newcat))

        cat = cat .. newcat
    end

    cat=cat.. string.rep(string.char(0x0e5),2048-string.len(cat))

    dsk.tracks[0][0].sector[sectorc1].data = string.sub(cat,1,512)
    dsk.tracks[0][0].sector[sectorc2].data = string.sub(cat,513,1024)
    dsk.tracks[0][0].sector[sectorc3].data = string.sub(cat,1025,1536)
    dsk.tracks[0][0].sector[sectorc4].data = string.sub(cat,1537,2048)

    dsk.catalog = nil

    return true

end
--=======================================================================================
function dsk.deletefile(filename)
    for num,direntry in pairs(dsk.catalog) do
        if(direntry.filename == filename) then
            dsk.catalog[num]={}
        end
    end
    -- Now we remove the white records
    table.sort(dsk.catalog, function (k1, k2) if(k1.key == k2.key) then return k1.numrecord<k2.numrecord else return k1.filename < k2.filename end end )
end
--=======================================================================================
-- user     : a byte (usually 0)
-- filename : Filename (11 chars max) in uppercase
-- filetype : 0 => BASIC, 1=> Protected, 2 => BINARY / Please use the contants AMSDOS_FILETYPE_BASIC, AMSDOS_FILETYPE_PROTECTED or AMSDOS_FILETYPE_BINARY
-- loadaddr : Loading address
-- length   : Length of the file
function dsk.generateheader(user,filename,filetype,loadaddr,entryaddr,length)
    local header = string.char(user)
    ..string.upper(string.sub(filename.."           ",1,11))
    ..string.char(0,0,0,0,0,0,filetype,0,0,loadaddr&255,loadaddr>>8,0,length&255,length>>8,entryaddr&255,entryaddr>>8)
    ..string.rep(string.char(0),36)
    ..string.char(length&255,length>>8)
    ..string.char(0)

    local checksum=0
    for cpt=1,66,1 do
        checksum = checksum + string.byte(header,cpt,cpt)
    end

    header = header..string.char(checksum&255,checksum>>8)
    .." File generated by SJASMPlus, the best Z80 assembler ! " -- Since there's room in the header...
    ..string.rep(string.char(0),59-55)

    return header
end

--=======================================================================================
-- header   : The 128 bytes of a header we need to patch
-- user     : a byte (usually 0)
-- filename : Filename (11 chars max) in uppercase
-- filetype : 0 => BASIC, 1=> Protected, 2 => BINARY / Please use the contants AMSDOS_FILETYPE_BASIC, AMSDOS_FILETYPE_PROTECTED or AMSDOS_FILETYPE_BINARY
-- loadaddr : Loading address
-- length   : Length of the file
function dsk.populateheader(header,user,filename,filetype,loadaddr,entryaddr,length)
    if (string.len(header)>128) then
        sj.error("dsk.populateheader : The provided header must have a maximum length of 128 bytes")
        return false
    end

    header=header..string.rep(string.char(0),128-string.len(header))
    
    local headerpatched = string.char(user)
    ..string.upper(string.sub(filename.."           ",1,11))
    ..string.char(0,0,0,0,0,0,filetype,0,0,loadaddr&255,loadaddr>>8,0,length&255,length>>8,entryaddr&255,entryaddr>>8)
    ..string.sub(header,29)

    headerpatched2=string.sub(headerpatched,1,0x40)..string.char(length&255)..string.char(length>>8)
                    ..string.char(0)..string.sub(headerpatched,0x44)
    headerpatched=headerpatched2
    
    local checksum=0
    for cpt=1,66,1 do
        checksum = checksum + string.byte(headerpatched,cpt,cpt)
    end

    headerpatched2=string.sub(headerpatched,1,0x43)..string.char(checksum&255)..string.char(checksum>>8)..string.sub(headerpatched,0x46)

    headerpatched=headerpatched2

--    headerpatched[0x43+1]=length&255
--    headerpatched[0x43+2]=length>>8

    return headerpatched
end

--=======================================================================================
function dsk.adddirectoryentry(user,filename,nbrecords,blockslist)

    local nbblocksinentry = 0
    local currentextension = 0
    local numblockslefttowrite = #blockslist
    local catalogentry = nil

    for n,block in pairs(blockslist) do
        if(nbblocksinentry == 0) then
            catalogentry = {}
            catalogentry.key = string.char(user)..filename
            catalogentry.user = user
            catalogentry.filename = filename
            catalogentry.numextension = currentextension
            catalogentry.blocks = {}
            if (numblockslefttowrite>=16) then
                catalogentry.nbrecords = 128
            else
                catalogentry.nbrecords = numblockslefttowrite*8
            end
        end

        table.insert(catalogentry.blocks,block)
        nbblocksinentry = nbblocksinentry+1
        numblockslefttowrite = numblockslefttowrite -1

        if((nbblocksinentry == 16) or (numblockslefttowrite == 0)) then
            table.insert(dsk.catalog,catalogentry)
            nbblocksinentry = 0
            currentextension = currentextension+1
        end
    end
end

--=======================================================================================
function dsk.saveamsdosfile(user,filename,blockdata)

    if (dsk.freeblocks == nil) then
        dsk.cat()
    end

    dsk.deletefile(filename)

    local nbrecords = (string.len(blockdata)+127)>>7 -- 
    local nbblocks = (string.len(blockdata)+1023)>>10
    blockdata = blockdata..string.rep(string.char(0),nbblocks*1024-string.len(blockdata))

    local nbfreeblocks = 0

    for num,block in pairs(dsk.freeblocks) do
        if (block == true) then
            nbfreeblocks = nbfreeblocks+1
        end
    end

    if (nbfreeblocks<nbblocks) then
        sj.error("Not enough space on the DSK")
        return false
    end

    local currentblock = 0
    local res = true
    local blockslist = {}

    for num,block in pairs(dsk.freeblocks) do
        if ((block == true)and(string.len(blockdata)>=(currentblock*1024+1))) then
            res = dsk.setblock(num,string.sub(blockdata,currentblock*1024+1,currentblock*1024+1024))
            if (res == false) then
                return false
            end
            blockslist[currentblock+1] = num
            currentblock = currentblock + 1
        end
    end

    dsk.adddirectoryentry(user,filename,nbrecords,blockslist)

    return true
end

--=======================================================================================
function dsk.save(filename,filetype,frombyte,tobyte,entryaddr)

    local data = ""
    local amsdosfilename = string.upper(filename)
    local pointpos = string.find(amsdosfilename,"%.")

    amsdosfilename = string.sub(amsdosfilename,1,pointpos-1)..string.rep(" ",9-pointpos)..string.sub(amsdosfilename,pointpos-string.len(amsdosfilename))

    for cpt = frombyte,tobyte-1,1 do
        data = data .. string.char(sj.get_byte(cpt))
    end

    local blockdata = dsk.generateheader(0,amsdosfilename,filetype,frombyte,entryaddr,string.len(data))..data

    return dsk.saveamsdosfile(0,amsdosfilename,blockdata)
end

--=======================================================================================
function dsk.saveexternalfile(externalfile,filename,filetype,frombyte,entryaddr)

    local data = ""
    local amsdosfilename = string.upper(filename)
    local pointpos = string.find(amsdosfilename,"%.")
    local datafile

    amsdosfilename = string.sub(amsdosfilename,1,pointpos-1)..string.rep(" ",9-pointpos)..string.sub(amsdosfilename,pointpos-string.len(amsdosfilename))

    datafile = io.open(externalfile, "rb")
    if(datafile==nil) then
        sj.error("File '"..filename.."' not found")
        return false
    end

    data = datafile:read("*all")

    local blockdata = dsk.generateheader(0,amsdosfilename,filetype,frombyte,entryaddr,string.len(data))..data

--    dsk.datafile:close()
--    dsk.datafile = nil

    return dsk.saveamsdosfile(0,amsdosfilename,blockdata)
end

--=======================================================================================
function dsk.savewithcustomheader(header,filename,filetype,frombyte,tobyte,entryaddr)

    local data = ""
    local amsdosfilename = string.upper(filename)
    local pointpos = string.find(amsdosfilename,"%.")

    amsdosfilename = string.sub(amsdosfilename,1,pointpos-1)..string.rep(" ",9-pointpos)..string.sub(amsdosfilename,pointpos-string.len(amsdosfilename))

    for cpt = frombyte,tobyte-1,1 do
        data = data .. string.char(sj.get_byte(cpt))
    end

    local blockdata = dsk.populateheader(header,0,amsdosfilename,filetype,frombyte,entryaddr,string.len(data))..data

    return dsk.saveamsdosfile(0,amsdosfilename,blockdata)
end


return dsk