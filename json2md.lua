local json = require 'pandoc.json'

local function read_inlines(raw)
  local doc = pandoc.read(raw, "commonmark")
  return pandoc.utils.blocks_to_inlines(doc.blocks)
end

local function read_blocks(raw)
  local doc = pandoc.read(raw, "commonmark")
  return doc.blocks
end

local function sorted_keys(arr)
  local keys = {}
  for k in pairs(arr) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end

function Reader(input)

  local blocks = {}
  table.insert(blocks, pandoc.Header(1, "Reminders"))

  local unorderedaccounts = json.decode(tostring(input))
  accounts = sorted_keys(unorderedaccounts)
  for i = 1, #accounts do
    local account, unorderedlists = accounts[i], unorderedaccounts[accounts[i]]
    table.insert(blocks, pandoc.Header(2, account))
    lists = sorted_keys(unorderedlists)
    for j = 1, #lists do
        local list, reminders = lists[j], unorderedlists[lists[j]]
        table.insert(blocks, pandoc.Header(3, list))
        reminderList = {}
        for _, reminder in ipairs(reminders) do
            items = {}

            title = {}
            if reminder.completed then
                table.insert(title, pandoc.Str("☒"))
            else
                table.insert(title, pandoc.Str("☐"))
            end
            if reminder.priority > 0 then
                table.insert(title, pandoc.Space())
                table.insert(title, pandoc.Str(string.rep("!", reminder.priority)))
            end
            table.insert(title, pandoc.Space())
            table.insert(title, pandoc.Str(reminder.title))

            if reminder["dueDate"] ~= nil then
                table.insert(title, pandoc.Space())
                if reminder["recurrence"] ~= nil then
                    table.insert(title, pandoc.Span(reminder.dueDate, {class = "due", rrule = reminder.recurrance}))
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
        table.insert(blocks, pandoc.BulletList(reminderList))
    end
  end

  return pandoc.Pandoc(blocks)

end

function ErrorOut(e)
  io.stderr:write(e)
  os.exit(1)
end

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
    return rtrim(pandoc.write(pandoc.Pandoc(block), 'plain'))
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
            if cb.t ~= "Para" then
                ErrorOut("reminder does not start with a Para block")
            end
            for j = 1, #cb.c do
                block = cb.c[j]
                if j == 1 then
                    if block.t == "Str" and block.text == "☐" then
                        completed = false
                    elseif block.t == "Str" and block.text == "☒" then
                        completed = true
                    else
                      -- ErrorOut("expected a checkbox as the first item")
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
        table.insert(l, r)
    end
    return l
end


function Writer (doc, opts)
  local lists = {}
  local filter = {
    BulletList = function (cb)
      table.insert(lists, ProcessReminderList(cb))
      return pandoc.BulletList({pandoc.Str('reminder-list:' .. tostring(#lists))})
    end
  }
  local jwrite = pandoc.write(doc:walk(filter), 'json', opts)
  local de = json.decode(jwrite, false)
  de["reminders"] = lists
  return json.encode(de)
end
