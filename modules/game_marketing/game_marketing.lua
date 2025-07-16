market_area = {}

market_player = ''

function init()
	load()

	connect(g_game, {onGameStart = onGameStart})
	connect(g_game, {onGameEnd = onGameEnd})

	ProtocolGame.registerExtendedJSONOpcode(96, function(protocol, opcode, buffer) onReceiveInfo(buffer) end)

	connect(rootWidget, {onMousePress = onMousePress})

	mouseGrabber = g_ui.createWidget('UIWidget', rootWidget)
	mouseGrabber:setVisible(false)
	mouseGrabber:setFocusable(false)
	mouseGrabber.onMouseRelease = selectObject
end

function terminate()
	disconnect(g_game, {onGameStart = onGameStart})
	disconnect(g_game, {onGameEnd = onGameEnd})

	ProtocolGame.unregisterExtendedJSONOpcode(96)

	gameMarketing:destroy()
end

function onGameStart()
	g_game.getProtocolGame():sendExtendedJSONOpcode(96, {action = "RefreshPos"})
end

function onGameEnd()
	gameMarketing:destroy()
	load()
end

function load()
	gameMarketing = g_ui.displayUI('game_marketing')
	gameMarketing:hide()
end

function toggle()
	if gameMarketing:isVisible() then
		gameMarketing:hide()
		gameMarketing:destroy()
		load()
	else
		gameMarketing:show()
	end
end

function sendMarket(name)
	market_player = name
	g_game.getProtocolGame():sendExtendedJSONOpcode(96, {action = "Refresh", market = market_player})
end

function onReceiveInfo(buffer)
	if buffer.action == "Refresh" then

		gameMarketing:show()

		for _, item in pairs(gameMarketing.marketWindow:getChildren()) do
			item:destroy()
		end

		for _, item in pairs(buffer.data) do
			if item.id > 0 then
				local addItem = g_ui.createWidget("newItem", gameMarketing.marketWindow)
				addItem:setId(item.uid)
				addItem.name = item.name:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest:lower() end)
				local newItem = Item.create(item.id, item.quant)
				newItem:setShowCount(1)
				print(item.quant)
				addItem:setItem(newItem)
				addItem.quant = item.quant
				addItem.price = item.price
				addItem.look = item.look
				addItem:setItemRarity(item.rarity)
				addItem:updateItemRarity()
			end
		end

		if market_player == g_game.getLocalPlayer():getName() then
			gameMarketing:getChildById('actionButton'):setEnabled(true)
			gameMarketing.itemAmountBar:setVisible(false)
			gameMarketing.itemAmount:setVisible(false)
			gameMarketing.itemAmountCount:setVisible(false)
			gameMarketing.startButton:setVisible(true)
			gameMarketing.descButton:setVisible(true)
		else
			gameMarketing:getChildById('actionButton'):setEnabled(false)
			gameMarketing.itemAmountBar:setVisible(true)
			gameMarketing.itemAmount:setVisible(true)
			gameMarketing.itemAmountCount:setVisible(true)
			gameMarketing.startButton:setVisible(false)
			gameMarketing.descButton:setVisible(false)
		end

		if buffer.oppened then
			gameMarketing.oppenedButton:setVisible(true)
			gameMarketing.actionButton:setVisible(false)
			gameMarketing.cancelButton:setVisible(false)
		end

	elseif buffer.action == "msg" then

		gameMarketing:recursiveGetChildById('message'):setVisible(true)
		gameMarketing:recursiveGetChildById('msgLabel'):setText(buffer.data.msg)

	elseif buffer.action == "coins" then

		local function formatMoney(money)
			if money >= 10^6 then
				return string.format("%.2fkk", money / 10^6)
			elseif money >= 10^3 then
				return string.format("%.2fk", money / 10^3)
			else
				return tostring(money)
			end
		end

		gameMarketing:recursiveGetChildById('goldWindow'):setText(formatMoney(buffer.data.gold))

	elseif buffer.action == "Finish" then
		if market_player == buffer.market then
			if gameMarketing:isVisible() then
				toggle()
			end
		end

	elseif buffer.action == "marketpos" then
		market_area = buffer.marketpos

	end
end

function selectObject(widget, mousePosition, mouseButton)
	if mouseButton == MouseLeftButton then
		local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
		if clickedWidget and clickedWidget:getStyle().__class == "UIItem" then
			local item = clickedWidget:getItem()
			if item then
				if item:getPosition().x ~= 65535 then
					return
				end

				gameMarketing.itemBKG.id = clickedWidget:getItemId()
				gameMarketing.itemBKG.pos = item:getPosition().z
				gameMarketing.itemBKG.quant = clickedWidget:getItemCountOrSubType()
				gameMarketing.itemBKG:setItem(Item.create(clickedWidget:getItemId(), clickedWidget:getItemCountOrSubType()))

				gameMarketing.itemBKG.rarity = item:getCustomAttribute(29305)
				-- gameMarketing.itemBKG:setItemRarity(item:getCustomAttribute(29305))
				-- gameMarketing.itemBKG:updateItemRarity()

				gameMarketing.itemAmountBar:setMaximum(clickedWidget:getItemCountOrSubType())
				gameMarketing.itemAmountBar:setValue(clickedWidget:getItemCountOrSubType())
				gameMarketing.itemAmountCount:setText(clickedWidget:getItemCountOrSubType())


				if market_player == g_game.getLocalPlayer():getName() then
					gameMarketing:getChildById('actionButton'):setText("Add")
				else
					gameMarketing:getChildById('actionButton'):setText("Buy")
				end

				gameMarketing.cancelButton:setEnabled(true)
			end
		end
	end

	g_mouse.popCursor('target')
	widget:ungrabMouse()
end

function onMousePress(self, mousePos, button)
	local self = gameMarketing:recursiveGetChildByPos(mousePos, false)

	if self then
		if button == 1 then

			if self:getStyle().__class == "UIItem" then
				if self:getId() ~= "itemBKG" then
					gameMarketing:getChildById('itemName'):setText(self.name)
					gameMarketing:getChildById('itemPrice'):setText("Price (un): "..(tonumber(self.price) or 1).."")
					gameMarketing:getChildById('priceWindow'):setText(tonumber(self.price) or 1)
					gameMarketing:getChildById('itemAmountPrice'):setText("Price (total): "..((tonumber(self.price) or 1)*(tonumber(self.quant) or 1)).."")
					gameMarketing:getChildById('itemAmountBar'):setMaximum(tonumber(self.quant) or 1)
					gameMarketing:getChildById('itemAmountBar'):setValue(tonumber(self.quant) or 1)
					gameMarketing:getChildById('itemBKG').uid = self:getId()
					gameMarketing:getChildById('itemBKG'):setItem(Item.create(self:getItemId(), self:getItemCountOrSubType()))
					gameMarketing:getChildById('itemLook'):getChildById('lookLabel'):setText(self.look)
					gameMarketing:getChildById('priceWindow'):setVisible(false)
					gameMarketing:getChildById('cancelButton'):setEnabled(true)
					gameMarketing:getChildById('actionButton'):setEnabled(true)
					if market_player == g_game.getLocalPlayer():getName() then
						gameMarketing:getChildById('actionButton'):setText("Remove")
						gameMarketing.itemAmountBar:setVisible(false)
						gameMarketing.itemAmount:setVisible(false)
						gameMarketing.itemAmountCount:setVisible(false)
					else
						gameMarketing:getChildById('actionButton'):setText("Buy")
						gameMarketing.itemAmountBar:setVisible(true)
						gameMarketing.itemAmount:setVisible(true)
						gameMarketing.itemAmountCount:setVisible(true)
					end
				end
			end

		elseif button == 2 then

			scheduleEvent(function()
				if g_game.getProtocolGame() then
					g_game.getProtocolGame():sendExtendedJSONOpcode(96, {action = "Open", data = {market = market_player, uid = self:getId()}})
				end
			end, 100)

		end
	end
end

function actionButton(action)
	if action == "Select" then
		mouseGrabber:grabMouse()
		g_mouse.pushCursor('target')
	elseif action == "Add" then
		local addItem = {
			id = tonumber(gameMarketing.itemBKG.id),
			pos = tonumber(gameMarketing.itemBKG.pos),
			quant = tonumber(gameMarketing.itemBKG.quant),
			price = tonumber(gameMarketing.priceWindow:getText()),
			rarity = tonumber(gameMarketing.itemBKG.rarity)
		}
		g_game.getProtocolGame():sendExtendedJSONOpcode(96, {action = action, market = market_player, data = addItem})
		cancelButton()
	elseif action == "Remove" then
		local removeItem = {
			uid = tonumber(gameMarketing.itemBKG.uid)
		}
		g_game.getProtocolGame():sendExtendedJSONOpcode(96, {action = action, market = market_player, data = removeItem})
		cancelButton()
	elseif action == "Buy" then
		gameMarketing.buyWindow:show()
	end
end

function cancelButton()
	gameMarketing.itemBKG.id = -1
	gameMarketing.itemBKG.pos = -1
	gameMarketing.itemBKG.quant = -1
	gameMarketing.itemBKG:setItem(Item.create(-1, -1))

	gameMarketing.itemAmountBar:setMaximum(1)
	gameMarketing.itemAmountBar:setValue(1)
	gameMarketing.itemAmountCount:setText(1)

	gameMarketing.priceWindow:setText(1)
	gameMarketing.priceWindow:setVisible(true)

	gameMarketing:getChildById('itemLook'):getChildById('lookLabel'):setText()

	gameMarketing.actionButton:setText("Select")
	if market_player == g_game.getLocalPlayer():getName() then
		gameMarketing:getChildById('actionButton'):setEnabled(true)
		gameMarketing.itemAmountBar:setVisible(false)
		gameMarketing.itemAmount:setVisible(false)
		gameMarketing.itemAmountCount:setVisible(false)
	else
		gameMarketing:getChildById('actionButton'):setEnabled(false)
		gameMarketing.itemAmountBar:setVisible(true)
		gameMarketing.itemAmount:setVisible(true)
		gameMarketing.itemAmountCount:setVisible(true)
	end

	gameMarketing.cancelButton:setEnabled(false)
end

function startButton()
	g_game.getProtocolGame():sendExtendedJSONOpcode(96, {action = "Start", description = gameMarketing.descWindow.descEdit:getText()})
	gameMarketing:getChildById('messageStart'):hide()
end

function oppenedButton(self)
	sendMarket(market_player, true)
	self:hide()
	gameMarketing.actionButton:setVisible(true)
	gameMarketing.cancelButton:setVisible(true)
end

function buyButton()
	local buyItem = {
		uid = tonumber(gameMarketing.itemBKG.uid),
		quant = tonumber(gameMarketing.itemAmountBar:getValue())
	}
	g_game.getProtocolGame():sendExtendedJSONOpcode(96, {action = "Buy", market = market_player, data = buyItem})
	gameMarketing.buyWindow:hide()
	cancelButton()
end