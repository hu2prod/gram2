g       = (require './rule')
@Gram               = g.Gram
@gram_escape        = g.gram_escape

g       = (require './node')
@Node               = g.Node

g       = (require './tokenizer')
@Token_parser       = g.Token_parser
@Tokenizer          = g.Tokenizer

# TEMP!!!
g       = (require 'gram')
@Translator         = g.Translator
@bin_op_translator_framework= g.bin_op_translator_framework
@bin_op_translator_holder   = g.bin_op_translator_holder
@un_op_translator_framework = g.un_op_translator_framework
@un_op_translator_holder    = g.un_op_translator_holder

@show_diff = show_diff = (a,b)->
  ### !pragma coverage-skip-block ###
  if a.rule != b.rule
    perr "RULE mismatch"
    perr "a="
    perr a.rule
    perr "b="
    perr b.rule
    return
  if a.value != b.value
    perr "a=#{a.value}"
    perr "b=#{b.value}"
    return
  if a.mx_hash.hash_key != b.mx_hash.hash_key
    perr "a=#{a.value}|||#{a.value_view}"
    perr "b=#{b.value}|||#{b.value_view}"
    perr "a.hash_key = #{a.mx_hash.hash_key}"
    perr "b.hash_key = #{b.mx_hash.hash_key}"
    return
  js_a = JSON.stringify a.mx_hash
  js_b = JSON.stringify b.mx_hash
  if js_a != js_b
    perr "a=#{a.value}|||#{a.value_view}"
    perr "b=#{b.value}|||#{b.value_view}"
    perr "a.mx_hash = #{js_a}"
    perr "b.mx_hash = #{js_b}"
    return
  if a.value_array.length != b.value_array.length
    perr "list length mismatch #{a.value_array.length} != #{b.value_array.length}"
    perr "a=#{a.value}|||#{a.value_view}"
    perr "b=#{b.value}|||#{b.value_view}"
    perr "a=#{a.value_array.map((t)->t.value).join ","}"
    perr "b=#{b.value_array.map((t)->t.value).join ","}"
    return
  for i in [0 ... a.value_array.length]
    show_diff a.value_array[i], b.value_array[i]
  return