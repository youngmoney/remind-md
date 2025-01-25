#!/usr/bin/env bash

function md_to_json() {
    pandoc --to=remind-md.lua -f markdown-blank_before_blockquote | python3 -m json.tool --sort-keys
}

function md_to_json_stripped() {
    pandoc --to=remind-md.lua-include_full_document -f markdown-blank_before_blockquote | python3 -m json.tool --sort-keys
}

function json_to_md() {
    pandoc --from=remind-md.lua --wrap=none --to=markdown
}

function json_to_md_stripped() {
    pandoc --from=remind-md.lua-include_full_document --wrap=none --to=markdown
}

function compare_to_file() {
    diff <(cat | tee /tmp/remind_test_output) $1 || echo failed with $1
}


# Tests often fail because in pandoc attributes are placed in a list, which has a random ordering.

cat examples/basic.json | json_to_md | compare_to_file examples/basic.md
cat examples/basic.json | json_to_md | md_to_json | compare_to_file examples/basic.full.json
cat examples/basic.json | json_to_md | md_to_json_stripped | compare_to_file examples/basic.json
cat examples/basic.md | md_to_json_stripped | compare_to_file examples/basic.json
cat examples/basic.md | md_to_json | compare_to_file examples/basic.full.json
cat examples/basic.md | md_to_json | json_to_md | compare_to_file examples/basic.md
cat examples/basic.md | md_to_json | json_to_md_stripped | compare_to_file examples/basic.stripped.md

cat examples/interleaved.json | json_to_md | compare_to_file examples/interleaved.stripped.md
cat examples/interleaved.full.json | json_to_md | md_to_json | compare_to_file examples/interleaved.full.json
cat examples/interleaved.full.json | json_to_md | md_to_json_stripped | compare_to_file examples/interleaved.json
cat examples/interleaved.json | json_to_md | md_to_json_stripped | compare_to_file examples/interleaved.json
cat examples/interleaved.md | md_to_json_stripped | compare_to_file examples/interleaved.json
cat examples/interleaved.md | md_to_json | compare_to_file examples/interleaved.full.json
cat examples/interleaved.md | md_to_json | json_to_md | compare_to_file examples/interleaved.md
cat examples/interleaved.md | md_to_json | json_to_md_stripped | compare_to_file examples/interleaved.stripped.md
