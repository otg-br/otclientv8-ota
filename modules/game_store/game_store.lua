local DONATION_URL = nil

local categories = {}
local offers = {}
local history = {}

local gameStoreWindow = nil
local selected = nil
local selectedOffer = nil
local changeNameWindow = nil
local gameStoreButton = nil
local msgWindow = nil
local transferWindow = nil

local premiumPoints = 0
local premiumSecondPoints = -1

local CATEGORY_NONE = -1
local CATEGORY_PREMIUM = 0
local CATEGORY_ITEM = 1
local CATEGORY_BLESSING = 2
local CATEGORY_OUTFIT = 3
local CATEGORY_MOUNT = 4
local CATEGORY_EXTRAS = 5

local searchResultCategoryId = "Search Results"

local storeUrl = ""
local useHttpImages = false

-- Variables for server communication 
local CATEGORIES = {}
local HISTORY = {}
local STATUS = {}
local AD = {}
local selectedOffer = {}
local browsingHistory = false

function init()
  connect( g_game, {
      onGameStart = create,
      onGameEnd = destroy,
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

  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect( g_game, {
      onGameStart = create,
      onGameEnd = destroy,
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

  destroy()
end

-- Server communication functions
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
  useHttpImages = true
end

function onStoreCategories(categories)
  if not gameStoreWindow then
    return
  end

  -- Clear existing categories first
  clearCategories()
  
  local correctCategories = {}
  for i, category in ipairs(categories) do
    local image = ""
    if category.icon and category.icon:len() > 0 then
      image = storeUrl .. category.icon
    end
    
    table.insert(correctCategories, {
      type = "image",
      image = image,
      name = category.name,
      offers = {}
    })
  end
  
  processCategories(correctCategories)
end

function onStoreOffers(categoryName, serverOffers)
  if not gameStoreWindow then
    return
  end

  -- Store offers in the offers array for this category
  offers[categoryName] = {}

  for i, offer in ipairs(serverOffers) do
    -- Convert server offer format to our format
    local image = ""
    if offer.icon and offer.icon:len() > 0 then
      image = storeUrl .. offer.icon
    end
    
    local processedOffer = {
      name = offer.name,
      id = offer.id,
      price = offer.price,
      isSecondPrice = false, -- Can be extended for different coin types
      count = offer.count or 1,
      description = offer.description or "",
      categoryId = getCategoryIdFromType(offer.type),
      image = image,
      type = offer.type or "item",
      itemtype = offer.itemtype,
      charges = offer.charges,
      male = offer.male,
      female = offer.female,
      addon = offer.addon,
      blessid = offer.blessid,
      items = offer.items
    }
    
    table.insert(offers[categoryName], processedOffer)
  end

  -- Update CATEGORIES array for compatibility
  local updated = false
  for i, category in ipairs(CATEGORIES) do
    if category.name == categoryName then
      if #category.offers ~= #serverOffers then
        updated = true
      end
      for i = 1, #category.offers do
        if category.offers[i].title ~= serverOffers[i].name or category.offers[i].id ~= serverOffers[i].id or category.offers[i].cost ~= serverOffers[i].price then
          updated = true
        end
      end
      if updated then
        for offer in pairs(category.offers) do
          category.offers[offer] = nil
        end
        for i, offer in ipairs(serverOffers) do
          local image = ""
          if offer.icon:len() > 0 then
            image = storeUrl .. offer.icon
          end
          table.insert(category.offers, {
            id = offer.id,
            type = "image",
            image = image,
            cost = offer.price,
            title = offer.name,
            description = offer.description
          })
        end
      end
    end
  end

  -- Show offers if this category is currently selected
  local categoriesList = gameStoreWindow:getChildById("categoriesList")
  if categoriesList then
    local activeCategory = categoriesList:getFocusedChild()
    if activeCategory then
      local nameWidget = activeCategory:getChildById("name")
      if nameWidget then
        local activeCategoryName = nameWidget:getText()
        if activeCategoryName == categoryName then
          showOffers(categoryName)
        end
      end
    else
      -- Try to show offers anyway if we have them
      if offers[categoryName] and #offers[categoryName] > 0 then
        showOffers(categoryName)
      end
    end
  end
end

function onStoreTransactionHistory(currentPage, hasNextPage, offers)
  if not gameStoreWindow then
    return
  end

  HISTORY = {}
  for i, offer in ipairs(offers) do
    local image = ""
    if offer.icon:len() > 0 then
      image = storeUrl .. offer.icon
    end
    table.insert(HISTORY, {
      id = offer.id,
      type = "image",
      image = image,
      cost = offer.price,
      title = offer.name,
      description = offer.description
    })
  end

  if not browsingHistory then
    return
  end

  updateHistory()
end

function onStorePurchase(message)
  if not gameStoreWindow then
    return
  end

  if not transferWindow:isVisible() then
    processMessage({title = "Successful shop purchase", msg = message})
  else
    processMessage({title = "Successfully gifted coins", msg = message})
    hideTransferWindow()
  end
end

function onStoreError(errorType, message)
  if not gameStoreWindow then
    return
  end

  if not transferWindow:isVisible() then
    processMessage({title = "Shop Error", msg = message})
  else
    processMessage({title = "Gift coins error", msg = message})
  end
end

function onCoinBalance(coins, transferableCoins)
  if not gameStoreWindow then
    return
  end

  premiumPoints = tonumber(coins)
  premiumSecondPoints = tonumber(transferableCoins)
  
  local balanceWidget = gameStoreWindow:getChildById("balance")
  if balanceWidget then
    local pointsWidget = balanceWidget:getChildById("value")
    if pointsWidget then
      pointsWidget:setText(comma_value(premiumPoints))
    end
  end
  
  local balanceSecondWidget = gameStoreWindow:getChildById("balanceSecond")
  if balanceSecondWidget then
    if premiumSecondPoints and premiumSecondPoints > 0 then
      local valueWidget = balanceSecondWidget:getChildById("value")
      if valueWidget then
        valueWidget:setText(comma_value(premiumSecondPoints))
      end
      balanceSecondWidget:show()
    else
      balanceSecondWidget:hide()
    end
  end
end

function onDisableOffer(name, offerid, reason)
  -- Handle disabled offers
end

function onStoreTriggerOpen()
  create()
end

function onRedirectToOffer(id)
  -- Handle redirect to specific offer
end

function processCategories(data)
  -- Always process categories when received from server
  clearCategories()
  CATEGORIES = data

  for i, category in ipairs(data) do
    addCategory(category)
  end

  if not browsingHistory then
    local categoriesList = gameStoreWindow:getChildById("categoriesList")
    if categoriesList then
      local firstCategory = categoriesList:getChildByIndex(1)
      if firstCategory then
        firstCategory:focus()
        -- Trigger selection manually
        local button = firstCategory:getChildById("button")
        if button then
          select(button)
        end
      end
    end
  end
end

function processMessage(data)
  if msgWindow then
    msgWindow:destroy()
  end

  local title = tr(data.title)
  local msg = data.msg
  msgWindow = displayInfoBox(title, msg)
  msgWindow:show()
  msgWindow:raise()
  msgWindow:focus()
end

function clearCategories()
  CATEGORIES = {}
  clearOffers()
  
  -- Reset selected to prevent nil reference errors
  selected = nil
  
  local categoriesList = gameStoreWindow:getChildById("categoriesList")
  if categoriesList then
    while categoriesList:getChildCount() > 0 do
      local child = categoriesList:getLastChild()
      categoriesList:destroyChildren(child)
    end
  end
end

function clearOffers()
  local offersPanel = gameStoreWindow:getChildById("offers")
  if not offersPanel then
    return
  end
  
  local offersList = offersPanel:getChildById("offersList")
  if not offersList then
    return
  end
  
  while offersList:getChildCount() > 0 do
    local child = offersList:getLastChild()
    offersList:destroyChildren(child)
  end
end

function downloadImage(url, callback)
  if not useHttpImages or not url or url:len() == 0 then
    if callback then
      callback(nil, "No URL provided")
    end
    return
  end

  local fullUrl = url
  if url:sub(1, 4):lower() ~= "http" then
    fullUrl = storeUrl .. url
  end

  HTTP.downloadImage(fullUrl, function(path, err)
    if err then
      if callback then
        callback(nil, err)
      end
      return
    end
    if callback then
      callback(path, nil)
    end
  end)
end

function create()
  if gameStoreWindow then
    return
  end
  
  local success, result = pcall(function()
    return g_ui.displayUI("game_store")
  end)
  
  if not success then
    return
  end
  
  gameStoreWindow = result
  if not gameStoreWindow then
    return
  end
  
  gameStoreWindow:hide()

  gameStoreButton = modules.client_topmenu.addRightGameToggleButton('gameStoreButton', tr('Store'), '/images/topbuttons/shop', toggle, false, 8)

  createTransferWindow()
end

function destroy()
  if gameStoreButton then
    gameStoreButton:destroy()
    gameStoreButton = nil
  end

  if gameStoreWindow then
    gameStoreWindow:destroy()
    gameStoreWindow = nil
  end

  if msgWindow then
    msgWindow:destroy()
    msgWindow = nil
  end

  if changeNameWindow then
    changeNameWindow:destroy()
    changeNameWindow = nil
  end

  if transferWindow then
    transferWindow:destroy()
    transferWindow = nil
  end
  
  -- Clear all data when game ends
  selected = nil
  selectedOffer = nil
  CATEGORIES = {}
  offers = {}
  history = {}
  browsingHistory = false
  premiumPoints = 0
  premiumSecondPoints = -1
end

function hideTransferWindow()
  if transferWindow then
    transferWindow:hide()
  end
end

function show()
  hideTransferWindow()
  if not gameStoreWindow or not gameStoreButton then
    return
  end
  
  hideHistory()
  gameStoreWindow:show()
  gameStoreWindow:raise()
  gameStoreWindow:focus()
  
  -- Clear existing data and request fresh data from server
  clearCategories()
  clearOffers()
  
  -- Request store data from server when opening
  if g_game.getFeature(GameIngameStore) then
    g_game.openStore(0)
  end
  
  -- Auto-select first category if available after data is loaded
  scheduleEvent(function()
    if gameStoreWindow then
      local categoriesList = gameStoreWindow:getChildById("categoriesList")
      if categoriesList and categoriesList:getChildCount() > 0 then
        local firstCategory = categoriesList:getChildByIndex(1)
        if firstCategory then
          firstCategory:focus()
          local button = firstCategory:getChildById("button")
          if button then
            select(button)
          end
        end
      end
    end
  end, 200)
end

function hide()
  hideTransferWindow()
  if gameStoreWindow then
    gameStoreWindow:hide()
  end
end

function showHistory()
  if not gameStoreWindow then
    return
  end
  
  deselect()
  local offersPanel = gameStoreWindow:getChildById("offers")
  if offersPanel then
    offersPanel:hide()
  end
  local historyPanel = gameStoreWindow:getChildById("history")
  if historyPanel then
    historyPanel:show()
  end
  browsingHistory = true
  
  -- Request transaction history from server
  if g_game.getFeature(GameIngameStore) then
    g_game.openTransactionHistory(100)
  end
end

function hideHistory()
  if not gameStoreWindow then
    return
  end
  
  local offersPanel = gameStoreWindow:getChildById("offers")
  if offersPanel then
    offersPanel:show()
  end
  
  local historyPanel = gameStoreWindow:getChildById("history")
  if historyPanel then
    historyPanel:hide()
  end
  
  browsingHistory = false
end

local entriesPerPage = 26
local currentPage = 1
local totalPages = 1

function updateHistory()
  local historyPanel = gameStoreWindow:getChildById("history")
  if not historyPanel then
    return
  end
  
  local historyList = historyPanel:getChildById("list")
  if not historyList then
    return
  end
  
  historyList:destroyChildren()

  local index = ((currentPage - 1) * entriesPerPage) + 1
  for i = index, math.min(#HISTORY, index + entriesPerPage - 1) do
    local widget = g_ui.createWidget("HistoryWidget", historyList)
    local dateWidget = widget:getChildById("date")
    if dateWidget then
      dateWidget:setText(HISTORY[i].date or "Unknown")
    end
    
    local priceWidget = widget:getChildById("price")
    if priceWidget then
      priceWidget:setText((HISTORY[i].cost > 0 and "+" or "") .. comma_value(HISTORY[i].cost))
      priceWidget:setOn(HISTORY[i].cost > 0)
    end
    
    local coinWidget = widget:getChildById("coin")
    if coinWidget then
      coinWidget:setOn(false)
    end

    local descriptionWidget = widget:getChildById("description")
    if descriptionWidget then
      descriptionWidget:setText(HISTORY[i].title)
    end
  end

  local pageLabel = historyPanel:getChildById("pageLabel")
  if pageLabel then
    pageLabel:setText("Page " .. currentPage .. "/" .. totalPages)
  end
end

function prevPage()
  if currentPage == 1 then
    return true
  end

  currentPage = currentPage - 1

  local historyPanel = gameStoreWindow:getChildById("history")
  updateHistory()
  
  if historyPanel then
    local nextPageButton = historyPanel:getChildById("nextPageButton")
    if nextPageButton then
      nextPageButton:setVisible(currentPage < totalPages)
    end
    
    local prevPageButton = historyPanel:getChildById("prevPageButton")
    if prevPageButton then
      prevPageButton:setVisible(currentPage > 1)
    end
  end
end

function nextPage()
  if currentPage == totalPages then
    return true
  end

  currentPage = currentPage + 1

  local historyPanel = gameStoreWindow:getChildById("history")
  updateHistory()

  if historyPanel then
    local nextPageButton = historyPanel:getChildById("nextPageButton")
    if nextPageButton then
      nextPageButton:setVisible(currentPage < totalPages)
    end
    
    local prevPageButton = historyPanel:getChildById("prevPageButton")
    if prevPageButton then
      prevPageButton:setVisible(currentPage > 1)
    end
  end
end

function deselect()
  if selected then
    selected:getChildById("button"):setChecked(false)
    local arrow = selected:getChildById("selectArrow")
    if arrow then
      arrow:hide()
    end

    if not selected:getChildById("subCategories") then
      selected = selected:getParent():getParent()
      if selected then
        local expandArrow = selected:getChildById("expandArrow")
        if expandArrow then
          expandArrow:show()
        end
      end
    end

    if selected then
      selected:setHeight(22)
      local subCategories = selected:getChildById("subCategories")
      if subCategories then
        subCategories:hide()
      end
    end
  end
end

function comma_value(n)
  local left, num, right = string.match(n, "^([^%d]*%d)(%d*)(.-)$")
  return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

function buyPoints()
  g_platform.openUrl(DONATION_URL)
end

function addCategory(data)
  local categoriesList = gameStoreWindow:getChildById("categoriesList")
  local category = g_ui.createWidget("ShopCategory", categoriesList)

  category:setId(data.name)
  
  -- Support for HTTP images in categories
  if data.image and data.image:len() > 0 then
    if data.image:sub(1, 4):lower() == "http" then
      HTTP.downloadImage(data.image, function(path, err)
        if err then
          return
        end
        
        local image = category:getChildById("image")
        if image and image.setImageSource then
          image:setImageSource(path)
        end
      end)
    else
      local image = category:getChildById("image")
      if image and image.setImageSource then
        image:setImageSource(data.image)
      end
    end
  end
  
  local nameWidget = category:getChildById("name")
  if nameWidget then
    nameWidget:setText(data.name)
  end
end

function select(self, ignoreSearch)
  hideHistory()
  if not ignoreSearch then
    eraseSearchResults()
  end

  local selfParent = self:getParent()
  if not selfParent then
    return
  end
  
  local panel = selfParent:getChildById("subCategories")
  if panel then
    deselect()
    selected = selfParent

    if panel:getChildCount() > 0 then
      panel:show()
      selfParent:setHeight((panel:getChildCount() + 1) * 22)
      local expandArrow = selfParent:getChildById("expandArrow")
      if expandArrow then
        expandArrow:hide()
      end
      local firstChild = panel:getChildren()[1]
      if firstChild then
        local button = firstChild:getChildById("button")
        if button then
          select(button)
        end
      end
    else
      self:setChecked(true)
    end
  else
    if selected then
      local button = selected:getChildById("button")
      if button then
        button:setChecked(false)
      end

      local arrow = selected:getChildById("selectArrow")
      if arrow then
        arrow:hide()
      end
    end

    selected = selfParent

    self:setChecked(true)
    local selectArrow = selfParent:getChildById("selectArrow")
    if selectArrow then
      selectArrow:show()
    end
  end

  local nameWidget = selfParent:getChildById("name")
  if not nameWidget then
    return
  end
  
  local categoryName = nameWidget:getText()
  
  showOffers(categoryName)
  
  -- Request offers for this category from server
  if g_game.getFeature(GameIngameStore) then
    local serviceType = 0
    if g_game.getFeature(GameTibia12Protocol) then
      serviceType = 2
    end
    
    g_game.requestStoreOffers(categoryName, serviceType)
  end
end

function selectOffer(self)
  if selectedOffer then
    if selectedOffer.setChecked then
      selectedOffer:setChecked(false)
    end
  end

  if self and self.setChecked then
    self:setChecked(true)
  end
  selectedOffer = self

  updateDescription(self)
end

function showOffers(id)
  if not offers[id] then
    return
  end
  
  local offersCache = offers[id]
  
  if not gameStoreWindow then
    return
  end

  local offersPanel = gameStoreWindow:getChildById("offers")
  local offersList = offersPanel:getChildById("offersList")
  
  offersList:destroyChildren()

  for i = 1, #offersCache do
    local widget = g_ui.createWidget("OfferWidget", offersList)
    local priceWidget = widget:getChildById("price")
    priceWidget:getChildById("coin"):setOn(offersCache[i].isSecondPrice)
    priceWidget:getChildById("value"):setText(comma_value(offersCache[i].price))

    widget:getChildById("name"):setText(offersCache[i].name)
    widget:getChildById("count"):setText(offersCache[i].count .. "x")
    widget:setId(offersCache[i].name)
    widget.data = offersCache[i]
    widget.categoryId = id

    -- Check if this offer has an image (either string ID or has image URL)
    local hasImage = offersCache[i].image and offersCache[i].image:len() > 0
    
    if hasImage then
      local imagePanel = widget:getChildById("imagePanel")
      local image = widget:getChildById("image")
      
      if imagePanel and image then
        imagePanel:show()
        
        if offersCache[i].image:sub(1, 4):lower() == "http" then
          HTTP.downloadImage(offersCache[i].image, function(path, err)
            if err then
              image:setImageSource("/images/store/" .. tostring(offersCache[i].id))
              return
            end
            image:setImageSource(path)
          end)
        else
          image:setImageSource(offersCache[i].image)
        end
      end
    end
    
    -- Handle numeric ID offers (items, outfits, mounts)
    if type(offersCache[i].id) == "number" then
      local categoryId = offersCache[i].categoryId
      widget.offerCategoryId = categoryId
      if categoryId == CATEGORY_ITEM then
        local item = widget:getChildById("item")
        item:show()
        item:setItemId(offersCache[i].id)
      elseif categoryId == CATEGORY_OUTFIT then
        local outfit = widget:getChildById("outfit")
        local currentOutfit = g_game.getLocalPlayer():getOutfit()
        currentOutfit.type = offersCache[i].id
        outfit:show()
        outfit:setOutfit(currentOutfit)
      elseif categoryId == CATEGORY_MOUNT then
        local mount = widget:getChildById("mount")
        mount:show()
        mount:setOutfit({ type = offersCache[i].id })
      end
    end
    
    if i == 1 then
      scheduleEvent(function()
        if widget and widget.setChecked then
          selectOffer(widget)
        end
      end, 50)
    end
  end
end

function updateDescription(self)
  if not self or not self.data then
    return
  end

  local offersPanel = gameStoreWindow:getChildById("offers")
  if not offersPanel then
    return
  end
  
  local offerDetails = offersPanel:getChildById("offerDetails")
  if not offerDetails then
    return
  end
  
  offerDetails:show()
  
  local nameWidget = offerDetails:getChildById("name")
  if nameWidget then
    nameWidget:setText(self.data.name)
  end

  local descriptionPanel = offerDetails:getChildById("description")
  if descriptionPanel then
    local widget = descriptionPanel:getChildren()[1]
    if not widget then
      widget = g_ui.createWidget("OfferDescripionLabel", descriptionPanel)
    end

    local description = ""
    if categories[self.categoryId] then
      description = categories[self.categoryId].description
    end
    if not description or description == "" then
      description = self.data.description or ""
    end

    if widget then
      widget:setText(description)
    end
  end

  local buyButton = offerDetails:getChildById("buyButton")
  local priceWidget = offerDetails:getChildById("price")
  local additionalBuyButton = offerDetails:getChildById("additionalBuyButton")
  local additionalPriceWidget = offerDetails:getChildById("additionalPrice")
  
  if priceWidget then
    priceWidget:setOn(self.data.isSecondPrice or false)
    priceWidget:setText(comma_value(self.data.price or 0))
  end

  local globalPoints = (self.data.isSecondPrice and premiumSecondPoints) or premiumPoints
  if priceWidget then
    priceWidget:setEnabled((self.data.price or 0) <= globalPoints)
  end
  if buyButton then
    buyButton:setEnabled((self.data.price or 0) <= globalPoints)
  end

  if self.additionalPriceValue and self.additionalCountValue then
    if buyButton then
      buyButton:setText("Buy " .. (self.data.count or 1))
    end

    if additionalPriceWidget then
      additionalPriceWidget:setEnabled(self.additionalPriceValue <= globalPoints)
    end
    if additionalBuyButton then
      additionalBuyButton:setText("Buy " .. self.additionalCountValue)
      additionalBuyButton:show()
      additionalBuyButton:setEnabled(self.additionalPriceValue <= globalPoints)
      additionalBuyButton.price = self.additionalPriceValue
      additionalBuyButton.count = self.additionalCountValue
    end
    if buyButton then
      buyButton.secondPrice = self.data.secondPrice
      buyButton.price = self.data.price
      buyButton.count = self.data.count
    end

    if additionalPriceWidget then
      additionalPriceWidget:setOn(self.data.isSecondPrice or false)
      additionalPriceWidget:setText(comma_value(self.additionalPriceValue))
      additionalPriceWidget:show()
    end
  else
    if additionalBuyButton then
      additionalBuyButton:hide()
    end

    if buyButton then
      buyButton.secondPrice = nil
      buyButton.price = nil
      buyButton.count = nil
      buyButton:setText("Buy")
    end
    if additionalPriceWidget then
      additionalPriceWidget:hide()
    end
  end

  -- Handle image display
  local currentOutfit = g_game.getLocalPlayer():getOutfit()
  local imagePanel = offerDetails:getChildById("imagePanel")
  local image = nil
  local item = nil
  local outfit = nil
  local mount = nil
  
  if imagePanel then
    image = imagePanel:getChildById("image")
    item = imagePanel:getChildById("item")
    outfit = imagePanel:getChildById("outfit")
    mount = imagePanel:getChildById("mount")
  end
  
  if imagePanel then imagePanel:hide() end
  if image then image:hide() end
  if item then item:hide() end
  if outfit then outfit:hide() end
  if mount then mount:hide() end
  
  -- Check if this offer has an image (same logic as showOffers)
  local hasImage = self.data.image and self.data.image:len() > 0
  
  if hasImage then
    if imagePanel and image then
      imagePanel:show()
      image:show()
      if self.data.image:sub(1, 4):lower() == "http" then
        HTTP.downloadImage(self.data.image, function(path, err)
          if err then
            image:setImageSource("/images/store/" .. tostring(self.data.id))
            return
          end
          image:setImageSource(path)
        end)
      else
        image:setImageSource(self.data.image)
      end
    end
  elseif type(self.data.id) == "number" then
    local categoryId = self.offerCategoryId
    if categoryId == CATEGORY_ITEM and item then
      item:show()
      item:setItemId(self.data.id)
    elseif categoryId == CATEGORY_OUTFIT and outfit then
      currentOutfit.type = self.data.id
      outfit:show()
      outfit:setOutfit(currentOutfit)
    elseif categoryId == CATEGORY_MOUNT and mount then
      mount:show()
      mount:setOutfit({ type = self.data.id })
    end
  end
end

function onOfferBuy(self)
  if not selectedOffer then
    displayInfoBox("Error", "Something went wrong, make sure to select category and offer.")
    return
  end

  hide()

  local title = "Purchase Confirmation"
  local msg
  if self.count and self.count > 1 then
    msg = "Do you want to buy " .. self.count .. "x " .. selectedOffer.data.name .. " for " .. comma_value(self.price) .. " points?"
  else
    msg = "Do you want to buy " .. selectedOffer.data.name .. " for " .. comma_value(selectedOffer.data.price) .. " points?"
  end

  if selectedOffer.data.name == "Name Change" then
    msgWindow = displayGeneralBox( title, msg, {
      { text = "Yes", callback = changeName },
      { text = "No",  callback = buyCanceled },
      anchor = AnchorHorizontalCenter
    }, changeName, buyCanceled)
  else
    msgWindow = displayGeneralBox( title, msg, {
      { text = "Yes", callback = buyConfirmed },
      { text = "No",  callback = buyCanceled },
      anchor = AnchorHorizontalCenter
    }, buyConfirmed, buyCanceled)
  end
  
  if self.count and self.count > 1 then
    msgWindow.count = self.count
    msgWindow.price = self.price
  else
    msgWindow.count = selectedOffer.data.count
    msgWindow.price = selectedOffer.data.price
  end
end

function buyConfirmed()
  msgWindow:destroy()
  msgWindow = nil
  
  -- Send purchase request to server
  if g_game.getFeature(GameIngameStore) and selectedOffer and selectedOffer.data then
    local offerName = selectedOffer.data.name:lower()
    
    if string.find(offerName, "name") and string.find(offerName, "change") and modules.client_textedit then
      modules.client_textedit.singlelineEditor("", function (newName)
        if newName:len() == 0 then
          return
        end
        g_game.buyStoreOffer(selectedOffer.data.id, 1, newName)
      end)
    else
      g_game.buyStoreOffer(selectedOffer.data.id, 0, "")
    end
  end
end

function buyCanceled()
  msgWindow:destroy()
  msgWindow = nil
  show()
end

function changeName()
  msgWindow:destroy()
  msgWindow = nil
  if changeNameWindow then
    return
  end

  changeNameWindow = g_ui.displayUI("changename")
end

function confirmChangeName()
  changeNameWindow:destroy()
  changeNameWindow = nil
end

function cancelChangeName()
  changeNameWindow:destroy()
  changeNameWindow = nil
end

function changeCoinsAmount(value)
  transferWindow:getChildById("coinsAmountLabel"):setText("Amount to gift: " .. comma_value(value))
end

function changeTaskPointsAmount(value)
  transferWindow:getChildById("taskPointsAmountLabel"):setText("Amount to gift: " .. comma_value(value))
end

function confirmGiftCoins()
  if not transferWindow then
    return
  end

  local amount = transferWindow:getChildById("coinsAmountScrollbar"):getValue()
  local recipient = transferWindow:getChildById("recipient"):getText()
  
  g_game.transferCoins(recipient, amount)
  
  transferWindow:getChildById("recipient"):setText('')
  transferWindow:getChildById("coinsAmountScrollbar"):setValue(0)
  transferWindow:getChildById("taskPointsAmountScrollbar"):setValue(0)
end

function cancelGiftCoins()
  if transferWindow then
    transferWindow:hide()
    show()
  end
end

function createTransferWindow()
  if not transferWindow then
    transferWindow = g_ui.displayUI('giftcoins')
    transferWindow:hide()
  end
end

function toggle()
  if not gameStoreWindow then
    return
  end

  if gameStoreWindow:isVisible() then
    return hide()
  end

  show()
end

function toggleGiftCoins()
  if transferWindow then
    hide()
    transferWindow:show()
    transferWindow:raise()
    transferWindow:focus()
    transferWindow:setOn(premiumSecondPoints ~= -1)
  end
end

function onTypeSearch(self)
  gameStoreWindow:getChildById("searchButton"):setEnabled(#self:getText() > 2)
end

function eraseSearchResults()
  local widget = gameStoreWindow:getChildById("categoriesList"):getChildById(searchResultCategoryId)
  if widget then
    if selected == widget then
      selected = nil
    end
    widget:destroy()
  end
end

function onSearch()
  local searchTextEdit = gameStoreWindow:getChildById("searchTextEdit")
  local text = searchTextEdit:getText()
  if #text < 3 then
    return
  end

  -- Request search results from server
  if g_game.getFeature(GameIngameStore) then
    local serviceType = 3  -- Search type
    g_game.requestStoreOffers(text, serviceType)
  end

  eraseSearchResults()
  addCategory({
    title = searchResultCategoryId,
    iconId = 7,
    categoryId = CATEGORY_NONE
  })

  offers[searchResultCategoryId] = {}
  for categoryId, offerData in pairs(offers) do
    for _, offer in pairs(offerData) do
      if string.find(offer.name:lower(), text) then
       table.insert(offers[searchResultCategoryId], offer)
      end
    end
  end

  local children = gameStoreWindow:getChildById("categoriesList"):getChildren()
  select(children[#children]:getChildById("button"), true)
  searchTextEdit:clearText()
end

function getCategoryIdFromType(type)
  if type == "item" or type == "stackeable" then
    return CATEGORY_ITEM
  elseif type == "outfit" or type == "outfit addon" then
    return CATEGORY_OUTFIT
  elseif type == "mount" then
    return CATEGORY_MOUNT
  elseif type == "premium" or type == "vip" then
    return CATEGORY_PREMIUM
  elseif type == "blessing" or type == "allblessing" then
    return CATEGORY_BLESSING
  else
    return CATEGORY_EXTRAS
  end
end
