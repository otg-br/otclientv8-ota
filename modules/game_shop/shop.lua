shop = nil
transferWindow = nil
local msgWindow = nil
local browsingHistory = false
local redirectBlockReopen = false
local transferValue = 0
local months = {
	May = "05",
	Sep = "09",
	Apr = "04",
	Oct = "10",
	Mar = "03",
	Nov = "11",
	Feb = "02",
	Dec = "12",
	Jan = "01",
	Aug = "08",
	Jul = "07",
	Jun = "06"
}
local storeUrl = ""
local coinsPacketSize = 0
local CATEGORIES = {}
local HISTORY = {}
local STATUS = {}
local AD = {}
local selectedOffer = {}

function init()
	connect(g_game, {
		onGameEnd = hide,
		onStoreInit = onStoreInit,
		onStoreCategories = onStoreCategories,
		onStoreOffers = onStoreOffers,
		onStoreTransactionHistory = onStoreTransactionHistory,
		onStorePurchase = onStorePurchase,
		onStoreError = onStoreError,
		onCoinBalance = onCoinBalance,
		onDisableOffer = onDisableOffer,
		onStoreTriggerOpen = onStoreTriggerOpen,
		onRedirectToOffer = onRedirectToOffer
	})
	createShop()
	createTransferWindow()
end

function terminate()
	disconnect(g_game, {
		onGameEnd = hide,
		onStoreInit = onStoreInit,
		onStoreCategories = onStoreCategories,
		onStoreOffers = onStoreOffers,
		onStoreTransactionHistory = onStoreTransactionHistory,
		onStorePurchase = onStorePurchase,
		onStoreError = onStoreError,
		onCoinBalance = onCoinBalance,
		onDisableOffer = onDisableOffer,
		onStoreTriggerOpen = onStoreTriggerOpen,
		onRedirectToOffer = onRedirectToOffer
	})

	if shop then
		shop:destroy()

		shop = nil
	end

	if msgWindow then
		msgWindow:destroy()
	end
end

function hideclose()
	if not shop then
		return
	end

	shop:hide()
	g_keyboard.unbindKeyDown("Enter", clickSearch)
end

function hide()
	if not shop then
		return
	end

	shop:hide()
	g_keyboard.unbindKeyDown("Enter", clickSearch)
end

function show(forceFirst)
	if not shop then
		return
	end

	if g_game.getFeature(GameIngameStore) then
		g_game.openStore(0)
	end

	shop:show()
	shop:raise()
	shop:focus()
	g_keyboard.bindKeyDown("Enter", clickSearch)
	shop.categoriesContainer.searchTextEdit:setText("")

	redirectBlockReopen = false

	if forceFirst == false then
		return
	end

	local firstCategory = shop.categoriesContainer.categories:getChildByIndex(1)

	if firstCategory then
		changeCategory(shop.categoriesContainer.categories:getFirstChild(), shop.categoriesContainer.categories:getChildren())
	end

	local firstOffer = shop.offersContainer.offers:getChildByIndex(1)

	if firstOffer and not firstOffer:isFocused() then
		shop.offersContainer.offers:focusChild(firstOffer)
	end
end

function softHide()
	if not transferWindow then
		return
	end

	transferWindow:hide()
	shop:show()
end

function showTransfer()
	if not shop or not transferWindow then
		return
	end

	hide()
	transferWindow:show()
	transferWindow:raise()
	transferWindow:focus()
end

function hideTransfer()
	if not shop or not transferWindow then
		return
	end

	transferWindow:hide()
	show()
end

function toggle()
	if not shop then
		return
	end

	if shop:isVisible() then
		return hide()
	end

	show()
end

function onDisableOffer(name, offerid, reason)
	local function findOfferById(search)
		for _, innerChild in ipairs(shop.offersContainer.offers:getChildren()) do
			if innerChild.offerId == search then
				return innerChild
			end
		end

		return nil
	end

	for _, category in ipairs(CATEGORIES) do
		if category.name == name then
			for _, offer in ipairs(category.offers) do
				if offer.id == offerid then
					offer.disabledReason = reason
				end
			end
		end
	end
end

function onRedirectToOffer(id)
	local function findCategoryAndOfferByOfferId(offerId)
		for id, category in ipairs(CATEGORIES) do
			for _, offer in ipairs(category.offers) do
				if offer.id == offerId then
					return id, category
				end
			end
		end

		return nil
	end

	local categoryId, category = findCategoryAndOfferByOfferId(id)

	if categoryId == nil or category == nil then
		redirectBlockReopen = nil

		return
	end

	clearOffers()

	for _, offer in ipairs(category.offers) do
		addOffer(categoryId, offer)
	end

	local function findOfferById(search)
		for _, innerChild in ipairs(shop.offersContainer.offers:getChildren()) do
			if innerChild.offerId == search then
				return innerChild
			end
		end

		return nil
	end

	local child = findOfferById(id)

	if child ~= nil then
		onStoreTriggerOpen()
		shop.offersContainer.offers:ensureChildVisible(child)
		child:focus()

		if not redirectBlockReopen then
			toggle()
		end
	end

	redirectBlockReopen = nil
end

function createShop()
	if shop then
		return
	end
	shop = g_ui.displayUI("shop")
	shop:hide()
	shopButton = modules.client_topmenu.addRightGameToggleButton('shopButton', tr('Shop'), '/images/topbuttons/shop', toggle, false, 8)
	g_keyboard.unbindKeyDown("Enter", clickSearch)
	connect(shop.offersContainer.offers, {
		onChildFocusChange = changeOffer
	})
	connect(shop.categoriesContainer.categories, { onChildFocusChange = changeCategory })
	setBanner(nil)
end

function createTransferWindow()
	if transferWindow then
		return
	end

	transferWindow = g_ui.displayUI("transfer")

	transferWindow:hide()
end

function onStoreTriggerOpen()
	createShop()
	createTransferWindow()
end

function onStoreInit(url, coins)
	storeUrl = url

	if storeUrl:len() > 0 then
		if storeUrl:sub(storeUrl:len(), storeUrl:len()) ~= "/" then
			storeUrl = storeUrl .. "/"
		end

		storeUrl = storeUrl .. "64/"

		if storeUrl:sub(1, 4):lower() ~= "http" then
			storeUrl = "http://" .. storeUrl
		end
	end

	coinsPacketSize = coins
end

function onStoreCategories(categories)
	if not shop then
		return
	end

	local correctCategories = {}

	for i, category in ipairs(categories) do
		local image = ""

		if category.icon:len() > 0 then
			image = storeUrl .. category.icon
		end

		table.insert(correctCategories, {
			type = "image",
			outfit = 0,
			itemcount = 0,
			walking = false,
			disabledReason = "",
			count = 0,
			item = 0,
			image = image,
			name = category.name,
			offers = {}
		})
	end

	processCategories(correctCategories)
end

function onStoreOffers(categoryName, offers)
	if not shop then
		return
	end

	local updated = false

	for i, category in ipairs(CATEGORIES) do
		if category.name == categoryName then
			if #category.offers ~= #offers then
				updated = true
			end

			for i = 1, #category.offers do
				if category.offers[i].title ~= offers[i].name or category.offers[i].id ~= offers[i].id or category.offers[i].cost ~= offers[i].price or category.offers[i].disabledReason ~= offers[i].disabledReason then
					updated = true
				end
			end

			if updated then
				for offer in pairs(category.offers) do
					category.offers[offer] = nil
				end

				for i, offer in ipairs(offers) do
					local image = ""

					if offer.icon:len() > 0 then
						image = storeUrl .. offer.icon
					end

					local type = "image"
					local outfit = g_game.getLocalPlayer():getOutfit()
					outfit.type = 0

					if offer.type == 1 then
						type = "item"
					elseif offer.type == 2 then
						type = "outfit"
						outfit.type = offer.outfit
						outfit.addons = 3
					elseif offer.type == 3 then
						type = "mount"
						outfit.type = offer.mount
						outfit.addons = 0
					end

					table.insert(category.offers, {
						count = 100,
						id = offer.id,
						type = type,
						image = image,
						cost = offer.price,
						title = offer.name,
						description = offer.description,
						disabledReason = offer.disabledReason,
						walking = offer.walking,
						item = offer.item,
						itemcount = offer.count,
						outfit = outfit
					})
				end

				local categoryId = "category" .. i

				for offer in pairs(category.offers) do
					downloadOffersImage(categoryId, category.offers[offer])
				end
			end
		end
	end

	if not updated then
		return
	end

	local activeCategory = shop.categoriesContainer.categories:getFocusedChild()

	changeCategory(activeCategory, activeCategory)
end

function onStoreTransactionHistory(currentPage, hasNextPage, offers)
	if not shop then
		return
	end

	HISTORY = {}

	for i, offer in ipairs(offers) do
		local image = ""

		if offer.icon:len() > 0 then
			image = storeUrl .. offer.icon
		end

		local outfit = g_game.getLocalPlayer():getOutfit()
		outfit.type = 0
		local type = "image"

		if offer.type == 1 then
			type = "item"
		elseif offer.type == 2 then
			type = "outfit"
			outfit.type = offer.outfit
			outfit.addons = 3
		elseif offer.type == 3 then
			type = "mount"
			outfit.type = offer.mount
			outfit.addons = 0
		end

		table.insert(HISTORY, {
			disabledReason = "",
			count = 100,
			id = offer.id,
			type = type,
			image = image,
			cost = offer.price,
			title = offer.name,
			description = offer.description,
			walking = offer.walking,
			item = offer.item,
			itemcount = offer.count,
			outfit = outfit
		})
	end

	if not browsingHistory then
		return
	end

	clearHistoryEntries()

	for i, entry in ipairs(HISTORY) do
		if i % 2 == 0 then
			addHistoryEntry(entry, true)
		else
			addHistoryEntry(entry, false)
		end
	end
end

function onStorePurchase(message)
	if not shop then
		return
	end

	if not transferWindow:isVisible() then
		processMessage({
			title = "Successful shop purchase",
			msg = message
		})
	else
		processMessage({
			title = "Successfuly gifted coins",
			msg = message
		})
		softHide()
	end
end

function onStoreError(errorType, message)
	if not shop then
		return
	end

	if not transferWindow:isVisible() then
		processMessage({
			title = "Shop Error",
			msg = message
		})
	else
		processMessage({
			title = "Gift coins error",
			msg = message
		})
	end
end

function onCoinBalance(coins, transferableCoins)
	if not shop then
		return
	end

	shop.infoPanel.pointsContainer.points:setText(tr("Points:") .. " " .. coins)
	transferWindow.coinsBalance:setText(tr("Transferable Miracle Coins: ") .. coins)
	transferWindow.coinsAmount:setMaximum(coins)
end

function transferCoins()
	if not transferWindow then
		return
	end

	local amount = 0
	amount = transferWindow.coinsAmount:getValue()
	local recipient = transferWindow.recipient:getText()

	g_game.transferCoins(recipient, amount)
	transferWindow.recipient:setText("")
	transferWindow.coinsAmount:setValue(0)
end

function clearOffers()
	while shop.offersContainer.offers:getChildCount() > 0 do
		local child = shop.offersContainer.offers:getLastChild()

		shop.offersContainer.offers:destroyChildren(child)
	end
end

function clearCategories()
	CATEGORIES = {}

	clearOffers()

	while shop.categoriesContainer.categories:getChildCount() > 0 do
		local child = shop.categoriesContainer.categories:getLastChild()

		shop.categoriesContainer.categories:destroyChildren(child)
	end
end

function clearHistory()
	HISTORY = {}

	if browsingHistory then
		clearHistoryEntries()
	end
end

function addHistoryEntry(data, highlight)
	local entry = g_ui.createWidget("HistoryEntry", shop.historyPanel.historyEntries)
	local purchaseDate = formatDate(data.description)
	local title = data.title
	local cost = data.cost

	entry.date:setText(purchaseDate)

	if string.find(title, "transferred") then
		entry.description:setText(title)
	else
		entry.description:setText("Purchased " .. title)
	end

	if tonumber(cost) > 0 then
		entry.balancePanel.cost:setText("+ " .. cost)
		entry.balancePanel.cost:setColor("#008b00")
	else
		entry.balancePanel.cost:setText(cost)
	end

	if highlight then
		entry:setBackgroundColor("#474747")
	end
end

function clearHistoryEntries()
	while shop.historyPanel.historyEntries:getChildCount() > 0 do
		local child = shop.historyPanel.historyEntries:getLastChild()

		shop.historyPanel.historyEntries:destroyChildren(child)
	end
end

function processCategories(data)
	if #CATEGORIES ~= 0 then
		return
	end

	clearCategories()

	CATEGORIES = data

	for i, category in ipairs(data) do
		addCategory(category)
	end

	if not browsingHistory then
		local firstCategory = shop.categoriesContainer.categories:getChildByIndex(1)

		if firstCategory then
			firstCategory:focus()
		end
	end
end

function processHistory(data)
	if table.equal(HISTORY, data) then
		return
	end

	HISTORY = data

	if browsingHistory then
		showHistory(true)
	end
end

function processMessage(data)
	if msgWindow then
		msgWindow:destroy()
	end

	local title = tr(data.title)
	local msg = data.msg
	msgWindow = displayInfoBox(title, msg)

	function msgWindow.onDestroy(widget)
		if widget == msgWindow then
			msgWindow = nil
		end

		show(false)
	end

	msgWindow:show()
	msgWindow:raise()
	msgWindow:focus()
end

function processStatus(data)
	if table.equal(STATUS, data) then
		return
	end

	STATUS = data

	if data.ad then
		processAd(data.ad)
	end

	if data.points then
		shop.infoPanel.pointsContainer.points:setText(tr("Points:") .. " " .. data.points)
	end
end

function processAd(data)
	if table.equal(AD, data) then
		return
	end

	AD = data

	if data.image and data.image:sub(1, 4):lower() == "http" then
		HTTP.downloadImage(data.image, function (path, err)
			if err then
				g_logger.warning("HTTP error: " .. err .. " - " .. data.image)

				return
			end

			shop.banner:setHeight(shop.banner:getHeight())
			shop.banner:setImageSource(path)
			shop.banner:setImageFixedRatio(true)
			shop.banner:setImageAutoResize(true)
		end)
	elseif data.text and data.text:len() > 0 then
		shop.banner.ad:setText(data.text)
		shop.banner:setHeight(shop.banner:getHeight())
	else
		shop.banner:setHeight(0)
	end

	if data.url and data.url:sub(1, 4):lower() == "http" then
		function shop.banner.onMouseRelease()
			scheduleEvent(function ()
				g_platform.openUrl(data.url)
			end, 50)
		end
	else
		shop.adPanel.ad.onMouseRelease = nil
	end
end

function setBanner(image)
	if image == nil then
		shop.banner:setHeight(0)
	end

	shop.banner:setHeight(shop.banner:getHeight())
	shop.banner:setImageSource(image)
	shop.banner:setImageFixedRatio(true)
	shop.banner:setImageAutoResize(true)
end

function addCategory(data)
	local category = g_ui.createWidget("ShopCategoryNewImage", shop.categoriesContainer.categories)

	if data.type == "image" then
		if data.image and data.image:sub(1, 4):lower() == "http" then
			HTTP.downloadImage(data.image, function (path, err)
				if err then
					g_logger.warning("HTTP error: " .. err .. " - " .. data.image)

					return
				end

				category.image:setImageSource(path)
			end)
		else
			category.image:setImageSource(data.image)
		end
	else
		g_logger.error("Invalid shop category type: " .. tostring(data.type))
	end

	category:setId("category_" .. shop.categoriesContainer.categories:getChildCount())
	category.name:setText(data.name)
end

function clickSearch()
	if browsingHistory then
		return
	end

	redirectBlockReopen = true

	g_game.requestStoreOffers(shop.categoriesContainer.searchTextEdit:getText(), 3)
end

function showHistory(force)
	if browsingHistory and not force then
		return
	end

	if g_game.getFeature(GameIngameStore) then
		g_game.openTransactionHistory(100)
	end

	browsingHistory = true

	clearHistoryEntries()

	for i, entry in ipairs(HISTORY) do
		if i % 2 == 0 then
			addHistoryEntry(entry, true)
		else
			addHistoryEntry(entry, false)
		end
	end

	shop.transactionHistory:setVisible(false)
	shop.buttonOffers:setVisible(true)
	shop.offersContainer:setVisible(false)
	shop.historyPanel:setVisible(true)
end

function showOffers()
	shop.offersContainer:setVisible(true)
	shop.historyPanel:setVisible(false)
	shop.transactionHistory:setVisible(true)
	shop.buttonOffers:setVisible(false)

	browsingHistory = false
end

function downloadOffersImage(category, data)
	if data.image and data.image:len() > 0 then
		HTTP.downloadImage(data.image, function (path, err)
			if err then
				g_logger.warning("HTTP error: " .. err .. " - " .. data.image)

				return
			end
		end)
	end
end

function addOffer(category, data)
	local offer, creatureOffer, itemOffer, imageOffer, innerLabel = nil

	if data.type == "item" then
		if data.image and data.image:len() > 0 then
			offer = g_ui.createWidget("ShopOfferNewImage", shop.offersContainer.offers)
			imageOffer = offer.image

			if data.image and data.image:sub(1, 4):lower() == "http" then
				HTTP.downloadImage(data.image, function (path, err)
					if err then
						g_logger.warning("HTTP error: " .. err .. " - " .. data.image)

						return
					end

					if not imageOffer then
						return
					end

					imageOffer:setImageSource(path)
					imageOffer:setTooltip(path)

					local splitId = offer:getId():split("_")
					local offerId = tonumber(splitId[3])

					if offerId == 1 then
						setRightShowoffImage(path)
					end
				end)
			elseif data.image and data.image:len() > 1 then
				imageOffer:setImageSource(data.image)
				imageOffer:setTooltip(data.image)
			end
		else
			offer = g_ui.createWidget("ShopOfferNewItem", shop.offersContainer.offers)
			itemOffer = offer.item

			itemOffer:setItemId(data.item)
			itemOffer:setItemCount(data.itemcount)
			itemOffer:setShowCount(false)
		end
	elseif data.type == "outfit" then
		offer = g_ui.createWidget("ShopOfferNewCreature", shop.offersContainer.offers)
		creatureOffer = offer.creature

		creatureOffer:setOutfit(data.outfit)
		creatureOffer:setAnimate(true)
		creatureOffer:setIdleAnimate(not data.walking)

		if data.outfit.rotating then
			creatureOffer:setAutoRotating(true)
		end
	elseif data.type == "mount" then
		offer = g_ui.createWidget("ShopOfferNewCreature", shop.offersContainer.offers)
		creatureOffer = offer:recursiveGetChildById("creature")

		creatureOffer:setOutfit(data.outfit)
		creatureOffer:setAnimate(true)
		creatureOffer:setIdleAnimate(not data.walking)

		if data.outfit.rotating then
			creatureOffer:setAutoRotating(true)
		end
	elseif data.type == "image" then
		offer = g_ui.createWidget("ShopOfferNewImage", shop.offersContainer.offers)
		imageOffer = offer.image

		if data.image and data.image:sub(1, 4):lower() == "http" then
			HTTP.downloadImage(data.image, function (path, err)
				if err then
					g_logger.warning("HTTP error: " .. err .. " - " .. data.image)

					return
				end

				if not imageOffer then
					return
				end

				imageOffer:setImageSource(path)
				imageOffer:setTooltip(path)

				local splitId = offer:getId():split("_")
				local offerId = tonumber(splitId[3])

				if offerId == 1 then
					setRightShowoffImage(path)
				end
			end)
		elseif data.image and data.image:len() > 1 then
			imageOffer:setImageSource(data.image)
			imageOffer:setTooltip(data.image)
		end
	else
		g_logger.error("Invalid shop offer type: " .. tostring(data.type))

		return
	end

	offer:setId("offer_" .. category .. "_" .. shop.offersContainer.offers:getChildCount())
	offer.title:setText(data.title)
	offer:recursiveGetChildById("points"):setText(data.cost)
	offer.description:setText(data.description)

	offer.offerId = data.id

	if category ~= 0 then
		offer.onDoubleClick = buyOffer
	end
end

local scheduledOffers = {}
local startScheduleOffer = 25
local scheduleDelay = 2

function changeCategory(newCategory, children)
	if not newCategory or newCategory:isOn() then
		return
	end

	local separators = {
		"sep1",
		"sep2",
		"sep3",
		"sep4"
	}

	for _, child in pairs(children) do
		if child:isOn() then
			child:setOn(false)

			for _, sep in ipairs(separators) do
				child:getChildById(sep):setVisible(true)
			end
		end
	end

	newCategory:setOn(true)

	for _, sep in ipairs(separators) do
		newCategory:getChildById(sep):setVisible(false)
	end

	if shop.buttonOffers:isVisible() then
		showOffers()
	end

	if g_game.getFeature(GameIngameStore) then
		local serviceType = 0

		if g_game.getFeature(GameTibia12Protocol) then
			serviceType = 2
		end

		g_game.requestStoreOffers(newCategory.name:getText(), serviceType)
	end

	browsingHistory = false
	local id = tonumber(newCategory:getId():split("_")[2])

	clearOffers()

	for _, event in ipairs(scheduledOffers) do
		if event then
			removeEvent(event)

			event = nil
		end
	end

	scheduledOffers = {}

	if id ~= nil then
		for i, offer in ipairs(CATEGORIES[id].offers) do
			if startScheduleOffer < i then
				break
			end

			addOffer(id, offer)
		end
	end

	shop.offersContainer.offers:focusChild(shop.offersContainer.offers:getFirstChild())

	if id ~= nil then
		for i, offer in ipairs(CATEGORIES[id].offers) do
			if startScheduleOffer < i then
				local event = scheduleEvent(function ()
					addOffer(id, offer)
				end, scheduleDelay * (i - (startScheduleOffer - 1)))

				table.insert(scheduledOffers, event)
			end
		end
	end
end

function buyOffer(widget)
	if not widget then
		return
	end

	local split = widget:getId():split("_")

	if #split ~= 3 then
		return
	end

	local category = tonumber(split[2])
	local offer = tonumber(split[3])
	local item = CATEGORIES[category].offers[offer]

	if not item then
		return
	end

	selectedOffer = {
		category = category,
		offer = offer,
		title = item.title,
		cost = item.cost,
		id = widget.offerId
	}

	scheduleEvent(function ()
		if msgWindow then
			msgWindow:destroy()
		end

		local title = tr("Buying from shop")
		local msg = "Do you want to buy " .. item.title .. " for " .. item.cost .. " premium points?"
		msgWindow = displayGeneralBox(title, msg, {
			{
				text = tr("Yes"),
				callback = buyConfirmed
			},
			{
				text = tr("No"),
				callback = buyCanceled
			},
			anchor = AnchorHorizontalCenter
		}, buyConfirmed, buyCanceled)

		msgWindow:show()
		msgWindow:raise()
		msgWindow:focus()
		msgWindow:raise()
		hide()
	end, 50)
end

function buyConfirmed()
	msgWindow:destroy()

	msgWindow = nil

	if g_game.getFeature(GameIngameStore) and selectedOffer.id then
		local offerName = selectedOffer.title:lower()

		if string.find(offerName, "name") and string.find(offerName, "change") and modules.client_textedit then
			modules.client_textedit.singlelineEditor("", function (newName)
				if newName:len() == 0 then
					return
				end

				g_game.buyStoreOffer(selectedOffer.id, 1, newName)
			end)
		else
			g_game.buyStoreOffer(selectedOffer.id, 0, "")
		end
	end
end

function buyCanceled()
	show(false)
	msgWindow:destroy()

	msgWindow = nil
	selectedOffer = {}
end

function changeOffer(list, focusedChild, unfocusedChild, reason)
	if focusedChild then
		local showOffPanel = shop:recursiveGetChildById("offerShowoff")
		local offerType = focusedChild:getLastChild()

		showOffPanel:destroyChildren()

		if offerType:getId() == "item" then
			local widget = g_ui.createWidget("ShopOfferShowoffItem", showOffPanel)

			widget.title:setText(focusedChild.title:getText())
			widget.item:setItemId(focusedChild.item:getItemId())
			widget.item:setItemCount(focusedChild.item:getItemCount())
			widget.item:setShowCount(false)
			widget.offerInfo.pointsContainer.points:setText(focusedChild.offerInfo.pointsContainer.points:getText())

			local descriptionWidget = shop:recursiveGetChildById("offerShowoffDescription")
			local descriptionText = focusedChild.description:getText()
			local formattedDescription = descriptionText:gsub("\\n", "\n")

			descriptionWidget:setText(formattedDescription)
		elseif offerType:getId() == "creature" then
			local widget = g_ui.createWidget("ShopOfferShowoffCreature", showOffPanel)

			widget.title:setText(focusedChild.title:getText())
			widget.offerInfo.pointsContainer.points:setText(focusedChild.offerInfo.pointsContainer.points:getText())
			widget.creature:setOutfit(focusedChild.creature:getOutfit())

			local descriptionWidget = shop:recursiveGetChildById("offerShowoffDescription")
			local descriptionText = focusedChild.description:getText()
			local formattedDescription = descriptionText:gsub("\\n", "\n")

			descriptionWidget:setText(formattedDescription)
		elseif offerType:getId() == "image" then
			local widget = g_ui.createWidget("ShopOfferShowoffImage", showOffPanel)
			local titleText = focusedChild.title:getText()

			if titleText == "Change Name" or titleText == "Recovery Key" or titleText == "Character Account Transfer" then
				function widget.buttonBuy.onClick()
					g_platform.openUrl("https://miracle74.com/?subtopic=accountmanagement")
				end
			end

			widget.title:setText(titleText)
			widget.offerInfo.pointsContainer.points:setText(focusedChild.offerInfo.pointsContainer.points:getText())
			widget.image:setImageSource(focusedChild.image:getTooltip())

			local descriptionWidget = shop:recursiveGetChildById("offerShowoffDescription")
			local descriptionText = focusedChild.description:getText()
			local formattedDescription = descriptionText:gsub("\\n", "\n")

			descriptionWidget:setText(formattedDescription)
		end
	end
end

function buttonBuyNow()
	local offer = shop.offersContainer.offers:getFocusedChild()

	if offer then
		buyOffer(offer)
	end
end

function formatDate(date)
	local month_str, day, year, time = date:match("Bought on: (%a+) (%d+) (%d+) (%d+:%d+:%d+)")
	local month = months[month_str]
	local formatted_date = string.format("%s-%s-%02d %s", year, month, day, time)

	return formatted_date
end

function setRightShowoffImage(imagePath)
	local showOffWidget = shop:recursiveGetChildById("shopOfferShowoffImage")

	if not showOffWidget then
		return
	end

	showOffWidget.image:setImageSource(imagePath)
end
