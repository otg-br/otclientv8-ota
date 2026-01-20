local window
local listCategory
local listProduct
local coinBalance
local acceptWindow
local transferPointsWindow
local storeUrl = ""
local WEBSITE_GETCOINS = ""
local IMAGES_URL = ""
if Services and Services.website then
    IMAGES_URL = Services.website.."/store"
end
local debugMode = false
local localImageMode = true
local changeNamePrice
local PLAYER_GENDER = 0
local storeCategories = {}
local storeOffers = {}


local function formatNumbers(number)
	local ret = number
	while true do  
		ret, k = string.gsub(ret, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then
			break
		end
	end
return ret
end

function init()	
	g_ui.importStyle('assets/ui')
	g_ui.importStyle('assets/acceptwindow')

	
	connect(g_game, { 
		onGameEnd = onCloseStore,
		onStoreInit = onStoreInit,
		onStoreCategories = onStoreCategories,
		onStoreOffers = onStoreOffers,
		onCoinBalance = onCoinBalance,
		onStorePurchase = onStorePurchase,
		onStoreError = onStoreError
	})
    
	window = g_ui.displayUI('assets/store')
      
	listCategory = window:recursiveGetChildById('listCategory')
	listProduct  = window:recursiveGetChildById('listProduct')
	coinBalance  = window:recursiveGetChildById('lblCoins')
	transferHistory  = window:recursiveGetChildById('transferHistory')
	
	transferPointsWindow = g_ui.displayUI('assets/transferpoints')
	transferPointsWindow:setVisible(false)
	
	changeNameWindow = g_ui.displayUI('assets/changename')
	changeNameWindow:setVisible(false)
	
	transferHistory:setVisible(false)
	
	listProduct.onChildFocusChange = function(self, focusedChild)
		if (not focusedChild) then return end
		local product = focusedChild.product
		local panel = window:getChildById('panelItem')
		
		if product.type == 1 or product.type == 2 then
			panel:getChildById('lblName'):setText("x"..product.count.." "..product.name)
		else
			panel:getChildById('lblName'):setText(product.name)
		end
		
		local productImage = product.image[1]
		-- Logic for gender specific images if available (legacy support, though primarily we use one icon now)
		if ((product.type == 3) or (product.type == 13)) and product.image[2] then
			if PLAYER_GENDER == 0 then
				productImage = product.image[2]
			end
		end
		
		if productImage and productImage:len() > 0 then
			if localImageMode then
				panel:getChildById('image'):setImageSource("images/64/"..productImage)
			else
				local imageUrl = storeUrl .. productImage
				HTTP.downloadImage(imageUrl, function(path, err) 
					if not err and path then
						panel:getChildById('image'):setImageSource(path)
					end
				end)
			end
		else
            panel:getChildById('image'):setImageSource("")
        end
		
		panel:getChildById('lblPrice'):setText(formatNumbers(product.price))
		panel:getChildById('lblDescription'):setText(product.description)
		if (getCoinsBalance() < product.price) then
			panel:getChildById('lblPrice'):setColor("#d33c3c")
			panel:getChildById('btnBuy'):disable()
		else
			panel:getChildById('lblPrice'):setColor("white")
			panel:getChildById('btnBuy'):enable()
		end
		
		panel:getChildById('btnBuy').onClick = function(widget)
			if acceptWindow then
				return true
			end
		
			local acceptFunc = function()
				local unformatted = coinBalance:getText():gsub(',', '')
				local balanceInfo = tonumber(unformatted)
				if balanceInfo >= product.price then
					if product.name == "Character Name Change" then
						changeName(product.price)
					else
						-- Use native bytes protocol to buy
						if g_game.getFeature(GameIngameStore) then
							g_game.buyStoreOffer(product.id, 0, "")
						end
					end
					
					if acceptWindow then
						acceptWindow:destroy()
						acceptWindow = nil
					end
				else
					displayErrorBox(window:getText(), tr("You don't have enough coins"))
					acceptWindow:destroy()
					acceptWindow = nil
				end
			end
		
			local cancelFunc = function() acceptWindow:destroy() acceptWindow = nil end
			acceptWindow = displayGeneralBox(
			tr('Confirmation of Purchase'), 'Do you want to buy the product "Buy '..product.name..'"?', { 
				{text=tr('Buy'), callback=acceptFunc},
				{text=tr('Cancel'), callback=cancelFunc},
				anchor=AnchorHorizontalCenter 
			}, acceptFunc, cancelFunc)
		end
	end  

  shopButton = modules.client_topmenu.addRightGameToggleButton('shopButton', tr('Shop'), '/images/topbuttons/shop', toggle, false, 8)

end

function terminate()
	disconnect(g_game, { 
		onGameEnd = onCloseStore,
		onStoreInit = onStoreInit,
		onStoreCategories = onStoreCategories,
		onStoreOffers = onStoreOffers,
		onCoinBalance = onCoinBalance,
		onStorePurchase = onStorePurchase,
		onStoreError = onStoreError
	})
	
	window:destroy()
end

function getCoinsWebsite()
	if WEBSITE_GETCOINS ~= "" then
		g_platform.openUrl(WEBSITE_GETCOINS)
	else
		sendMessageBox("Error", "No data for store URL.")
	end
end

function getCoinsBalance()
	local unformatted = coinBalance:getText():gsub(',', '')
	local balanceInfo = tonumber(unformatted)
return balanceInfo
end

function createHistoryEntries(buffer)
	-- Clearing the history
	while transferHistory:getChildCount() > 0 do
		local child = transferHistory:getLastChild()
		transferHistory:destroyChildren(child)
	end
	
	local data = buffer[1]
	-- Filling it
	for i = 1, #data do
		local row = g_ui.createWidget('HistoryEntry', transferHistory)	  
		row.index = i
		row:getChildById('historyDate'):setText(data[i].date)
		row:getChildById('historyDescription'):setText(data[i].description)
		row:getChildById('historyBalance'):setText(data[i].balance)
		
		if tonumber(row:getChildById('historyBalance'):getText()) < 0 then
			row:getChildById('historyBalance'):setColor("#d33c3c")
		else
			row:getChildById('historyBalance'):setMarginLeft(151)
			row:getChildById('historyBalance'):setColor("#00ff00")
		end
		
		
		if (i > 1) then
			row:setMarginTop(24 + ((i-1) * 15))
		end
		
		if (i % 2 == 0) then
			row:setBackgroundColor("#414141")
		end
	end
end

-- Native bytes protocol callbacks
function onStoreInit(url, coins)
	storeUrl = url or ""
	if storeUrl:len() > 0 then
		if storeUrl:sub(storeUrl:len(), storeUrl:len()) ~= "/" then
			storeUrl = storeUrl .. "/"
		end
		storeUrl = storeUrl .. "64/"
	end
end

function onStoreCategories(categories)
	if not window then return end
	
	clearCategories()
	storeCategories = categories
	
	for i, category in ipairs(categories) do
		local cat = g_ui.createWidget('MenuCategoryStore', listCategory)
		cat.index = i
		cat.categoryName = category.name
		
		if category.icon and category.icon:len() > 0 then
			local iconUrl = storeUrl .. category.icon
			HTTP.downloadImage(iconUrl, function(path, err)
				if not err and path then
					cat:setIcon(path)
				end
			end)
		end
		
		cat:setText(tr(category.name))
		
		cat.onClick = function(self)
			-- Request offers for this category
			if g_game.getFeature(GameIngameStore) then
				local serviceType = 0
				g_game.requestStoreOffers(self.categoryName, serviceType)
			end
			
			if transferHistory:isVisible() then
				transferHistory:setVisible(false)
			end
		end
	end
	
	-- Auto-select first category
	if listCategory:getChildCount() > 0 then
		listCategory:focusChild(listCategory:getFirstChild())
		listCategory:getFirstChild().onClick(listCategory:getFirstChild())
	end
end

function onStoreOffers(categoryName, offers)
	if not window then return end
	
	listProduct:destroyChildren()
	storeOffers[categoryName] = offers
	
	for i, offer in ipairs(offers) do
		local row = g_ui.createWidget('RowStore', listProduct)
		row.product = {
			id = offer.id,
			name = offer.name,
			price = offer.price,
			count = offer.count or 1,
			description = offer.description or "",
			type = offer.type or 0,
			image = {offer.icon or ""},
			sexId = offer.id
		}
		
		local displayName = offer.name
		if offer.count and offer.count > 1 then
			displayName = "x" .. offer.count .. " " .. offer.name
		end
		
		row:getChildById('lblName'):setText(displayName)
		row:getChildById('lblName'):setTextAlign(AlignCenter)
		row:getChildById('lblName'):setMarginRight(10)
		row:getChildById('lblPrice'):setText(formatNumbers(offer.price))
		
		if getCoinsBalance() < offer.price then
			row:getChildById('lblPrice'):setColor("#d33c3c")
		end
		
		-- Load image from local folder
		if offer.icon and offer.icon:len() > 0 then
			if localImageMode then
				row:getChildById('image'):setImageSource("images/64/" .. offer.icon)
			else
				local imageUrl = storeUrl .. offer.icon
				HTTP.downloadImage(imageUrl, function(path, err)
					if not err and path then
						row:getChildById('image'):setImageSource(path)
					end
				end)
			end
		end
	end
	
	if listProduct:getChildCount() > 0 then
		listProduct:focusChild(listProduct:getFirstChild())
	end
end

function onCoinBalance(coins, transferableCoins)
    local points = tonumber(coins) or 0
    local transferPoints = tonumber(transferableCoins) or 0
    
    local total = points + transferPoints
    
    if coinBalance then
        coinBalance:setText(formatNumbers(total))
    end
end
_G.onCoinBalance = onCoinBalance


function onStorePurchase(message)
	sendMessageBox("Purchase Successful", message)
end

function onStoreError(errorType, message)
	sendMessageBox("Store Error", message)
end

function toggleTransferHistory()
	if transferHistory:isVisible() then
		transferHistory:setVisible(false)
	else
		transferHistory:setVisible(true)
		listCategory:getFocusedChild():focus(false)
		if g_game.getFeature(GameIngameStore) then
			g_game.openTransactionHistory(26)
		end
	end
end

-- Keep for backwards compatibility
function updatePlayerSex(data)
	PLAYER_GENDER = data.sex or 0
end

function changeStoreUrl(url)
	storeUrl = url or ""
end

function changeWebsiteUrl(url)
	WEBSITE_GETCOINS = url or ""
end

function changeImagesUrl(url)
	IMAGES_URL = url
end

function getStoreCategories(buffer)
	clearCategories()
	
	local storeIndex = buffer[1]
	for i, store in ipairs(storeIndex) do
		local category = g_ui.createWidget('MenuCategoryStore', listCategory)
			category.index  = i
			
			if localImageMode then
				category:setIcon("images/"..store.icon)
			else
				local iconURL = IMAGES_URL.."/"..store.icon..".png"
				HTTP.downloadImage(iconURL, function(path, err) 
					if err and debugMode then 
						g_logger.warning("HTTP error: " .. err)
					return end
					
					if path then
						category:setIcon(path)
					end
				end)
			end
			
			category:setText(tr(storeIndex[i].name))
	
		category.onClick = function(self)	
			listProduct:destroyChildren()

			local storeProducts = store.offers
			if storeProducts then
				for i, product in ipairs(storeProducts) do
					if tostring(self.index) == product.category_id then
						local row = g_ui.createWidget('RowStore', listProduct)
						row.store = store
						row.product = product		  
						row.type = product.type		
						
						if product.type == 1 or product.type == 2 then
							row:getChildById('lblName'):setText("x"..product.count.." "..product.name)
						else
							row:getChildById('lblName'):setText(product.name)
						end
					
							row:getChildById('lblName'):setTextAlign(AlignCenter)
							row:getChildById('lblName'):setMarginRight(10)
						row:getChildById('lblPrice'):setText(formatNumbers(product.price))
						
						if getCoinsBalance() < product.price then
							row:getChildById('lblPrice'):setColor("#d33c3c")
						end
						
						local productImage = product.image[1]
						if (product.type == 3) or (product.type == 13) then
							if PLAYER_GENDER == 0 then
								productImage = product.image[2]
							end
						end
						
						if productImage then
							if localImageMode then
								row:getChildById('image'):setImageSource("images/"..productImage)
							else
								local imageURL = IMAGES_URL.."/"..productImage..".png"
								HTTP.downloadImage(imageURL, function(path, err) 
									if err and debugMode then 
										g_logger.warning("HTTP error: " .. err)
									return end
									
									if (path ~= nil) then
										row:getChildById('image'):setImageSource(path)
									end
								end)
							end
						end
					end
				end
			end
			
			if transferHistory:isVisible() then
				transferHistory:setVisible(false)
			end
			
			listProduct:focusChild(listProduct:getFirstChild())  
		end
	end
	
	listCategory:focusChild(listCategory:getFirstChild())  
	listCategory:getFirstChild().onClick(listCategory:getFirstChild())
	storeDataSent = true
end

function downloadImages()

end

function clearOffers()
	while listProduct:getChildCount() > 0 do
		local child = listProduct:getLastChild()
		listProduct:destroyChildren(child)
	end
end

function clearCategories()
	clearOffers()
	while listCategory:getChildCount() > 0 do
		local child = listCategory:getLastChild()
		listCategory:destroyChildren(child)
	end
end

function onCloseStore()
	window:hide()
	transferPointsWindow:setVisible(false)
	
	if acceptWindow then
		acceptWindow:destroy()
		acceptWindow = nil
	end
end

function openStoreWindow()
	window:setVisible(true)
end

function transferPoints()
	window:hide()
	
	if getCoinsBalance() <= 0 then
		return sendMessageBox("Gifting not possible", "You don't have enough coins to gift.", true)
	end
	
	local value = transferPointsWindow:getChildById('transferPointsValue')
	value:setText(tr('0'))

	local balanceInfo = window:getChildById('lblCoins'):getText()
	local balance = transferPointsWindow:getChildById('coinBalance2')
	balance:setText(formatNumbers(balanceInfo))
	transferPointsWindow:setVisible(true)
	
	transferPointsWindow:focus()
	transferPointsWindow:raise()
	
	if acceptWindow then
		acceptWindow:destroy()
		acceptWindow = nil
	end
end

function changeName(price)
	local newName = changeNameWindow:getChildById('transferPointsText')
	newName:setText(tr(''))
	
	changeNameWindow:setVisible(true)
	changeNameWindow:focus()
	changeNameWindow:raise()
	
	-- Internal Variable
	changeNamePrice = price
	
	if acceptWindow then
		acceptWindow:destroy()
		acceptWindow = nil
	end
end

function changeNameAccept()
	local newName = changeNameWindow:getChildById('transferPointsText')
	-- Use native bytes protocol for name change
	if g_game.getFeature(GameIngameStore) then
		-- Name change offer ID needs to be found/stored when selecting the offer
		g_game.buyStoreOffer(0, 1, newName:getText()) -- productType 1 = name change
	end
	
	changeNameWindow:setVisible(false)
	newName:setText("")
	window:setVisible(true)
end

function changeNameCancel()
	local newName = changeNameWindow:getChildById('transferPointsText')
	newName:setText("")
				
	changeNameWindow:setVisible(false)
	window:setVisible(true)
end

function transferAccept()
	local unformatted = coinBalance:getText():gsub(',', '')
	local balanceInfo = tonumber(unformatted)
	local nickname = transferPointsWindow:getChildById('transferPointsText')
	local value = transferPointsWindow:getChildById('transferPointsValue')
	if not value then return true end
	
	transferPointsWindow:getChildById('buttonOk').onClick = function(widget)
		local transferableAmountSet = tonumber(value:getText())
		if transferableAmountSet > balanceInfo then
			displayErrorBox(window:getText(), tr("You don't have enough coins"))
			return true
		end
		
		if tonumber(transferableAmountSet) <= 0 then
			return true
		end
		
		if acceptWindow then
			return true
		end
		
		local cancelFunc = function() acceptWindow:destroy() acceptWindow = nil end
		local acceptFunc = function()
			if balanceInfo >= transferableAmountSet then
				-- Use native bytes protocol to transfer coins
				if g_game.getFeature(GameIngameStore) then
					g_game.transferCoins(nickname:getText(), transferableAmountSet)
				end
				
				-- Destroy accept window
				acceptWindow:destroy()
				acceptWindow = nil
				
				-- Cleaning
				nickname:setText("")
				value:setText("0")
				
				-- Removing the window
				transferPointsWindow:setVisible(false)
				window:setVisible(true)
			else
				displayErrorBox(window:getText(), tr("You don't have enough coins"))
				acceptWindow:destroy()
				acceptWindow = nil
			end
		end
		
		acceptWindow = displayGeneralBox(tr('Gift Tibia Coins'), tr("Do you want to transfer "..transferableAmountSet.." to "..nickname:getText().."?"),
		{ { text=tr('Yes'), callback=acceptFunc },
		{ text=tr('Cancel'), callback=cancelFunc },
		anchor=AnchorHorizontalCenter }, acceptFunc, cancelFunc)
			
	end
end

function transferCancel()
	local nickname = transferPointsWindow:getChildById('transferPointsText')
	local value = transferPointsWindow:getChildById('transferPointsValue')
	nickname:setText("")
	value:setText("0")
				
	transferPointsWindow:setVisible(false)
	transferHistory:setVisible(false)
	window:setVisible(true)
end

function sendMessageBox(title, message, specialCallback)
	local okFunc = function() messageBox:destroy() messageBox = nil if specialCallback then openStoreWindow() end end
	messageBox = displayGeneralBox(title, message, {{text=tr('Ok'), callback=okFunc}, anchor=AnchorHorizontalCenter}, okFunc)
end
function show(category,item)
window:hide()
toggle()
scheduleEvent(function() 
for i,child in pairs(listCategory:getChildren()) do
if string.find(child:getText(),category) then
	child.onClick(child)
		end

end
end,50)
scheduleEvent(function() 
for i,child in pairs(listProduct:getChildren()) do
if string.find(child:getChildById('lblName'):getText(),item) then
		child:focus(true)
		end

end
end,100)

end
function toggle()
	if window:isVisible() then
		window:hide()
	else
		-- Use native bytes protocol to open store
		if g_game.getFeature(GameIngameStore) then
			g_game.openStore(0)
		end
		
		-- The rest
		window:show()
		window:raise()
		window:focus()
	end
end
