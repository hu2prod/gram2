module = @
{Node} = require './node'

# ###################################################################################################
#  TODO
#  reject token
# ###################################################################################################

class @Token_parser
  name  : ''
  regex   : ''
  atparse : null
  first_letter_list : []
  first_letter_list_discard : {}
  
  constructor : (name, regex, atparse=null)->
    @name = name
    @regex= regex
    @atparse= atparse
    @first_letter_list = []
    @first_letter_list_discard = {}
  
  fll_add  : (first_letter_list)->
    @first_letter_list = first_letter_list.split ''
    @
  
  fll_discard  : (first_letter_list)->
    for ch in first_letter_list.split ''
      @first_letter_list_discard[ch] = true
    @

class @Tokenizer
  parser_list : []
  text    : null
  atparse_unique_check : false
  is_prepared : false
  tail_space_len: 0
  line       : 0
  pos        : 0
  
  first_char_table  : {}
  positive_symbol_table : {}
  non_marked_rules : []
  
  # atparse access
  token_sequence_hypothesis_list : null
  
  constructor : ()->
    @parser_list= []
    @first_char_table  = {}
    @positive_symbol_table = {}
    @non_marked_rules = []
  
  regex     : (regex)->
    ret = regex.exec(@text)
    return if !ret
    cap_text = ret[0]
    if -1 == cap_text.indexOf '\n'
      @pos += cap_text.length
    else
      line_list = cap_text.split('\n')
      cap_text = line_list.last()
      @line += line_list.length-1
      @pos = cap_text.length+1
    
    @text = @text.substr ret[0].length
    @tail_space_len = /^[ \t]*/.exec(@text)[0].length
    @pos += @tail_space_len
    @text = @text.substr @tail_space_len
    return
  
  initial_prepare_table: ()->
    @positive_symbol_table = {}
    @non_marked_rules = []
    for v in @parser_list
      if v.first_letter_list.length > 0
        for ch in v.first_letter_list
          @positive_symbol_table[ch] ?= []
          @positive_symbol_table[ch].push v
      else
        @non_marked_rules.push v
    
    @is_prepared = true
    return
  
  prepare_table : ()->
    @first_char_table = {}
    for i in [0 ... @text.length]
      ch = @text[i]
      continue if @first_char_table[ch]?
      list = []
      if @positive_symbol_table[ch]?
        for v in @positive_symbol_table[ch]
          list.push v
      for v in @non_marked_rules
        list.push v unless v.first_letter_list_discard[ch]?
      @first_char_table[ch] = list
    return
  
  go      : (text)->
    @line = 1
    @pos  = 1
    @text = text
    @initial_prepare_table() if !@is_prepared
    @prepare_table()
    ret = []
    while @text.length > 0
      found = false
      token_hypothesis_list = []
      for v in @first_char_table[@text[0]]
        reg_ret = v.regex.exec(@text)
        if reg_ret?
          node = new Node
          node.mx_hash.hash_key = v.name
          node.regex = v.regex # parasite
          node.value = reg_ret[0]
          node.atparse = v.atparse if v.atparse?
          node.line = @line
          node.pos  = @pos
          token_hypothesis_list.push node
      throw new Error "can't tokenize '#{@text.substr(0,100)}'..." if token_hypothesis_list.length == 0
      
      token_hypothesis_max_length_list = []
      max_length = 0
      for v in token_hypothesis_list
        max_length = v.value.length if max_length < v.value.length
      for v in token_hypothesis_list
        token_hypothesis_max_length_list.push v if v.value.length == max_length
      
      @token_sequence_hypothesis_list = token_sequence_hypothesis_list = []
      for v in token_hypothesis_max_length_list
        token_sequence_hypothesis_list.push ret_proxy = []
        if v.atparse?
          v.atparse(@, ret_proxy, v)
        else
          ret_proxy.push [v]
      
      @regex token_hypothesis_max_length_list[0].regex
      
      for v in token_hypothesis_max_length_list
        v.mx_hash.tail_space = +@tail_space_len
      
      if @atparse_unique_check
        if token_sequence_hypothesis_list.length > 1
          puts token_hypothesis_max_length_list
          throw new Error "atparse unique failed. Multiple regex pretending"
      else if token_sequence_hypothesis_list.length > 1
        united_length = token_sequence_hypothesis_list[0].length # token list length
        if united_length>1
          throw new Error "united_length > 1 not implemented"
        for v in token_sequence_hypothesis_list
          if v.length != united_length
            puts token_sequence_hypothesis_list
            throw new Error "no united length"
      
      if token_sequence_hypothesis_list.length > 1
        add_list = []
        # only for united_length == 1
        for v in token_sequence_hypothesis_list
          list = v[0]
          if list
            for v2 in list
              add_list.push v2
        if add_list.length
          ret.push add_list 
      else if token_sequence_hypothesis_list.length == 1
        list = token_sequence_hypothesis_list[0]
        for v in list
          ret.push v
      else
        throw new Error("token_sequence_hypothesis_list.length == 0 -> not parsed")
    ret

