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
                if reminder["recurrance"] ~= nil then
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

  -- for _,entry in ipairs(parsed.data.children) do
  --   local d = entry.data
  --   table.insert(blocks, pandoc.Header(2,
  --                 pandoc.Link(read_inlines(d.title), d.url)))
  --   for _,block in ipairs(read_blocks(d.selftext)) do
  --     table.insert(blocks, block)
  --   end
  -- end

  return pandoc.Pandoc(blocks)

end
