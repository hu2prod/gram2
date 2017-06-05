# gram2
Nonpolynomial superpower parser, better, faster

# Differences from gram1
* strict operation `=` not exist, use `==`
* penetration flag removed
* @ is position pass, not value
* You can't write more ms rule `delimiter=, ` use quotes `delimiter=','` or double quotes
* `parse_text_list` not exists anymore. Use `go`. No ugly "simple tokenizer" incorporated
* deep pass `value` is not working anymore. Use `value_view` or `node.value or node.value_view`.
* all possible hask_keys should be present in gram rules.
