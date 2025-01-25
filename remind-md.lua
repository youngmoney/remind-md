local json = require 'pandoc.json'

--
-- General Utils
--

local function sorted_keys(arr)
  local keys = {}
  for k in pairs(arr) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end

function ErrorOut(e)
  io.stderr:write(e .. '\n')
  os.exit(1)
end

function getOrError(table, key)
    value = table[key]
    if value == nil then
        ErrorOut("missing key: " .. key)
    end
    return value
end

function getOrCreate(table, key)
    if table[key] == nil then
        table[key] = {}
    end
    return table[key]
end

--
-- Global Settings
--

Extensions = {
    include_full_document = true
}

--
-- Reader (from JSON)
--

local function getListFromBulletList(cb)
    if cb.c[1] == nil or cb.c[1][1] == nil or cb.c[1][1].t ~= "Plain" then
        return nil
    end
    local plain = cb.c[1][1]
    if plain.c[1] == nil or plain.c[1].t ~= "Span" then
        return nil
    end
    local span = plain.c[1]
    if span.attr == nil or span.attr.attributes == nil then
        return nil
    end
    local attrs = span.attr.attributes
    if attrs["list"] == nil or attrs["account"] == nil then
        return nil
    end
    return attrs
end

function Reader(input, opts)
  local blocks = {}
  table.insert(blocks, pandoc.Header(1, "Reminders"))
  local generatedAccounts = {}

  local all = json.decode(tostring(input), false)
  if all == nil then
      ErrorOut("invalid json")
  end
  unorderedaccounts = all["reminders"]
  if unorderedaccounts == nil then
      ErrorOut("reminders not found in input")
  end

  accounts = sorted_keys(unorderedaccounts)
  for i = 1, #accounts do
    local account, unorderedlists = accounts[i], unorderedaccounts[accounts[i]]
    if unorderedlists == nil then
        ErrorOut("invalid account: " .. account)
    end
    table.insert(blocks, pandoc.Header(2, account))
    lists = sorted_keys(unorderedlists)
    for j = 1, #lists do
        local list, reminders = lists[j], unorderedlists[lists[j]]
        if reminders == nil then
            ErrorOut("invalid list: " .. list)
        end
        table.insert(blocks, pandoc.Header(3, list))
        reminderList = {}
        for _, reminder in ipairs(reminders) do
            items = {}

            title = {}
            if getOrError(reminder, "completed") then
                table.insert(title, pandoc.Str("☒"))
            else
                table.insert(title, pandoc.Str("☐"))
            end
            priority = getOrError(reminder, "priority")
            if priority > 0 then
                table.insert(title, pandoc.Space())
                table.insert(title, pandoc.Str(string.rep("!", priority)))
            end
            table.insert(title, pandoc.Space())
            table.insert(title, pandoc.Str(getOrError(reminder, "title")))

            if reminder["dueDate"] ~= nil then
                table.insert(title, pandoc.Space())
                if reminder["recurrence"] ~= nil then
                    table.insert(title, pandoc.Span(reminder.dueDate, {class = "due", rrule = reminder.recurrence}))
                else
                    table.insert(title, pandoc.Span(reminder.dueDate, {class = "due"}))
                end
            end
            if reminder["completionDate"] ~= nil then
                table.insert(title, pandoc.Space())
                table.insert(title, pandoc.Span(reminder.completionDate, {class = "completed"}))
            end

            table.insert(items, pandoc.Plain(title))

            if reminder["notes"] ~= nil then
                table.insert(items, pandoc.BlockQuote(pandoc.read(reminder.notes).blocks))
            end
            table.insert(reminderList, items)
        end
        generated = pandoc.BulletList(reminderList)
        table.insert(blocks, generated)
        local a = getOrCreate(generatedAccounts, account)
        a[list] = generated
    end
  end

  local add_all = opts.extensions:includes 'include_full_document'
  if all["pandoc-api-version"] == nil or add_all == false  then
      return pandoc.Pandoc(blocks)
  end

  all["reminders"] = nil
  doc = json.decode(json.encode(all))
  local addLists = {
      BulletList = function(cb)
          list = getListFromBulletList(cb)
          if list ~= nil then
              if generatedAccounts[list.account] ~= nil then
                  if generatedAccounts[list.account][list.list] ~= nil then
                      return generatedAccounts[list.account][list.list]
                  end
              end
          end
          return cb
      end
  }
  -- TODO: add the leftover lists
  return doc:walk(addLists)

end

--
-- Writer (to JSON)
--

function getPriority(s)
    if s == "!" then
        return 1
    end
    if s == "!!" then
        return 2
    end
    if s == "!!!" then
        return 3
    end
    return nil
end

function rtrim(s)
  return s:match'^(.*%S)%s*$'
end

function asMarkdown(block)
    s = pandoc.write(pandoc.Pandoc(block), 'markdown')
    return rtrim(s)
end

function asPlain(block)
    p = rtrim(pandoc.write(pandoc.Pandoc(block), 'plain'))
    if p == nil then p = "" end
    return p
end

function isDue(block)
    if block.attr ~= nil and #block.attr.classes > 0 and  block.attr.classes[1] == "due" then
        return true
    end
    return false
end

function isCompleted(block)
    if block.attr ~= nil and #block.attr.classes > 0 and  block.attr.classes[1] == "completed" then
        return true
    end
    return false
end

function ProcessTodo(item)
    completed = false
    priority = 0
    titleParts = {}
    due = nil
    recurrence = nil
    completion = nil
    notes = nil

    for i = 1, #item do
        cb = item[i]
        if i == 1 then
            if cb.t ~= "Para" and cb.t ~= "Plain" then
                ErrorOut("reminder does not start with a Para block: " .. tostring(cb))
            end
            for j = 1, #cb.c do
                block = cb.c[j]
                if j == 1 then
                    if block.t == "Str" and block.text == "☐" then
                        completed = false
                    elseif block.t == "Str" and block.text == "☒" then
                        completed = true
                    else
                        return nil
                    end
                elseif j == 2 then
                    if block.t ~= "Space" then
                      ErrorOut("expected a space after the checkbox ")
                    end
                elseif j == 3 and getPriority(block.text) ~= nil then
                    priority = getPriority(block.text)
                else
                    if isDue(block) then
                        due = asPlain(block)
                        if block.attr.attributes["rrule"] ~= nil then
                            recurrence = block.attr.attributes["rrule"]
                        end
                    elseif isCompleted(block) then
                        completed = true
                        completion = asPlain(block)
                    else
                        table.insert(titleParts, block)
                    end
                end
            end
        elseif i == 2 then
            if cb.t ~= "BlockQuote" then
                -- BlockQuote should always directly follow the reminder list item line
                ErrorOut("expceted BlockQuote (-f markdown-blank_before_blockquote)")
            end
            notes = asMarkdown(cb.c)
        else
          ErrorOut("unexpected extra blocks in reminder")
        end
    end
    reminder = {
        completed = completed,
        priority = priority,
        title = asMarkdown(pandoc.Para(titleParts))
    }
    if due ~= nil then
        reminder["dueDate"] = due
    end
    if recurrence ~= nil then
        reminder["recurrence"] = recurrence
    end
    if completion ~= nil then
        reminder["completionDate"] = completion
    end
    if notes ~= nil then
        reminder["notes"] = notes
    end
    return reminder
end

function ProcessReminderList(list)
    l = {}
    for i = 1, #list.c do
        r = ProcessTodo(list.c[i])
        if r == nil then
            if #l > 1 then
                ErrorOut("reminder list has a non-first item that is not a reminder: " .. asPlain(list.c[i]))
            end
            return nil
        end
        table.insert(l, r)
    end
    return l
end


function Writer (doc, opts)
  local accounts = {}
  local accountname = ""
  local listname = ""
  local filter = {
    Header = function (cb)
        if cb.level == 2 then
            accountname = asPlain(cb)
            listname = ""
        end
        if cb.level == 3 then
            listname = asPlain(cb)
        end
    end,
    BulletList = function (cb)
      local p = ProcessReminderList(cb)
      if p == nil then
          return cb
      end
      account = getOrCreate(accounts, accountname)
      if account[listname] ~= nil then
          ErrorOut("a single list (H3) can only exist once: " .. listname)
      end
      account[listname] = p
      local spanattrs = {class="reminder-list", account=accountname, list=listname}
      local listspan = pandoc.Span(accountname .. " > " .. listname, spanattrs)
      return pandoc.BulletList(listspan)
    end
  }
  walked = doc:walk(filter)
  add_all = opts.extensions:includes 'include_full_document'
  if add_all == false then
      return json.encode({reminders=accounts})
  end
  local jwrite = pandoc.write(walked, 'json', opts)
  local de = json.decode(jwrite, false)
  de["reminders"] = accounts
  return json.encode(de)
end
