--
-- Author: Ace
-- Date: 2014-03-23 22:04:56
--
local GameModel = class("GameModel",cc.mvc.ModelBase)

GameModel.FLASH_EVENT	= "FLASH_EVENT"
GameModel.WIN_EVENT		= "WIN_EVENT"
GameModel.LOST_EVENT	= "LOST_EVENT"
GameModel.SCORE_EVENT	= "SCORE_EVENT"
GameModel.MOVE_EVENT	= "MOVE_EVENT"
GameModel.MERGE_EVENT	= "MERGE_EVENT"
GameModel.NOMOVE_EVENT	= "NOMOVE_EVENT"
GameModel.RESTORE_EVENT	= "RESTORE_EVENT"
GameModel.ARROW_EVENT 	= "ARROW_EVENT"
GameModel.NEXT_EVENT 	= "NEXT_EVENT"

function GameModel:ctor(properties)
	self.super.ctor(self,properties)
	if GameData.map then
		self.map = GameData.map
		self.rec = GameData.rec
		self.undoCell = GameData.undoCell
		self.currScore = GameData.currScore
		self.currId = GameData.currId
		self.flag = GameData.flag
		self.maxNum = GameData.maxNum
		self.nextNum = GameData.nextNum
		self.isRestore = true
	else
		self.isRestore = false
		self.flag = math.random(2) == 1
	end
end


--重新开始游戏要刷新的数据放这里，不刷新的放在ctor中。
function GameModel:startGame()
	local rstMode
	if self.isRestore then
		self.gsUpdate = true
		self.isRestore = false
		self:showNext()
		rstMode = 2 --恢复进度
	else
		self.currId = 0
		self.currScore = 0
		self.maxNum = 4
		-- 生成模型表，注意tag是坐标绑定的，永远不变
		-- 这样无论矩阵怎么旋转，对应的目标tag不变。
		self.map = {
			{{v=0,tag=1},{v=0,tag=2},{v=0,tag=3},{v=0,tag=4}},
			{{v=0,tag=5},{v=0,tag=6},{v=0,tag=7},{v=0,tag=8}},
			{{v=0,tag=9},{v=0,tag=10},{v=0,tag=11},{v=0,tag=12}},
			{{v=0,tag=13},{v=0,tag=14},{v=0,tag=15},{v=0,tag=16}}
		}
		-- rec用于记录gameLog，目的undo。
		-- undoCell用于记录undo时最后的那个cell，防止通过undo来试图改变出子的位置或数字。
		self.rec = {} 
		self.undoCell = {}

		self.gsUpdate = false
		self:init()
		rstMode = 1 -- 新游戏
	end
	self:dispatchEvent({
		name = GameModel.RESTORE_EVENT,
		map = self.map,
		curr = self.currScore,
		rstMode = rstMode
	})
end

-- 初始产生5个cell
function GameModel:init()
	self.cell = {}
	local empty = {}
	for i=1,16 do
		empty[i] = i
	end
	local num,id,tag,idx
	for i = 1,3 do
		for _ = 1,2 do
			num = i == 2 and 4 or i
			id = self:getId()
			idx = math.random(#empty)
			tag = table.remove(empty,idx)
			self:fillMap({id=id,tag=tag,num=num})
			if i == 2 then break end
		end
	end
	self:getNextNum()
end


-- 获得下一个将出来的数字
function GameModel:getNextNum()
	local num
	local undoCnt = #self.undoCell
	if undoCnt > 0 then
		num = self.undoCell[undoCnt].num
	else
		num = math.random(3)
		if num == 2 then
			if self.maxNum <= 32 then
				num = 4
			else
				num = self:getRndNum()
			end
		else
			num = self.flag and 1 or 3
			--self.flag = not self.flag
		end
	end

	self.nextNum = num
	self:showNext()
end

-- 如果即将出来的数非2，且当前最大数字大于等于32，加权随机。
function GameModel:getRndNum()
	-- 构造加权随机表
	local t = {}
	local curNum = self.maxNum / 8
	local cnt = 1
	while curNum > 4 do
		for i = 1,cnt do
			table.insert(t,curNum)
		end
		curNum = curNum / 2
		cnt = cnt * 2
	end
	for i = 1, self.maxNum/8 - #t do
		table.insert(t,4)
	end

	local idx = math.random(#t)
	return t[idx]
end

-- 通知view显示下一个数字
function GameModel:showNext()
	self:dispatchEvent({name=GameModel.NEXT_EVENT,num=self.nextNum})
end

-- 生成id：用于给每个cell一个唯一的id，tag只能用于定位，
-- 由于move、merge和动画延迟执行等原因，getChildByTag是不可靠的。
function GameModel:getId()
	self.currId = self.currId + 1
	--用文本型id方便view采用hash表存储
	return "id"..tostring(self.currId) 
end

function GameModel:creatNewCell()
	local undoCell = table.remove(self.undoCell)
	if undoCell then  --防止通过undo改变新的cell
		for _,v in ipairs(self.empty) do
			if undoCell.tag == v then
				-- if undoCell.num < 4 then self.flag = not self.flag end
				return undoCell
			end
		end
	end

	--随机在空位表中找个位置
	local idx = math.random(#self.empty)
	local tag = self.empty[idx]
	--获得id
	local id = self:getId()
	return  {id=id,tag=tag,num=self.nextNum}
end

function GameModel:flash()
	self.cell = self:creatNewCell()
	-- 同步维护self.map表
	self:fillMap(self.cell)
	self:gameLog()
	self.currScore = self:countScore()
	if self.currScore > GameData.bestScore then
		GameData.bestScore = self.currScore
	end

	-- 分发事件，通知view显示新的cell
	self:dispatchEvent({
		name = GameModel.FLASH_EVENT,
		id = self.cell.id,
		tag = self.cell.tag,
		num = self.cell.num,
		curr=self.currScore
	})

	-- 产生下一个cell的数值
	self:getNextNum()

	-- 检查失败条件
	self:checkLost()
end

-- 递归计算分数
function GameModel:getScore(num)
	if num < 4 then
		return 0
	else
		--用一段小程序求2的次幂power
		local power = 0
		local k = num
		while k > 1 do
			k = k / 2
			power = power + 1
		end
		return num * (power - 1)
	end
end

-- 统计当前分数
function GameModel:countScore()
	local cnt,cnt1,cnt3 = 0,0,0
	for i = 1,4 do
		for j= 1,4 do
			local v = self.map[i][j].v
			if v >= 4 then
				cnt = cnt + self:getScore(v)
			else
				if v==1 then cnt1=cnt1+1 end
				if v==3 then cnt3=cnt3+1 end
			end
		end
	end
	if cnt1 < cnt3 then
		self.flag = true
	elseif cnt1 > cnt3 then
		self.flag = false
	else
		self.flag = math.random(2) == 1
	end
	return cnt
end

-- 将指定cell填入self.map表
function GameModel:fillMap(cell)
	local tag = cell.tag
	local row = math.floor((tag - 1)/4) + 1
	local col = math.mod(tag - 1, 4) + 1
	self.map[row][col].v = cell.num
	self.map[row][col].id = cell.id
end

--检查失败条件
function GameModel:checkLost()
	for i = 1,4 do
		for j = 1,4 do
			local vv = self.map[i][j].v
			if vv == 0 then return end
			if j < 4 then
				local vx = self.map[i][j+1].v
				if vv >= 4 and vv == vx or vv <4 and vv+vx==4 then
					return
				end
			end
			if i < 4 then
				local vy = self.map[i+1][j].v
				if vv >= 4 and vv == vy or vv <4 and vv+vy==4 then
					return
				end
			end
		end
	end
	self:dispatchEvent({name=GameModel.LOST_EVENT})
	for i = 1,4 do
		for j = 1,4 do
			local num = self:getScore(self.map[i][j].v)
			if num > 0 then
				self:dispatchEvent({name=GameModel.SCORE_EVENT,num=num,tag=self.map[i][j].tag})
			end
		end
	end
end

-- 矩阵变换，用于上移，行列互换
function GameModel:upMap(srcMap)
	local map = {}
	for i=1,4 do
		map[i] = {}
		for j=1,4 do
			map[i][j] = srcMap[j][   i]
		end   
	end   
	return map   
end

-- 矩阵变换，用于右移，左右互换(水平镜像)
function GameModel:rightMap(srcMap)
	local map = {}
	for i=1,4 do
		map[i] = {}
		for j=1,4 do
			map[i][j] = srcMap[i][5-j]
		end
	end
	return map
end

-- 矩阵变换，用于下移，旋转180度(中心对称)
function GameModel:downMap(srcMap)
	local map = {}
	for i=1,4 do
		map[i] = {}
		for j=1,4 do
			map[i][j] = srcMap[5-j][5-i]
		end
	end
	return map
end

-- 响应View中玩家的移动事件
function GameModel:move(eventId)
	-- 保留移动前的map、score用于undo记录
	self.oldMap = clone(self.map)
	self.oldScore = self.currScore

	--由self.map变换成对应map
	local map =	eventId == TOUCH_MOVED_UP and self:upMap(self.map)
		or eventId == TOUCH_MOVED_DOWN and self:downMap(self.map)
		or eventId == TOUCH_MOVED_RIGHT and self:rightMap(self.map)
		or self.map

	self.empty = {}
	for i=1,4 do
		--单行合并，左移算法。所以其他移动方向要变换矩阵。
		self:lineMerge(map[i])
	end

	if self.winEventParams then
		self:dispatchEvent(self.winEventParams)
		self.winEventParams = nil
	end

	--再把map变换回来,存储到self.map
	self.map =	eventId == TOUCH_MOVED_UP and self:upMap(map)
		or eventId == TOUCH_MOVED_DOWN and self:downMap(map)
		or eventId == TOUCH_MOVED_RIGHT and self:rightMap(map)
		or map

	if #self.empty > 0 then
		self:flash()
		self:dispatchEvent({name = GameModel.ARROW_EVENT,empty=self.empty,dir=eventId})
	else
		self:dispatchEvent({name = GameModel.NOMOVE_EVENT})
	end
end

-- 表内移动算法，dis为移动的距离(格子数)，用于控制View中动画时间。
function  GameModel:moveInMap(des,src)
	self:dispatchEvent({
		name=GameModel.MOVE_EVENT,
		srcId=src.id,desTag=des.tag
	})
	des.v = src.v
	des.id = src.id
	src.v = 0
	src.id = nil
end

-- 表内合并算法
function GameModel:mergeInMap(des,src)
	des.v = des.v + src.v
	des.hot = true  --设置热点，防止在同一次移动中被两次merge
	if des.v > GameData.bestCell then
		GameData.bestCell = des.v
	end
	if des.v > self.maxNum then
		self.maxNum = des.v
		self.winEventParams = {
			name=GameModel.WIN_EVENT,
			id = des.id, num=des.v
		}
	end
	self:dispatchEvent({
		name=GameModel.MERGE_EVENT,
		src=src.id,des=des.id,num=des.v
	})

	src.v = 0
	src.id = nil
end

--单行移动、合并的算法
function GameModel:lineMerge(arr)
	local update
	for cur =2,4 do
		local vv = arr[cur].v
		local vx = arr[cur-1].v
		if vv ~=0 then
			if vx == 0 then
				self:moveInMap(arr[cur-1],arr[cur])
				update = true
			elseif (vv>=4 and vv==vx) or (vv<4 and vv+vx==4) then
				self:mergeInMap(arr[cur-1],arr[cur])
				update = true
			end
		end
	end
	if update then
		table.insert(self.empty,arr[4].tag)
	end
end

function GameModel:gameLog()
	if #self.rec >= 20 then  
		--保留最后20条记录，事实上可以保留全部记录，但是意义不大，浪费内存
		table.remove(self.rec,1)
	end
	table.insert(self.rec,{
		map = self.oldMap,
		curr = self.oldScore,
		cell = self.cell,
	})
	self.gsUpdate = true
end

function GameModel:undo()
	local rec = table.remove(self.rec)
	if rec then
		self.map = clone(rec.map)
		self.currScore = rec.curr
		self:dispatchEvent({
			name = GameModel.RESTORE_EVENT, 
			map  = rec.map,
			curr = rec.curr,
			rstMode = 3 -- undo
		})
		table.insert(self.undoCell,rec.cell)
		self.nextNum = rec.cell.num
		self:showNext()
	else --can't undo
		self:dispatchEvent({name=GameModel.RESTORE_EVENT,rstMode=4})
	end
end

function GameModel:saveGameData(isSaving)
	if self.gsUpdate then
		if isSaving then
			GameData.map = self.map
			GameData.rec = self.rec
			GameData.undoCell = self.undoCell
			GameData.currScore = self.currScore
			GameData.currId = self.currId
			GameData.flag = self.flag
			GameData.maxNum = self.maxNum
			GameData.nextNum = self.nextNum
		else -- clear
			GameData.map = nil
			GameData.rec = nil
			GameData.undoCell = nil
			--其他数据占存储很少，不用清理，本身也无效
		end
		
		GameState.save(GameData)
	end
end

return GameModel