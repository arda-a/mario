--[[
    GD50
    Super Mario Bros. Remake

    -- LevelMaker Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu
]]

LevelMaker = Class{}

function LevelMaker.generate(width, height)
    local currentLevelWidth = width
    local tiles = {}
    local entities = {}
    local objects = {}

    local tileID = TILE_ID_GROUND
    
    -- whether we should draw our tiles with toppers
    local topper = true
    local tileset = math.random(20)
    local topperset = math.random(20)

    -- insert blank tables into tiles for later access
    for x = 1, height do
        table.insert(tiles, {})
    end

    -- lock and key
    keyVariant = math.random(#KEYS_AND_LOCKS)

    local keyPosition = math.random(width - 5)
    local lockPosition = math.random(width - 5)
    keyTaken = false

    -- loop until they spawn in seperate positions
    while lockPosition - keyPosition < 10 and lockPosition - keyPosition > -10 do
        keyPosition = math.random(width - 5)
    end

    -- column by column generation instead of row; sometimes better for platformers
    for x = 1, width do
        local tileID = TILE_ID_EMPTY
        
        -- lay out the empty space
        for y = 1, 6 do
            table.insert(tiles[y],
                Tile(x, y, tileID, nil, tileset, topperset))
        end

        -- chance to just be emptiness (cannot be empty on key or lock positions)
        if x < 5 and x + 5 < width and keyPosition ~= x and lockPosition ~= x and math.random(7) == 1 then
            for y = 7, height do
                table.insert(tiles[y],
                    Tile(x, y, tileID, nil, tileset, topperset))
            end
        else
            tileID = TILE_ID_GROUND

            local blockHeight = 4

            for y = 7, height do
                table.insert(tiles[y],
                    Tile(x, y, tileID, y == 7 and topper or nil, tileset, topperset))
            end

            -- the flag position should be empty
            if x + 5 > width then
                goto continue
            end

            -- chance to generate a pillar
            if math.random(8) == 1 then
                blockHeight = 2
                
                -- chance to generate bush on pillar
                if math.random(8) == 1 then
                    table.insert(objects,
                        GameObject {
                            texture = 'bushes',
                            x = (x - 1) * TILE_SIZE,
                            y = (4 - 1) * TILE_SIZE,
                            width = 16,
                            height = 16,
                            
                            -- select random frame from bush_ids whitelist, then random row for variance
                            frame = BUSH_IDS[math.random(#BUSH_IDS)] + (math.random(4) - 1) * 7
                        }
                    )
                end
                
                -- pillar tiles
                tiles[5][x] = Tile(x, 5, tileID, topper, tileset, topperset)
                tiles[6][x] = Tile(x, 6, tileID, nil, tileset, topperset)
                tiles[7][x].topper = nil
            
            -- chance to generate bushes
            elseif math.random(8) == 1 then
                table.insert(objects,
                    GameObject {
                        texture = 'bushes',
                        x = (x - 1) * TILE_SIZE,
                        y = (6 - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,
                        frame = BUSH_IDS[math.random(#BUSH_IDS)] + (math.random(4) - 1) * 7,
                        collidable = false
                    }
                )
            end

            -- chance to spawn key or lock
            if x == keyPosition then
                table.insert(objects, createKey(x, blockHeight))
            elseif x == lockBlockPosition then
                table.insert(objects, createLock(x, blockHeight, objects))

            -- chance to spawn a block
            elseif math.random(10) == 1 then
                table.insert(objects,

                    -- jump block
                    GameObject {
                        texture = 'jump-blocks',
                        x = (x - 1) * TILE_SIZE,
                        y = (blockHeight - 1) * TILE_SIZE,
                        width = 16,
                        height = 16,

                        -- make it a random variant
                        frame = math.random(#JUMP_BLOCKS),
                        collidable = true,
                        hit = false,
                        solid = true,

                        -- collision function takes itself
                        onCollide = function(obj)

                            -- spawn a gem if we haven't already hit the block
                            if not obj.hit then

                                -- chance to spawn gem, not guaranteed
                                if math.random(5) == 1 then

                                    -- maintain reference so we can set it to nil
                                    local gem = GameObject {
                                        texture = 'gems',
                                        x = (x - 1) * TILE_SIZE,
                                        y = (blockHeight - 1) * TILE_SIZE - 4,
                                        width = 16,
                                        height = 16,
                                        frame = math.random(#GEMS),
                                        collidable = true,
                                        consumable = true,
                                        solid = false,

                                        -- gem has its own function to add to the player's score
                                        onConsume = function(player, object)
                                            gSounds['pickup']:play()
                                            player.score = player.score + 100
                                        end
                                    }
                                    
                                    -- make the gem move up from the block and play a sound
                                    Timer.tween(0.1, {
                                        [gem] = {y = (blockHeight - 2) * TILE_SIZE}
                                    })
                                    gSounds['powerup-reveal']:play()

                                    table.insert(objects, gem)
                                end

                                obj.hit = true
                            end

                            gSounds['empty-block']:play()
                        end
                    }
                )
            end
        end

        ::continue::
    end

    local map = TileMap(width, height)
    map.tiles = tiles
    
    return GameLevel(entities, objects, map)
end

function createKey(x, blockHeight)
    return GameObject 
    {
        texture = 'keys-and-locks',
        width = 16,
        height = 16,
        x = (x - 1) * TILE_SIZE,
        y = (blockHeight - 1) * TILE_SIZE,

        -- random variant
        frame = keyVariant,
        hit = false,
        solid = false,
        consumable = true,
        collidable = true,

        onConsume = function(obj)
            if not obj.hit then
                gSounds['powerup-reveal']:play()
                obj.hit = true
                keyTaken = true
            end
        end
    }
end

function createLock(x, blockHeight, objects)
    return GameObject {
        texture = 'keys-and-locks',
        x = (x - 1) * TILE_SIZE,
        y = (blockHeight - 1) * TILE_SIZE,
        width = 16,
        height = 16,

        frame = 4 + keyVariant,
        hit = false,
        solid = true,
        collidable = true,
        consumable = false,

        onCollide = function(obj)           
            gSounds['powerup-reveal']:play()
            for k, object in pairs(objects) do
                if keyTaken and object == obj then
                    table.remove(objects, k)
                    table.insert(objects, createRod(currentLevelWidth - 2, 4, objects))
                    table.insert(objects, createFlag(currentLevelWidth - 2, 4, objects))
                end
            end
        end
    }
end

function createFlag(x, blockHeight)
    return GameObject {
        texture = 'flags',
        x = (x - 1) * TILE_SIZE + 8,
        y = (blockHeight - 1) * TILE_SIZE,
        width = 16,
        height = 16,

        frame = 7,
        solid = false,
        collidable = false
    }
end

function createRod(x, blockHeight)
    return GameObject {
        texture = 'rods',
        x = (x - 1) * TILE_SIZE,
        y = (blockHeight - 1) * TILE_SIZE,
        width = 16,
        height = 64,

        frame = math.random(1,6),
        hit = false,
        solid = false,
        collidable = true,
        consumable = true,

        onCollide = function(obj)           
            gSounds['powerup-reveal']:play()
            return true
        end,

        onConsume = function(player, obj)
            gStateMachine:change('play', { width = currentLevelWidth + 20, score = player.score })
        end
    }
end