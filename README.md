# Remind.md

A tool for storing structured reminders in markdown.

Easily convert to and from markdown and json format. Keep the structure of existing markdown files.

## Example

```
# My Reminders

## My Grouping

### My List

- [ ] A reminder to do something
- [x] this one is completed
  > I'm glad I did this
```

has reminders in the JSON format

```
{
    "reminders": {
        "My Grouping": {
            "My List": [
                {
                    "completed": false,
                    "priority": 0,
                    "title": "A reminder to do something"
                },
                {
                    "completed": true,
                    "notes": "I'm glad I did this",
                    "priority": 0,
                    "title": "this one is completed"
                }
            ]
        }
    }
}
```


## Commands

This project leverages Pandoc and its Lua plugin ability.

To convert from JSON representation:

```
pandoc --from=json2md.lua --to=markdown --wrap=none
```

To extract reminders from markdown:

```
pandoc --to=json2md.lua -f markdown-blank_before_blockquote
```

### Processing Existing Markdown

By default the extraction from markdown includes the full pandoc json representation, the the location of the reminder lists replaced with placeholders. 

Running the json to markdown conversion will reproduce the document as is, with any new lists added at the end.

This means any processing can happen on the intermediate json, and the document will be reformed.

For example

```
pandoc --to=json2md.lua -f markdown-blank_before_blockquote | my_processer | pandoc --from=json2md.lua --to=markdown --wrap=none
```

To control this, you can disable the extension by disabling `json2md.lua-include_full_document`.

For example

```
pandoc --to=json2md.lau -f markdown-blank_before_blockquote -t json2md.lua-include_full_document
```

will produce json with only the reminders. And

```
pandoc --from=json2md.lua --to=markdown --wrap=none -f json2md.lua-include_full_document
```

will produce markdown from only the reminders, ignoring any pandoc in the json.

## Markdown Spec

### Reminder List

```
- <checkbox> [<priority>] <title> <due> <completion>
  [> <notes>]
```

checkbox
: Either `[ ]` or `[x]` if completed

priority
: (optional) `!` `!!` `!!!` mapping to 1,2,3 or 0 if not set

title
: Everything else on the line

due
: A pandoc span containing a date and time without seconds representing the due date, and a class `due`. Optionally an attribute with the RRULE (iCal format). `[YYYY-MM-DD HH:MM]{.due}` or `[YYYY-MM-DD HH:MM]{.due rrule="<RRULE>"}`

completion
: A pandoc span containing a date and time without seconds representing the completion time `[YYYY-MM-DD HH:MM]{.completion}`

notes
: A blockquote that has full markdown support `> note contents`. Indented to match the checkbox so it is part of the list item. Suggested to leave no blank line and disable pandoc's blank line check (`-f markdown-blank_before_blockquote`).

#### Example

```
-   [ ] ! urgently due [1999-12-31 23:59]{.due rrule="FREQ=YEARLY;INTERVAL=1000"}
  > Before the millenium is up!
-   [x] completed item [999-12-31 23:59]{.completion}
```

### Details

Pandoc converts bulleted lists to `-   ` as the prefix: `dash` `space` `space` `space` (3 spaces).

The hierarchy is H2 > H3 > BulletList. This maps to many other pieces of software with Account > List > Items

There can be exactly one bulleted list with checkboxes per H3. Other lists may exists so long as the first item does not have a check box.

## JSON Spec

```
{
    "reminders": {
        "Group Name": {
            "List Name": [
                {
                    "completed": false,
                    "dueDate": "1999-12-31 23:59",
                    "notes": "Before the millenium is up!",
                    "priority": 1,
                    "recurrence": "FREQ=YEARLY;INTERVAL=1000",
                    "title": "urgently due"
                },
                {
                    "completed": true,
                    "completionDate": "999-12-31 23:59",
                    "priority": 0,
                    "title": "completed item"
                }
            ]
        }
    }
}
```
