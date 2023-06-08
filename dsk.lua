print("DSK Management tool - CheshireCat/Flush")

local dsk = {}
dsk.datafile = nil
dsk.catalog = nil
dsk.verbose = true
dsk.tracks = nil

--=======================================================================================
function dsk.read(filename)
    dsk.catalog = nil
    dsk.tracks={}
    dsk.datafile = io.open(filename, "r")
    if(dsk.datafile==nil) then
        sj.error("File '"..filename.."' not found")
        return false
    end

    header = dsk.datafile:read(34)
    if(header ~= "MV - CPCEMU Disk-File\r\nDisk-Info\r\n") then
        sj.error("The file '"..filename.."' is not a DSK file")
        return false
    end

    creator = dsk.datafile:read(14)
    dsk.tracksnumber = string.byte(dsk.datafile:read(1))
    dsk.sidesnumber = string.byte(dsk.datafile:read(1))
    dsk.tracksize = string.byte(dsk.datafile:read(1))+string.byte(dsk.datafile:read(1))*256

    if(dsk.verbose==true) then
        print("Opening file : "..filename.." [Creator:'"..creator.."'/Tracks:"..dsk.tracksnumber.."/Sides:"..dsk.sidesnumber.."/Track size:"..dsk.tracksize.."]")
    end

    dsk.datafile:seek("cur",204)

    -- Tracks reading

    dsk.tracks={}

    for cpt_tracks_sides = 0,(dsk.tracksnumber*dsk.sidesnumber)-1,1
    do
        local trackheader = dsk.datafile:read(12)
        dsk.datafile:seek("cur",4)
        local tracknum = string.byte(dsk.datafile:read(1))
        local sidenum = string.byte(dsk.datafile:read(1))

        if(dsk.verbose==true) then
            print("Track : "..tracknum.." / side : "..sidenum)
        end

        dsk.datafile:seek("cur",2)

        dsk.tracks[tracknum]={}
        dsk.tracks[tracknum][sidenum]={}

        dsk.tracks[tracknum][sidenum].sectorssize = string.byte(dsk.datafile:read(1))
        dsk.tracks[tracknum][sidenum].sectorsnumber = string.byte(dsk.datafile:read(1))
        dsk.tracks[tracknum][sidenum].gap = string.byte(dsk.datafile:read(1))
        dsk.tracks[tracknum][sidenum].filler = string.byte(dsk.datafile:read(1))

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
        end

        pos=((dsk.datafile:seek()>>8)+1)<<8
        dsk.datafile:seek("set",pos)
         
        for cpt_sectors = 0,dsk.tracks[tracknum][sidenum].sectorsnumber-1,1
        do
            dsk.tracks[tracknum][sidenum].sector[cpt_sectors].data = dsk.datafile:read(256<<(dsk.tracks[tracknum][sidenum].sector[cpt_sectors].size-1))
        end

    end

    dsk.datafile:close()
    dsk.datafile = nil

    dsk.cat()

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

    dsk.datafile = io.open(filename, "w")
    if(dsk.datafile==nil) then
        sj.error("File '"..filename.."' can't be opened for writing. Wrong path ?")
        return false
    end

    dsk.datafile:write("MV - CPCEMU Disk-File\r\nDisk-Info\r\n")
    dsk.datafile:write("DSKTool/Flush"..string.char(228))

    dsk.datafile:write(string.char(dsk.tracksnumber))
    dsk.datafile:write(string.char(dsk.sidesnumber))
    dsk.datafile:write(string.char(dsk.tracksize&255))
    dsk.datafile:write(string.char(dsk.tracksize>>8))

    dsk.datafile:write(string.rep(string.char(0),204))


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
                dsk.datafile:write(string.rep(string.char(0),2))
            end

            pos=dsk.datafile:seek()
            dsk.datafile:write(string.rep(string.char(0),(((pos>>8)+1)<<8)-pos))
    
            for cpt_sectors = 0,dsk.tracks[cpt_tracks][cpt_sides].sectorsnumber-1,1
            do
                dsk.datafile:write(dsk.tracks[cpt_tracks][cpt_sides].sector[cpt_sectors].data)
            end
        
        end
    end

    return true

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

    dsk.cat()

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
    sectornum = blocknum*2
    tracknum = math.floor(sectornum/9)
    sectorid = 0xc1+(sectornum%9)
    res = dsk.setsector(tracknum,0,sectorid,string.sub(data,1,512))

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
--    dsk.freeblocks[0] = false -- Room for the directory
--    dsk.freeblocks[1] = false
end

--=======================================================================================
function dsk.cat()
    if(dsk.tracks==nil) then
        dsk.create()
    end

    if(dsk.catalog ~= nil) then
        return
    end

    dsk.initializefreeblocks()

    dsk.catalog={}

    local directory = dsk.getsector(0,0,0x0c1)..dsk.getsector(0,0,0x0c2)..dsk.getsector(0,0,0x0c3)..dsk.getsector(0,0,0x0c4)

    local entrynum = -1

    for cpt=0,63,1 do
        entrynum = entrynum +1
        if(string.byte(string.sub(directory,cpt*32+1,cpt*32+1)) ~= 0x0E5) then
            dsk.catalog[entrynum]={}

            dsk.catalog[entrynum].key = string.sub(directory,cpt*32,cpt*32+12)
            dsk.catalog[entrynum].user = string.byte(directory,cpt*32+1,cpt*32+1)
            dsk.catalog[entrynum].filename = string.sub(directory,cpt*32+1,cpt*32+12)
            dsk.catalog[entrynum].numextension = string.byte(directory,cpt*32+13,cpt*32+13)
            dsk.catalog[entrynum].nbrecords = string.byte(directory,cpt*32+16,cpt*32+16)
            local nbblockstoread = ((dsk.catalog[entrynum].nbrecords+7)>>3)+1

            if(nbblockstoread>16) then
                nbblockstoread=16
            else
                dsk.catalog[entrynum].blocks = {}
            end

            for blocks = 1,nbblockstoread,1 do
                dsk.catalog[entrynum].blocks[blocks] = string.byte(directory,cpt*32+16+blocks,cpt*32+16+blocks)
                dsk.freeblocks[dsk.catalog[entrynum].blocks[blocks]] = false
            end
        end
    end

    if(dsk.verbose==true) then
        for num,direntry in pairs(dsk.catalog) do
            io.write(direntry.user.." "..direntry.filename.." "..direntry.nbblocks.." (")
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

    local sectorc2 = nil

    local currentsector = nil

    for num, sector in pairs(dsk.tracks[0][0].sector) do
        if (sector.id == 0x0c1) then
            currentsector = num
        else
            if (sector.id == 0x0c2) then
                sectorc2 = num
            end
        end
    end

    if ((sectorc2 == nil)or(currentsector == nil)) then
        return false
    end

    dsk.tracks[0][0].sector[currentsector].data = string.rep(string.char(0x0e5),512)
    dsk.tracks[0][0].sector[sectorc2].data = string.rep(string.char(0x0e5),512)

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
        pos = pos+1

        if(pos == 16) then
            cat = cat .. string.rep(string.char(0x0e5),512-string.len(cat))
            dsk.tracks[0][0].sector[currentsector].data = cat
            cat = ""
            currentsector = sectorc2
        end
    end

    if(pos~=0) then -- If the sector is not full, the data has not been written
        cat = cat .. string.rep(string.char(0x0e5),512-string.len(cat))
        dsk.tracks[0][0].sector[currentsector].data = cat
    end

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
-- filetype : 0 => BASIC, 1=> Protected, 2 => BINARY
-- loadaddr : Loading address
-- length   : Length of the file
function dsk.generateheader(user,filename,filetype,loadaddr,entryaddr,length)
    local header = string.char(user)
    ..string.upper(string.sub(filename.."           ",1,11))
    ..string.char(0,0,0,0,0,0,filetype,0,0,loadaddr&255,loadaddr>>8,0,length&255,length>>8,entryaddr&255,entryaddr>>8)
    ..string.rep(string.char(0),36)
    ..string.char(length&255,length>>8)
    ..string.char(0)

    checksum=0
    for cpt=1,66,1 do
        checksum = checksum + string.byte(header,cpt,cpt)
    end

    header = header..string.char(checksum&255,checksum>>8)
    .." File generated by SJASMPlus, the best Z80 assembler ! " -- Since there's room in the header...
    ..string.rep(string.char(0),59-55)

    return header
end

--=======================================================================================
function dsk.adddirectoryentry(user,filename,nbrecords,blockslist)

    local nbblocksinentry = 0
    local currentextension = 0
    local numblockslefttowrite = #blockslist
    local lastcatalogentrynbrecordswas128 = false
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
                lastcatalogentrynbrecordswas128 = true
            else
                catalogentry.nbrecords = nbrecords
            end
        end

        table.insert(catalogentry.blocks,block)
        nbblocksinentry = nbblocksinentry+1
        numblockslefttowrite = numblockslefttowrite -1

        if((nbblocksinentry == 16) or (numblockslefttowrite == 0)) then        
            table.insert(dsk.catalog,catalogentry)
            nbblocksinentry = 0
            currentextension = currentextension+1

            if ((lastcatalogentrynbrecordswas128 == true) and (numblockslefttowrite == 0)) then
                catalogentry = {}
                catalogentry.key = string.char(user)..filename
                catalogentry.user = user
                catalogentry.filename = filename
                catalogentry.numextension = currentextension
                catalogentry.blocks = {}
                catalogentry.nbrecords = 0
                table.insert(dsk.catalog,catalogentry)
                lastcatalogentrynbrecordswas128 = false
            end
        end
    end
end

--=======================================================================================
function dsk.saveamsdosfile(user,filename,filetype,loadaddr,entryaddr,data)

    if (dsk.freeblocks == nil) then
        dsk.cat()
    end

    dsk.deletefile(filename)

    local blockdata = dsk.generateheader(user,filename,filetype,loadaddr,entryaddr,string.len(data))..data

    local nbrecords = (string.len(blockdata)+127)>>7
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

    return dsk.saveamsdosfile(0,amsdosfilename,filetype,frombyte,entryaddr,data)
end


return dsk