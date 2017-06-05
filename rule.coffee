# BUG hash_to_pos для head/tail правил отсутствует

module = @
require 'fy/codegen'
{Node} = require './node'
{explicit_list_generator} = require './explicit_list_generator'
# ###################################################################################################
#    tokenizer
# ###################################################################################################
{Tokenizer, Token_parser} = require 'gram'

tokenizer = new Tokenizer
tokenizer.parser_list.push (new Token_parser 'dollar_id', /^\$[_a-z0-9]+/i)
tokenizer.parser_list.push (new Token_parser 'hash_id', /^\#[_a-z0-9]+/i)
tokenizer.parser_list.push (new Token_parser 'pass_id', /^\@[_a-z0-9]+/i)
tokenizer.parser_list.push (new Token_parser 'id', /^[_a-z][_a-z0-9]*/i)
tokenizer.parser_list.push (new Token_parser '_bin_op', /// ^ (
  (&&?|\|\|?|[-+*/])|
  <>|[<>!=]=|<|>
) ///)
tokenizer.parser_list.push (new Token_parser '_pre_op', /^!/)
# tokenizer.parser_list.push (new Token_parser 'assign_bin_op', /^(&&?|\|\|?|[-+])?=/)
tokenizer.parser_list.push (new Token_parser 'bracket', /^[\[\]\(\)\{\}]/)
tokenizer.parser_list.push (new Token_parser 'delimiter', /^[:.]/)



string_regex_craft = ///
    \\[^xu] |               # x and u are case sensitive while hex letters are not
    \\x[0-9a-fA-F]{2} |     # Hexadecimal escape sequence
    \\u(?:
      [0-9a-fA-F]{4} |      # Unicode escape sequence
      \{(?:
        [0-9a-fA-F]{1,5} |  # Unicode code point escapes from 0 to FFFFF
        10[0-9a-fA-F]{4}    # Unicode code point escapes from 100000 to 10FFFF
      )\}
    )
///.toString().replace(/\//g,'')
single_quoted_regex_craft = ///
  (?:
    [^\\] |
    #{string_regex_craft}
  )*?
///.toString().replace(/\//g,'')
tokenizer.parser_list.push (new Token_parser 'string_literal_singleq'      , /// ^  ' #{single_quoted_regex_craft} '    ///)
double_quoted_regexp_craft = ///
  (?:
    [^\\#] |
    \#(?!\{) |
    #{string_regex_craft}
  )*?
///.toString().replace(/\//g,'')
tokenizer.parser_list.push (new Token_parser 'string_literal_doubleq'      , /// ^  " #{double_quoted_regexp_craft} "    ///)

tokenizer.parser_list.push (new Token_parser 'number', /^[0-9]+/)

# ###################################################################################################
#    gram
# ###################################################################################################
base_priority = -9000
{Gram} = require 'gram'
gram = new Gram
q = (a, b)->gram.rule a,b

q('pre_op',  '!')                                       .mx('priority=1')
q('pre_op',  '-')                                       .mx('priority=1')
q('pre_op',  '+')                                       .mx('priority=1')

q('bin_op',  '*|/')                                     .mx('priority=5  right_assoc=1')
q('bin_op',  '+|-')                                     .mx('priority=6  right_assoc=1')
q('bin_op',  '<|<=|>|>=|!=|<>|==')                      .mx('priority=9')
q('bin_op',  '&|&&|and|or|[PIPE]|[PIPE][PIPE]')         .mx('priority=10 right_assoc=1')


q('access_rvalue',  '#dollar_id')                       .mx("priority=#{base_priority} ult=dollar_id")
q('access_rvalue',  '#hash_id')                         .mx("priority=#{base_priority} ult=hash_id")
q('rvalue',  '#access_rvalue')                          .mx("priority=#{base_priority} ult=access_rvalue")

q('rvalue',  '#pass_id')                                .mx("priority=#{base_priority} ult=dollar_id")

q('rvalue',  '#number')                                 .mx("priority=#{base_priority} ult=value")
q('rvalue',  '#id')                                     .mx("priority=#{base_priority} ult=wrap_string")
q('rvalue',  '#string_literal_singleq')                 .mx("priority=#{base_priority} ult=value")
q('rvalue',  '#string_literal_doubleq')                 .mx("priority=#{base_priority} ult=value")


q('rvalue',  '#rvalue #bin_op #rvalue')                 .mx('priority=#bin_op.priority ult=bin_op')   .strict('#rvalue[1].priority<#bin_op.priority #rvalue[2].priority<#bin_op.priority')
# q('rvalue',  '#rvalue #bin_op #rvalue')                 .mx('priority=#bin_op.priority ult=bin_op')   .strict('#rvalue[1].priority<#bin_op.priority #rvalue[2].priority=#bin_op.priority #bin_op.left_assoc')
q('rvalue',  '#rvalue #bin_op #rvalue')                 .mx('priority=#bin_op.priority ult=bin_op')   .strict('#rvalue[1].priority=#bin_op.priority #rvalue[2].priority<#bin_op.priority #bin_op.right_assoc')

q('rvalue',  '#pre_op #rvalue')                         .mx('priority=#pre_op.priority ult=pre_op')   .strict('#rvalue[1].priority<=#pre_op.priority')

q('rvalue',  '( #rvalue )')                             .mx("priority=#{base_priority} ult=deep")

q('access_rvalue', '#hash_id [ #rvalue ]')                     .mx("priority=#{base_priority} ult=hash_array_access")
q('rvalue', '#access_rvalue [ #number : #number ]')            .mx("priority=#{base_priority} ult=slice_access")
# . access
q('rvalue', '#access_rvalue . #id')                            .mx("priority=#{base_priority} ult=field_access")

q('strict_rule', '#rvalue')                             .mx("ult=deep")

# ###################################################################################################
#    trans
# ###################################################################################################

{
  Translator
  bin_op_translator_framework
  bin_op_translator_holder
  un_op_translator_framework
  un_op_translator_holder
} = require 'gram'

trans = new Translator
trans.trans_skip = {}
trans.trans_token = {}

deep = (ctx, node)->
  list = []
  # if node.mx_hash.deep?
  #   node.mx_hash.deep = '0' if node.mx_hash.deep == false # special case for deep=0
  #   value_array = (node.value_array[pos] for pos in node.mx_hash.deep.split ',')
  # else
  #   value_array = node.value_array
  
  
  value_array = node.value_array
  for v,k in value_array
    list.push ctx.translate v
  list
# ###################################################################################################
do ()->
  holder = new bin_op_translator_holder
  for v in bin_op_list = "+ - * / && ||".split ' '
    holder.op_list[v]  = new bin_op_translator_framework "($1$op$2)"
  
  # SPECIAL
  holder.op_list["&"]  = new bin_op_translator_framework "($1&&$2)"
  holder.op_list["|"]  = new bin_op_translator_framework "($1||$2)"
  holder.op_list["<>"]  = new bin_op_translator_framework "($1!=$2)"

  for v in bin_op_list = "== != < <= > >=".split ' '
    holder.op_list[v]  = new bin_op_translator_framework "($1$op$2)"
  trans.translator_hash['bin_op'] = holder

do ()->
  holder = new un_op_translator_holder
  holder.mode_pre()
  for v in un_op_list = "+ - !".split ' '
    holder.op_list[v]  = new un_op_translator_framework "$op$1"

  trans.translator_hash['pre_op'] = holder
# ###################################################################################################


trans.translator_hash['deep']   = translate:(ctx, node)->
  list = deep ctx, node
  list.join('')

trans.translator_hash['value']  = translate:(ctx, node)->node.value
trans.translator_hash['wrap_string']  = translate:(ctx, node)->JSON.stringify node.value

trans.translator_hash['dollar_id'] = translate:(ctx, node)->
  idx = (node.value.substr 1)-1
  if idx < 0 or idx >= ctx.rule.sequence.length
    throw new Error "strict_rule access out of bounds [0, #{ctx.rule.sequence.length}] idx=#{idx} (note real value are +1)"
  node.mx_hash.idx = idx
  ctx.id_touch_list.upush idx
  "arg_list[#{idx}]"

trans.translator_hash['hash_id'] = translate:(ctx, node)->
  name = node.value.substr 1
  if !idx_list = ctx.rule.hash_to_pos[name]
    throw new Error "unknown hash_key '#{name}' allowed key list #{JSON.stringify Object.keys(ctx.rule.hash_to_pos)}"
  node.mx_hash.idx = idx = idx_list[0]
  ctx.id_touch_list.upush idx
  "arg_list[#{idx}]"

trans.translator_hash['access_rvalue'] = translate:(ctx, node)->
  code = ctx.translate node.value_array[0]
  "#{code}.value"

trans.translator_hash['hash_array_access'] = translate:(ctx, node)->
  [id_node, _s, idx_node] = node.value_array
  name = id_node.value.substr 1
  if !idx_list = ctx.rule.hash_to_pos[name]
    throw new Error "unknown hash_key '#{name}' allowed key list #{JSON.stringify Object.keys(ctx.rule.hash_to_pos)}"
  
  idx = idx_node.value-1
  if idx < 0 or idx >= idx_list.length
    throw new Error "hash_array_access out of bounds [0, #{idx_list.length}] idx=#{idx} (note real value are +1)"
  node.mx_hash.idx = idx = idx_list[idx]
  ctx.id_touch_list.upush idx
  "arg_list[#{idx}]"

trans.translator_hash['slice_access'] = translate:(ctx, node)->
  [rvalue_node, _s, start_node, _s, end_node] = node.value_array
  rvalue = ctx.translate rvalue_node
  start  = +start_node.value
  end    = +end_node.value
  if end < start
    throw new Error "end < start at #{node.value}"
  
  "#{rvalue}.value.substr(#{start},#{end-start+1})"

trans.translator_hash['field_access'] = translate:(ctx, node)->
  [root_node, _s, field_node] = node.value_array
  root = ctx.translate root_node
  field = field_node.value
  "#{root}.mx_hash.#{field}"

# ###################################################################################################
#    Gram_rule
# ###################################################################################################
class @Gram_rule
  hash_to_pos : {}
  ret_hash_key: ''
  ret_hash_key_idx: 0
  sequence        : []
  mx_sequence     : []
  strict_sequence : []
  
  mx_rule_fn    : (arg_list)->{} # default pass
  strict_rule_fn: (arg_list)->true # default pass
  # TODO loop wrap
  
  constructor : ()->
    @hash_to_pos    = {}
    @sequence       = []
    @mx_sequence    = []
    @strict_sequence= []
  
  cmp_seq : (t)->
    return @sequence.join() == t.sequence.join()
  # ###################################################################################################
  #    mx
  # ###################################################################################################
  mx : (str)->
    pos_list = str.split /\s+/g
    @mx_sequence = []
    code_jl = []
    for pos in pos_list
      continue if !pos
      [key, value] = pos.split `/=/`
      if !value # autoassign case
        if @sequence.length != 1
          throw new Error "can't autoassign if sequence.length(#{@sequence.length}) != 1"
        @mx_sequence.push {
          autoassign    : true
          key
          id_touch_list : null
          ast           : null
        }
        continue
      {id_touch_list, ast} = @_strict_pos_parse value
      @mx_sequence.push {
        autoassign : false
        key
        id_touch_list
        ast
      }
    return
  
  _mx : ()->
    code_jl = []
    for v in @mx_sequence
      {key} = v
      if v.autoassign
        code_jl.push """
          mx_hash_stub[#{JSON.stringify key}] = arg_list[0].mx_hash[#{JSON.stringify key}];
          """
      else
        trans.rule   = @
        trans.id_touch_list = []
        code = trans.go v.ast
        code_jl.push """
          mx_hash_stub[#{JSON.stringify key}] = #{code};
          """
    @mx_rule_fn = eval """
      __ret = (function(arg_list, mx_hash_stub){
        #{join_list code_jl, '  '}
      })
      """
    return
  
  cmp_mx : (t)->
    return false if @mx_sequence.length != t.mx_sequence.length
    for v1,idx in @mx_sequence
      v2 = t.mx_sequence[idx]
      return false if v1.autoassign != v2.autoassign
      return false if v1.key != v2.key
      return false if v1.id_touch_list.join() != v2.id_touch_list.join()
      return false if v1.ast.value != v2.ast.value # !!! DANGER !!!
    
    true
  
  # ###################################################################################################
  #    strict
  # ###################################################################################################
  strict : (str)->
    pos_list = str.split /\s+/g
    @strict_sequence = []
    for pos in pos_list
      continue if !pos
      {id_touch_list, ast} = @_strict_pos_parse pos
      @strict_sequence.push {
        id_touch_list
        ast
      }
    return
  
  _strict : ()->
    code_jl = []
    for pos,idx in @sequence
      continue if pos[0] == "#"
      code_jl.push """
        if (arg_list[#{idx}].value != #{JSON.stringify pos}) return false;
        """
    
    for v in @strict_sequence
      trans.rule   = @
      trans.id_touch_list = []
      code = trans.go v.ast
      code_jl.push """
        if (!(#{code})) return false;
        """
    @strict_rule_fn = eval """
      __ret = (function(arg_list){
        #{join_list code_jl, '  '}
        return true;
      })
      """
  
  cmp_strict : (t)->
    return false if @strict_sequence.length != t.strict_sequence.length
    for v1,idx in @strict_sequence
      v2 = t.strict_sequence[idx]
      return false if v1.id_touch_list.join() != v2.id_touch_list.join()
      return false if v1.ast.value != v2.ast.value # !!! DANGER !!!
    
    true
  
  _strict_pos_parse : (str)->
    tok_list = tokenizer.go str
    
    gram.mode_full = true
    ast = gram.parse_text_list tok_list,
      expected_token : 'strict_rule'
    if ast.length == 0
      throw new Error "Parsing error. No proper combination found"
    if ast.length != 1
      # [a,b] = ast
      # show_diff a,b
      ### !pragma coverage-skip-block ###
      throw new Error "Parsing error. More than one proper combination found #{ast.length}"
    
    trans.rule   = @
    trans.id_touch_list = []
    
    code = trans.go ast[0]
    {
      code
      id_touch_list : trans.id_touch_list
      ast : ast[0]
    }
  
  # unused
  # cmp : (t)->
  #   return false if @ret_hash_key != t.hash_key
  #   return false if !@cmp_seq(t)
  #   return false if !@cmp_mx(t)
  #   return false if !@cmp_strict(t)
  #   return
  
  _head_cmp : (t)->
    # return false if @ret_hash_key != t.hash_key
    return false if !@cmp_seq(t)
    return false if !@cmp_mx(t)
    return false if !@cmp_strict(t)
    true
    
  
class @Gram_rule_proxy
  rule_list : []
  constructor:()->
    @rule_list = []
  
  mx : (str)->
    for rule in @rule_list
      rule.mx str
    @
  
  strict : (str)->
    for rule in @rule_list
      rule.strict str
    @
  
# ###################################################################################################
#    Gram
# ###################################################################################################
str_replace = (search, replace, str)-> str.split(search).join(replace)
@gram_unescape= (v) ->
  v = str_replace '[PIPE]',   '|', v
  v = str_replace '[QUESTION]','?', v
  v = str_replace '[DOLLAR]', '$', v # нужно в случае конструкций ${}, когда нельзя отделить $ от токена
  v = str_replace '[HASH]',   '#', v

class @Gram
  @magic_attempt_limit_mult : 4
  initial_rule_list : []
  
  hash_key_list : []
  extra_hash_key_list : []
  _optimized : false
  
  # Array<Array<Node> >
  # hki = hash_key_idx
  # a_pos = left  token bound position
  # b_pos = right token bound position
  t_hki_a_pos_old_list : []
  t_hki_a_pos_new_list : []
  t_hki_b_pos_old_list : []
  t_hki_b_pos_new_list : []
  new_new_list         : []
  
  constructor:()->
    @initial_rule_list    = []
    @hash_key_list        = []
    @extra_hash_key_list  = []
    @t_hki_a_pos_old_list = []
    @t_hki_a_pos_new_list = []
    @t_hki_b_pos_old_list = []
    @t_hki_b_pos_new_list = []
    @new_new_list         = []
  
  rule : (_ret, str_list)->
    @_optimized = false
    ret = new module.Gram_rule_proxy
    
    hash_to_pos = {}
    
    pos_list_list = []
    for chunk,idx in chunk_list = str_list.split /\s+/g
      list = chunk.split '|'
      if list.length > 1
        # NOTE positions not allowed, only const
        for v,k in list
          if v[0] == '#'
            throw new Error "#positions + | not allowed"
          list[k] = module.gram_unescape v
        pos_list_list.push list
        continue
      
      if chunk[0] == "#"
        id = chunk.substr 1
        id = module.gram_unescape id
        hash_to_pos[id] ?= []
        hash_to_pos[id].push idx
      
      if /\?$/.test chunk
        chunk = chunk.substr 0, chunk.length-1
        chunk = module.gram_unescape chunk
        pos_list_list.push [chunk, null]
        continue
      
      chunk = module.gram_unescape chunk
      pos_list_list.push [chunk]
    
    pos_list_list2 = explicit_list_generator pos_list_list
    for sequence in pos_list_list2
      id_mapping = {}
      sequence_filtered = []
      dst = 0
      for v,idx in sequence
        continue if !v?
        id_mapping[idx] = dst++
        sequence_filtered.push v
      
      continue if sequence_filtered.length == 0
      
      rule = new module.Gram_rule
      rule.ret_hash_key = _ret
      for k,v of hash_to_pos
        rule.hash_to_pos[k] = v.map (t)->id_mapping[t]
      
      rule.sequence = sequence_filtered
      rule.strict('') # reinit strict_rule_fn by sequence in case strict will not be called at all
      
      @initial_rule_list.push rule
      ret.rule_list.push rule
    
    ret
  
  rule_1_by_arg : []
  rule_2_by_arg : []
  
  optimize : ()->
    @_optimized = true
    synth_rule_list = []
    uid = 0
    
    proxy = new module.Gram_rule
    proxy.sequence = ['STUB', 'STUB']
    
    replace_id_access = (tree, skip_id)->
      search_idx = tree.mx_hash.idx
      if search_idx?
        if search_idx != skip_id
          {ast} = proxy._strict_pos_parse "$1.__arg_#{search_idx}"
          return ast
        else
          # $2
          # #a
          # #a[2]
          {ast} = proxy._strict_pos_parse "@2"
          return ast
      list = tree.value_array
      for v,k in list
        list[k] = replace_id_access v, skip_id
      tree
    
    for rule in @initial_rule_list
      switch rule.sequence.length
        when 1,2
          found = false
          for _rule in synth_rule_list
            if rule._head_cmp _rule
              found = _rule
              break
          if !found
            synth_rule_list.push rule
        else
          found = null
          while rule.sequence.length > 2
            head_rule = new module.Gram_rule
            tail_rule = new module.Gram_rule
            
            {ast, id_touch_list} = proxy._strict_pos_parse "1"
            tail_rule.mx_sequence.push {
              autoassign : false
              key        : "is_proxy_rule"
              id_touch_list
              ast
            }
            
            tail_rule.ret_hash_key = rule.ret_hash_key
            
            head_rule.hash_to_pos = rule.hash_to_pos # дабы не сломалось ничего.
            
            _max_idx = rule.sequence.length-1
            for k,list of rule.hash_to_pos
              v = list.last()
              if v == _max_idx
                tail_rule.hash_to_pos[k] ?= []
                tail_rule.hash_to_pos[k].push 1
              # а остальных быть не может т.к. strict rule будет переписано и все остальные позиции будут через @
            
            head_rule.sequence = rule.sequence.clone()
            last = head_rule.sequence.pop()
            tail_rule.sequence = ['REPLACE_ME', last]
            
            last_id = head_rule.sequence.length
            
            # mx отдувается за всех. Ему нужно пробросить всё
            head_filled_with_mx_pass = false
            fill_head = ()->
              if !head_filled_with_mx_pass
                head_filled_with_mx_pass = true
                for i in [0 ... last_id]
                  key = "__arg_#{i}"
                  # p "key=#{key}"
                  {ast, id_touch_list} = head_rule._strict_pos_parse "@#{i+1}"
                  head_rule.mx_sequence.push {
                    autoassign : false
                    key
                    id_touch_list
                    ast
                  }
              return
            
            for v in rule.mx_sequence
              if v.autoassign # DEBUG ONLY
                throw new Error "WTF"
              if v.id_touch_list.has last_id
                if v.id_touch_list.length == 1
                  tail_rule.mx_sequence.push v
                else
                  # PROBLEM
                  fill_head()
                  v.ast = replace_id_access v.ast, last_id
                  tail_rule.mx_sequence.push v
              else
                if v.key == "__arg_0" and rule.sequence.length == 3
                  {ast, id_touch_list} = proxy._strict_pos_parse "@1"
                  head_rule.mx_sequence.push {
                    autoassign    : false
                    key           : v.key
                    id_touch_list
                    ast
                  }
                else if v.key == "__arg_1" and rule.sequence.length == 3
                  {ast, id_touch_list} = proxy._strict_pos_parse "@2"
                  head_rule.mx_sequence.push {
                    autoassign    : false
                    key           : v.key
                    id_touch_list
                    ast
                  }
                else
                  head_rule.mx_sequence.push v
                
                {ast, id_touch_list} = proxy._strict_pos_parse "$1.#{v.key}"
                tail_rule.mx_sequence.push {
                  autoassign    : false
                  key           : v.key
                  id_touch_list
                  ast
                }
            
            for v in rule.strict_sequence
              if v.id_touch_list.has last_id
                if v.id_touch_list.length == 1
                  # tail_rule.strict_sequence.push v
                  # p "last_id=#{last_id}"
                  # p v.ast.value_array[0]?.value_array[0]?.value_array[0]
                  v.ast = replace_id_access v.ast, last_id
                  # p v.ast.value_array[0]?.value_array[0]?.value_array[0]
                  tail_rule.strict_sequence.push v
                else
                  v.ast = replace_id_access v.ast, last_id # вызывать тяжелую артиллерию только тогда, когда действительно надо
                  tail_rule.strict_sequence.push v
                  # PROBLEM
                  fill_head()
              else
                head_rule.strict_sequence.push v
            
            for _rule in synth_rule_list
              if head_rule._head_cmp _rule
                found = _rule
                break
            
            synth_rule_list.push tail_rule
            if found
              tail_rule.sequence[0] = "#"+found.ret_hash_key
              break
            
            pass_hash_key = "proxy_#{head_rule.sequence.join(',')}_#{uid++}"
            head_rule.ret_hash_key = pass_hash_key
            tail_rule.sequence[0] = "#"+pass_hash_key
            rule = head_rule
          
          if !found
            synth_rule_list.push rule
    
    for rule in synth_rule_list
      rule._mx()
      rule._strict()
    # ###################################################################################################
    @hash_key_list.clear()
    @hash_key_list.push '*' # special position for string constants
    @hash_key_list.uappend @extra_hash_key_list
    for rule in synth_rule_list
      @hash_key_list.upush rule.ret_hash_key
      for v in rule.sequence
        if v[0] == "#"
          @hash_key_list.upush v.substr 1
    
    for rule in synth_rule_list
      rule.ret_hash_key_idx = @hash_key_list.idx rule.ret_hash_key
    
    # ###################################################################################################
    @rule_1_by_arg = []
    for i in [0 ... @hash_key_list.length]
      @rule_1_by_arg.push []
    
    @rule_2_by_arg = []
    for i in [0 ... (@hash_key_list.length ** 2)]
      @rule_2_by_arg.push []
    
    pos_to_idx = (pos)=>
      idx = 0 # if string const
      if pos[0] == "#"
        idx = @hash_key_list.idx pos.substr 1
      if idx == -1 # DEBUG
        throw new Error "WTF idx == -1 pos=#{pos} #{JSON.stringify @hash_key_list}"
      idx
      
    mult = @hash_key_list.length
    
    for rule in synth_rule_list
      switch rule.sequence.length
        when 1
          [pos] = rule.sequence
          idx = pos_to_idx pos
          @rule_1_by_arg[idx].push rule
        when 2
          [pos_a, pos_b] = rule.sequence
          idx_a = pos_to_idx pos_a
          idx_b = pos_to_idx pos_b
          @rule_2_by_arg[idx_a*mult + idx_b].push rule
    
    return
  
  hypothesis_find : (node_hypothesis_list, opt={})->
    @optimize() if !@_optimized
    
    mode_full = false
    mode_full = opt.mode_full if opt.mode_full?
    
    expected_token_idx = -1
    if opt.expected_token?
      if -1 == expected_token_idx = @hash_key_list.idx opt.expected_token
        throw new Error "unknown expected_token hash_key '#{opt.expected_token}' list=#{JSON.stringify @hash_key_list}"
    
    max_hki = @hash_key_list.length
    max_idx = node_hypothesis_list.length
    @t_hki_a_pos_old_list.length  = max_hki
    @t_hki_a_pos_new_list.length  = max_hki
    @t_hki_b_pos_old_list.length  = max_hki
    @t_hki_b_pos_new_list.length  = max_hki
    
    t_hki_a_new_count_list = []
    t_hki_b_new_count_list = []
    for i in [0 ... max_hki]
      t_hki_a_new_count_list.push 0
      t_hki_b_new_count_list.push 0
    
    init_max_idx = ()->
      ret = []
      for j in [0 .. max_idx]
        ret.push []
      ret
    
    @new_new_list = []
    # INCLUSIVE [a,b]
    for i in [0 ... max_hki]
      @t_hki_a_pos_old_list[i] = init_max_idx()
      @t_hki_a_pos_new_list[i] = init_max_idx()
      @t_hki_b_pos_old_list[i] = init_max_idx()
      @t_hki_b_pos_new_list[i] = init_max_idx()
    
    for v_list,idx in node_hypothesis_list
      for v in v_list
        v.a = idx
        v.b = idx+1
        v.hash_key_idx = @hash_key_list.idx v.mx_hash.hash_key
        if v.hash_key_idx == -1
          throw new Error "WTF v.hash_key_idx == -1 v.mx_hash.hash_key=#{v.mx_hash.hash_key} list=#{JSON.stringify @hash_key_list}"
        @t_hki_a_pos_new_list[v.hash_key_idx][idx  ].push v
        @t_hki_b_pos_new_list[v.hash_key_idx][idx+1].push v
        if v.hash_key_idx != 0
          @t_hki_a_pos_new_list[0][idx  ].push v
          @t_hki_b_pos_new_list[0][idx+1].push v
        @new_new_list.push v
    # create hash_key_idx arrays for max_idx
    
    ret = []
    fin_collect = ()=>
      ret.clear()
      if mode_full
        for pos_list_list,hash_key_idx in @t_hki_a_pos_old_list
          continue if expected_token_idx != -1 and hash_key_idx != expected_token_idx
          list = pos_list_list[0]
          for v in list
            continue if v.b != max_idx
            continue if v.hash_key_idx != hash_key_idx
            ret.push v
      
      for v in @new_new_list
        continue if v.a != 0
        continue if v.b != max_idx
        continue if expected_token_idx != -1 and v.hash_key_idx != expected_token_idx
        ret.push v
      
      if mode_full then false else !!ret.length
    
    return ret if fin_collect()
    
    # BUG? правила вида term term лезут во все токены в поисках value даже в те, где есть только value_view
    
    limit = Gram.magic_attempt_limit_mult*max_idx
    for i in [1 .. limit]
      @new_new_list.clear()
      
      # MORE OPT jump list
      for hash_key_idx in [0 ... max_hki]
        count = 0
        for v in @t_hki_a_pos_new_list[hash_key_idx]
          count += v.length
        t_hki_a_new_count_list[hash_key_idx] = count
        count = 0
        for v in @t_hki_b_pos_new_list[hash_key_idx]
          count += v.length
        t_hki_b_new_count_list[hash_key_idx] = count
      
      # L2R
      rule_2_idx = 0
      len = @hash_key_list.length
      for hash_key_idx_1 in [0 ... len]
        for hash_key_idx_2 in [0 ... len]
          rule_list = @rule_2_by_arg[rule_2_idx++]
          continue if rule_list.length == 0
          # new_list_b_count = 1
          # new_list_a_count = 1
          new_list_b_count = t_hki_b_new_count_list[hash_key_idx_1]
          new_list_a_count = t_hki_a_new_count_list[hash_key_idx_2]
          continue if new_list_a_count == 0 and new_list_b_count == 0
          
          node_old_list_b = @t_hki_b_pos_old_list[hash_key_idx_1]
          node_new_list_b = @t_hki_b_pos_new_list[hash_key_idx_1]
          node_old_list_a = @t_hki_a_pos_old_list[hash_key_idx_2]
          node_new_list_a = @t_hki_a_pos_new_list[hash_key_idx_2]
          # OPT this call can be inlined
          # keeped for readability
          fn = (lla, llb)=>
            # TODO opt no new token at hash_key (count before rule)
            for list_a,joint_pos in llb
              continue if list_a.length == 0
              list_b = lla[joint_pos]
              continue if list_b.length == 0
              for rule in rule_list
                # can opt in strict_rule_fn
                for a in list_a
                  for b in list_b
                    value_array = [a, b]
                    # PROD
                    continue if !rule.strict_rule_fn value_array
                    # DEBUG
                    # try
                      # res = rule.strict_rule_fn value_array
                    # catch err
                      # pp value_array[0]
                      # p rule.strict_rule_fn.toString()
                      # throw err
                    # continue if !res
                    #
                    new_node = new Node
                    new_node.value_view = "#{a.value or a.value_view} #{b.value or b.value_view}"
                    new_node.value_array = value_array
                    rule.mx_rule_fn value_array, new_node.mx_hash
                    new_node.mx_hash.hash_key = rule.ret_hash_key
                    new_node.hash_key_idx = rule.ret_hash_key_idx
                    new_node.a = a.a
                    new_node.b = b.b
                    @new_new_list.push new_node
            return
          if new_list_b_count
            fn node_old_list_a, node_new_list_b
          if new_list_a_count
            fn node_new_list_a, node_old_list_b
          if new_list_a_count and new_list_b_count
            fn node_new_list_a, node_new_list_b
      # R2L ничего не даст т.к. new_new_list
      
      # singles
      for rule_list, hash_key_idx in @rule_1_by_arg
        for node_list in @t_hki_a_pos_new_list[hash_key_idx]
          for rule in rule_list
            # can opt in strict_rule_fn
            for node in node_list
              value_array = [node]
              continue if !rule.strict_rule_fn value_array
              new_node = new Node
              new_node.value_view = node.value or node.value_view
              new_node.value_array = value_array
              rule.mx_rule_fn value_array, new_node.mx_hash
              new_node.mx_hash.hash_key = rule.ret_hash_key
              new_node.hash_key_idx = rule.ret_hash_key_idx
              new_node.a = node.a
              new_node.b = node.b
              @new_new_list.push new_node
      return ret if fin_collect()
      
      for hki in [0 ... max_hki]
        for pos in [0 .. max_idx]
          @t_hki_a_pos_old_list[hki][pos].append @t_hki_a_pos_new_list[hki][pos]
          @t_hki_a_pos_new_list[hki][pos].clear()
          @t_hki_b_pos_old_list[hki][pos].append @t_hki_b_pos_new_list[hki][pos]
          @t_hki_b_pos_new_list[hki][pos].clear()
      
      for node in @new_new_list
        @t_hki_a_pos_new_list[node.hash_key_idx][node.a].push node
        @t_hki_b_pos_new_list[node.hash_key_idx][node.b].push node
        @t_hki_a_pos_new_list[0][node.a].push node
        @t_hki_b_pos_new_list[0][node.b].push node
      
      if @new_new_list.length == 0
        # p "# ###################################################################################################"
        # pp @t_hki_a_pos_old_list
        @new_new_list.clear()
        fin_collect()
        return ret 
    
    throw new Error "magic_attempt_limit_mult exceed"
  
  go : (node_hypothesis_list, opt={})->
    opt.reemerge ?= true
    
    ret = @hypothesis_find node_hypothesis_list, opt
    if opt.reemerge
      walk = (tree)->
        for v in tree.value_array
          walk v
        
        if tree.mx_hash.is_proxy_rule
          [head, tail] = tree.value_array
          tree.value_array.clear()
          tree.value_array.append head.value_array
          tree.value_array.push tail
          
          str_list = []
          for v in tree.value_array
            str_list.push v.value or v.value_view
          tree.value_view = str_list.join ' '
        
        return
      
      for tree,k in ret
        walk tree
    
    ret
    
  
