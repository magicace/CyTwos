--
-- Author: Ace
-- Date: 2014-03-25 00:17:24
--

local Auto = require("app.public.Auto")
local AutoItems = require("app.public.AutoItems")
local TouchNode = require("app.ui.TouchNode")

local GameView = class("GameView", function()
    return display.newLayer()
end)

function GameView:ctor(listener)
    self.cell = {}
    self:createScoreBoard()
    self:createBoard()
    self.listener = listener
    self.scoreMode = 1
end

-- 锁定游戏区
function GameView:lockBoard(unlock)
    self.board:setTouchEnabled(unlock)
    self.boardLocked = not unlock
    self.boardMask:setVisible(not unlock)
end

function GameView:startGame(game)
    --游戏开始，开启各种事件
    self:lockBoard(true)
    local model = app:getObject("myGameDonotNeedObj")
    --联结model和view，开启各种事件响应
    cc.EventProxy.new(model,self)
        :addEventListener(game.FLASH_EVENT, self.onFlash, self)
        :addEventListener(game.WIN_EVENT, self.onWin, self)
        :addEventListener(game.LOST_EVENT, self.onLost, self)
        :addEventListener(game.MOVE_EVENT, self.onMove, self)  
        :addEventListener(game.MERGE_EVENT, self.onMerge, self) 
        :addEventListener(game.NOMOVE_EVENT, self.onNoMove, self)
        :addEventListener(game.RESTORE_EVENT, self.onRestore, self)
        :addEventListener(game.ARROW_EVENT,self.onDir,self)
        :addEventListener(game.SCORE_EVENT,self.onScore,self)
        :addEventListener(game.NEXT_EVENT, self.onNext,self)

    self.game = game
    self:showMsg(Lang.info.guide)
end

-- 创建GameLogo、分数板、各种隐藏功能按钮
function GameView:createScoreBoard()
    local scale = (display.height - 960) /960
    local topY = display.top - 70*(1+scale)  --不同分辨率下的Y坐标
    local y

    --创建Logo标识 = Undo Button
    local logo = display.newSprite("#logo.png"):pos(100,topY):scale(0.75):addTo(self)
    self.logo = TouchNode.new(logo,handler(self,self.onLogoTouched))

    -- 下一个水晶,暂时用1.png占位 = save按钮
    local nextSpt = display.newSprite("#1.png"):pos(550,topY):scale(0.75):addTo(self)
    self.nextSpt = TouchNode.new(nextSpt,handler(self,self.onSaveTouched))
    local nextLabel = ui.newTTFLabel({
            text = Lang.title.nextCell,
            size = 24,
            align = ui.TEXT_ALIGN_CENTER,
            x = 550,
            y = topY - 90,
        })
    nextLabel = Auto.addOpacityBack(nextLabel,255):addTo(self)

    -- 最高分数板 = bestMode按钮
    local bestScoreBack = display.newScale9Sprite(
        "#vBox.png",250,topY,
        CCSize(120,80)
    ):addTo(self)
    self.bestTitle = ui.newTTFLabel({
        text=Lang.title.bestScore,
        size=24,x=60,y=58,
        align=ui.TEXT_ALIGN_CENTER
    }):addTo(bestScoreBack)
    self.bestScoreLabel = ui.newTTFLabel({
        text=tostring(GameData.bestScore),
        size=24,x=60,y=20,
        align=ui.TEXT_ALIGN_CENTER
    }):addTo(bestScoreBack)
    self.bestButton = TouchNode.new(bestScoreBack,handler(self,self.onBestTouched))

    -- Logo下的文字栏
    ui.newTTFLabel({
        text = Lang.title.text,
        color = ccc3(0,0,0),
        size=24,x=48,y=topY - 90
    }):addTo(self) 


    --创建newGame Button
    local button
    button = Auto.ttfButton(Lang.title.newgame,24,_,CCSize(120,40)):addTo(self)
    button:pos(400,topY + 20)
    self.newButton = TouchNode.new(button,handler(self,self.onNewTouched))

    --创建exit Button
    button = Auto.ttfButton(Lang.title.exit,24,_,CCSize(120,40)):addTo(self)
    button:pos(400,topY - 22)
    self.exitButton = TouchNode.new(button,handler(self,self.onExitTouched))
end

-- 创建游戏区
function GameView:createBoard()
    local items = {}
    for i=1,16 do
        items[i] = display.newSprite("#vBox1.png")
        -- items[i] = display.newScale9Sprite("#vFrame.png",0,0,CCSize(132,132))
    end
    local x = display.cx
    local y = display.height < 900 and display.cy - 60 or display.cy
    local params = {
        items = items,
        mode = 1,
        cols = 4,
        spacing = 8,
        border = 10,
        backPic = "#vBox.png",
        x = x, y = y,
    } --用autoItems将16个框按每列4个，间距10点自动排好，背景框加好。
    local board = AutoItems.create(params)
    -- 加灰度遮罩(默认隐藏，当游戏失败或达到最大8192时，锁定游戏状态时显示) 
    self.boardMask = Auto.addMask(board)
    -- 从返回的参数中获得每个格子的位置信息(贴图位置,直接可用)
    self.pos = params.pos
    -- 让board成为一个TouchNode，接受触摸事件
    self.board =  TouchNode.new(board,handler(self,self.onBoardTouched)):addTo(self)
    -- 创建一个node用于最后显示各个水晶的分数，定位。
    local size = self.board:getContentSize()
    self.scoreNode = display.newNode()
        :pos(x-size.width/2, y-size.height/2)
        :addTo(self)
end

-- NewGame按钮被touch
function GameView:onNewTouched(eventId)
    self.newButton:setColor(ccc3(255,0,0))
    if self.boardLocked or self.isBegin then 
        --如果游戏区是锁定的，说明已经lost或者win,直接开始
        self.listener(TOUCH_RESTART_EVENT)
    else --否则说明在游戏中，需要一定确认机制防止误点
        if eventId == TOUCH_PRESSED then
            --如果是长按事件(按住1秒以上)，开始新游戏
            self.listener(TOUCH_RESTART_EVENT)
        else
            self:showMsg(Lang.info.restartHint)
        end
    end
    self:performWithDelay(function ()
        self.newButton:setColor(ccc3(255,255,255))
    end, 0.5)
end

--Exit按钮被touch
function GameView:onExitTouched()
    self.exitButton:setColor(ccc3(255,0,0))
    self.listener(TOUCH_EXIT_EVENT)
    self:performWithDelay(function ()
        self.exitButton:setColor(ccc3(255,255,255))
    end, 0.5)
end

--Save按钮被touch，手动保存游戏进度，隐藏功能
function GameView:onSaveTouched(eventId)
    if self.boardLocked then return end
    if eventId == TOUCH_PRESSED then
        self.nextSpt:runAction(transition.sequence({
            CCScaleTo:create(0.15,1.1),
            CCScaleTo:create(0.1,0.75)
        })) 
        self.game:saveGameData(true)
        self:showMsg(Lang.info.saved)
    end
    --其他操作不做任何提示
end

--Best按钮被touch，切换bestMode
function GameView:onBestTouched()
    self.scoreMode = self.scoreMode + 1
    if self.scoreMode > 3 then self.scoreMode = 1 end
    self:changeScore()
end

-- Logo图标被touch，提供undo操作，隐藏功能
function GameView:onLogoTouched(eventId)
    if self.boardLocked then return end
    self.logo:runAction(transition.sequence({
        CCScaleTo:create(0.15,1.1),
        CCScaleTo:create(0.1,0.75) }))
    if eventId == TOUCH_PRESSED then
        self:performWithDelay(function ()
            self.listener(TOUCH_UNDO_EVENT)
        end, 0.5)
    else
        self:showMsg(Lang.info.undoHint)
    end
end

-- 游戏区下方的提示信息
function GameView:showMsg(text)
    if self.msgLabel then
        -- 因为后面加了深灰色背景，用setString背景宽度不会同步改变，故删除重新生成。
        self.msgLabel:removeSelf()
    end

    self.msgLabel = ui.newTTFLabel({
        text = text,
        size = 32,
        align = ui.TEXT_ALIGN_CENTER,
        x = display.cx,
        y = display.height< 900 and display.cy - 380 or display.cy - 320
    })
    -- 因为深色TTF字表现很差(毛边)，所以用黑底衬白字
    self.msgLabel = Auto.addOpacityBack(self.msgLabel):addTo(self)
end

-- 游戏区的触摸事件，如果是移动类事件回调model去计算，其他给提示。
function GameView:onBoardTouched(eventId)
    if self.boardLocked then return end
    if eventId == TOUCH_CLICKED or eventId == TOUCH_DOUBLE_CLICKED then
        self:showMsg(Lang.info.clicked)
    elseif eventId == TOUCH_PRESSED then
        self:showMsg(Lang.info.pressed)
    elseif eventId == TOUCH_MOVED_UP or eventId == TOUCH_MOVED_DOWN or eventId == TOUCH_MOVED_LEFT or eventId == TOUCH_MOVED_RIGHT then
        self.board:setTouchEnabled(false)  --防止过快的操作
        self.game:move(eventId)
        self:performWithDelay(function ()
            self.board:setTouchEnabled(true)
        end, 0.5)
    else
        -- undefine touch event
    end
end

-- 显示下一个水晶事件
function GameView:onNext(event)
    self.nextSpt:setDisplayFrame(display.newSpriteFrame(tostring(event.num)..".png"))
end

-- 刷新事件，生成新的cell
function GameView:onFlash(event)
    local tag = event.tag
    local cell = self:getCellSprite(event.num)
    cell:pos(self.pos[tag].x,self.pos[tag].y)
    --维护self.cell列表，保存这个cell的关键信息，使用hash表方便检索。
    self.cell[event.id] = {tag=tag,sprite=cell}
    --正常情况有move和merge，让这些动作先执行一段时间再延迟显示新的cell

    self.currScore = event.curr
    self:changeScore()
    cell:hide():addTo(self.board,1,tag)
    self:performWithDelay(function ()
        cell:show():fadeIn(0.5)
    end, 0.3)
end

-- 达到新的最高分数水晶。
function GameView:onWin(event)
    local cell = self.cell[event.id].sprite
    self:performWithDelay(function ()
        cell:runAction(transition.sequence({
            CCScaleTo:create(0.4,1.1),
            CCScaleTo:create(0.3,1.0)
        })) 
        cell:runAction(transition.sequence({
            CCRotateTo:create(0.35,180),
            CCRotateBy:create(0.35,180)
        }))
    end, 0.6)
    if event.num < 1024 then
        self:showMsg(Lang.info.win1)
    elseif event.num == 1024 then
        self:showMsg(Lang.info.win2)        
    elseif event.num > 1024 then 
        self:showMsg(Lang.info.win3)
    end
end

-- 失败事件，给出提示，锁定游戏区。
function GameView:onLost(event)
    self:showMsg(Lang.info.lost)
    self:lockBoard(false)
end

-- 移动事件
function GameView:onMove(event)
    local time = 0.15
    local cell = self.cell[event.srcId].sprite
    local tag = event.desTag
    cell:moveTo(time,self.pos[tag].x,self.pos[tag].y)
    cell:setTag(tag) --不重要了，可以不设置
    self.cell[event.srcId].tag = tag
    local infos = Lang.info.moved
    self:showMsg(infos[math.random(#infos)])  
end

-- merge事件
function GameView:onMerge(event)
    local src = self.cell[event.src].sprite
    local des = self.cell[event.des].sprite
    local time = 0.15
    local pos = self.pos
    local tag = self.cell[event.des].tag

    src:moveTo(time,pos[tag].x,pos[tag].y)
    src:fadeOut(0.15)   
    des:fadeOut(0.15)
    self:performWithDelay(function()
        src:removeSelf()
        self.cell[event.src] = nil
        self:changeCellNum(des, event.num)
        des:fadeIn(0.2)
        des:runAction(transition.sequence({
            CCScaleTo:create(0.15,1.1),
            CCScaleTo:create(0.1,1.0)
            })) 
    end,0.2)  
    local infos = Lang.info.merged
    self:showMsg(infos[math.random(#infos)])
    self.isBegin = false
end

-- 不能移动事件
function GameView:onNoMove(event)
    self:showMsg(Lang.info.nomoved)
end

-- 移动方向指示事件
function GameView:onDir(event)
    for _,v in ipairs(event.empty) do
        local arrow = display.newSprite("#arrow.png")
            :pos(self.pos[v].x,self.pos[v].y)
            :addTo(self.board)
        local angel = event.dir == TOUCH_MOVED_UP and 90
            or event.dir == TOUCH_MOVED_RIGHT and 180
            or event.dir == TOUCH_MOVED_DOWN  and 270 or 0
        arrow:setRotation(angel)
        arrow:fadeOut(0.5)
        self:performWithDelay(function ()
            arrow:removeSelf()
        end, 0.5)
    end
end

-- 显示分数事件
function GameView:onScore(event)
    local color = event.num > 1000 and ccc3(255,0,0)
        or event.num > 100 and ccc3(255,0,255)
        or ccc3(255,255,0)
    local label = ui.newTTFLabelWithOutline({
        text = tostring(event.num),
        color = color,
        size = 40,
        x = self.pos[event.tag].x,
        y = self.pos[event.tag].y,
        align = ui.TEXT_VALIGN_CENTER,
    }):addTo(self.scoreNode)
end

-- Restore事件
function GameView:onRestore(event)
    if event.rstMode == 1 then
        self:showMsg(Lang.info.start)
        self.isBegin = true
    elseif event.rstMode == 2 then
        self:showMsg(Lang.info.restored)
    elseif event.rstMode == 3 then
        self:showMsg(Lang.info.undoed)
    else
        self:showMsg(Lang.info.notUndo)
        return        
    end
    
    for i=1,4 do
        for j=1,4 do
            local v = event.map[i][j]
            if v.id then
                self:restoreCell(self.cell[v.id],v)
            end
        end
    end
    --删除上次flash生成的cell，找没有检查标记的就是。
    for k,v in pairs(self.cell) do
        if v.checked then
            v.checked = nil
        else
            v.sprite:removeSelf()
            self.cell[k] = nil
        end
    end
    self.currScore = event.curr
    self:changeScore()
end

-- 恢复指定单元
function GameView:restoreCell(cell,map)
    if cell then --如果在本地表中(未被合并)
        if cell.tag ~= map.tag then --如果位置不对，移动回去
            local dis = math.abs(cell.tag - map.tag)
            if dis > 3 then dis = dis/4 end
            self:onMove({srcId=map.id, desTag=map.tag, dis=dis})
        end
        self:changeCellNum(cell.sprite,map.v) -- 数字改回来
        cell.checked = true -- 设置检查标记
    else --这个id的cell已经被删除了，重新生成一个
        self:onFlash({id=map.id,tag=map.tag,num=map.v})
        self.cell[map.id].checked = true 
    end   
end

-- 改变分数板的分数
function GameView:changeScore()
    if self.scoreMode == 1 then
        self.bestTitle:setString(Lang.title.currScore)
        self.bestScoreLabel:setString(tostring(self.currScore))
    elseif self.scoreMode == 2 then
        self.bestTitle:setString(Lang.title.bestScore)
        self.bestScoreLabel:setString(tostring(GameData.bestScore))
    else
        self.bestTitle:setString(Lang.title.bestCell)
        self.bestScoreLabel:setString(tostring(GameData.bestCell))
    end
end

-- 改变单元数字(换水晶图案)
function GameView:changeCellNum(sprite,num)
    if num > 2048 then
        sprite:setDisplayFrame(display.newSpriteFrame("vBox.png"))
        self:showDigital(sprite,num)
    else
        local label = sprite:getChildByTag(10)
        if label then
            label:removeSelf()
        end
        sprite:setDisplayFrame(display.newSpriteFrame(tostring(num)..".png"))
    end
end

-- 显示水晶TTF数字(大于2048的情况)
function GameView:showDigital(sprite,num)
    local label = sprite:getChildByTag(10)
    if label then
        label:setString(tostring(num))
    else
        label = ui.newTTFLabel({
            text = tostring(num),
            size = 32,
            color = ccc3(255,128,0),
            align=ui.TEXT_ALIGN_CENTER,
            x = 59,
            y = 59,
        }):addTo(sprite,10,10)
    end
end

-- 创建水晶图案精灵
function GameView:getCellSprite(num)
    local sprite
    if num > 2048 then
        sprite = display.newSprite("#vBox.png")
        self:showDigital(sprite,num)
    else
        sprite = display.newSprite("#"..tostring(num)..".png")
    end
    return sprite
end

-- 退出游戏提示信息
function GameView:exitHint(flag) 
    if not self.exitLabel then
        self.exitLabel = ui.newTTFLabel({
            text = Lang.info.exitHint,
            size = 48,
            align = ui.TEXT_ALIGN_CENTER,
            x = display.cx,
            y = display.cy
        })

        self.exitLabel = Auto.addOpacityBack(self.exitLabel,255):addTo(self,100)
    end
    self.exitLabel:setVisible(flag)
end

function GameView:restart()
    for k,v in pairs(self.cell) do
        v.sprite:removeSelf()
        self.cell[k] = nil
    end
    --self:changeScore(0)
    self:showMsg(Lang.info.start)
    self.scoreNode:removeAllChildren()
    self:lockBoard(true)
end

return GameView