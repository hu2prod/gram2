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