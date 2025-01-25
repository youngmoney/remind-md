#!/usr/bin/env bash

function md_to_json() {
    pandoc --to=json2md.lua -f markdown-blank_before_blockquote | python3 -m json.tool
}

function md_to_json_stripped() {
    pandoc --to=json2md.lua -f markdown-blank_before_blockquote -t json2md.lua-include_full_document | python3 -m json.tool
}

function json_to_md() {
    pandoc --from=json2md.lua --wrap=none --to=markdown
}

function json_to_md_stripped() {
    pandoc --from=json2md.lua --wrap=none --to=markdown -f json2md.lua-include_full_document
}

function compare_to_file() {
    diff <(cat) $1
}

# cat examples/basic.json | json_to_md | compare_to_file examples/basic.md
# cat examples/basic.json | json_to_md | md_to_json | compare_to_file examples/basic.full.json
# cat examples/basic.json | json_to_md | md_to_json_stripped | compare_to_file examples/basic.json
# cat examples/basic.md | md_to_json_stripped | compare_to_file examples/basic.json
# cat examples/basic.md | md_to_json | compare_to_file examples/basic.full.json
# cat examples/basic.md | md_to_json | json_to_md | compare_to_file examples/basic.md
# cat examples/basic.md | md_to_json | json_to_md_stripped | compare_to_file examples/basic.stripped.md
#
# cat examples/interleaved.json | json_to_md | compare_to_file examples/interleaved.stripped.md
# cat examples/interleaved.full.json | json_to_md | md_to_json | compare_to_file examples/interleaved.full.json
# cat examples/interleaved.full.json | json_to_md | md_to_json_stripped | compare_to_file examples/interleaved.json
# cat examples/interleaved.json | json_to_md | md_to_json_stripped | compare_to_file examples/interleaved.json
# cat examples/interleaved.md | md_to_json_stripped | compare_to_file examples/interleaved.json
# cat examples/interleaved.md | md_to_json | compare_to_file examples/interleaved.full.json
# cat examples/interleaved.md | md_to_json | json_to_md | compare_to_file examples/interleaved.md
cat examples/interleaved.md | md_to_json | json_to_md_stripped | compare_to_file examples/interleaved.stripped.md
