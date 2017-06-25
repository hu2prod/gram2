assert = require 'assert'
util = (require 'fy').test_util

{
  Gram
} = require '../src/rule'
{Node} = require '../src/node'
simple_tok = (str)->
  list = []
  for v in str.split /\s+/g
    node = new Node
    node.mx_hash.hash_key = '*'
    node.value = v
    list.push [node]
  list

describe 'gram_rule section', ()->
  hash_kv =
    "a" : {
      rule_count  : 1
      arg_count   : 1
      hash_to_pos : {}
    }
    "a a" : {
      rule_count  : 1
      arg_count   : 2
      hash_to_pos : {}
    }
    "#a" : {
      rule_count  : 1
      arg_count   : 1
      hash_to_pos : {
        a : [0]
      }
    }
    "#a a" : {
      rule_count  : 1
      arg_count   : 2
      hash_to_pos : {
        a : [0]
      }
    }
    "#a #a" : {
      rule_count  : 1
      arg_count   : 2
      hash_to_pos : {
        a : [0,1]
      }
    }
    "#a #b" : {
      rule_count  : 1
      arg_count   : 2
      hash_to_pos : {
        a : [0]
        b : [1]
      }
    }
    "a|a" : {
      rule_count  : 2
      arg_count   : 1
      hash_to_pos : {}
    }
    "#a a|a" : {
      rule_count  : 2
      arg_count   : 2
      hash_to_pos : {
        a : [0]
      }
    }
    "#a|#b" : "throw"
    
    "a a?" : {
      rule_count  : 2
      arg_count   : 2
      hash_to_pos : {}
    }
    
    "a?" : {
      rule_count  : 1
      arg_count   : 1
      hash_to_pos : {}
    }
    
  for k,v of hash_kv
    do (k,v)->
      it "'#{k}' works", ()->
        g = new Gram
        if v == "throw"
          util.throws ()->
            g.rule 'ret', k
          return
        
        proxy = g.rule 'ret', k
        
        if v.rule_count
          assert.equal g.initial_rule_list.length, v.rule_count
          
          rule = g.initial_rule_list[0]
          
          assert.equal rule.sequence.length, v.arg_count
          util.json_eq rule.hash_to_pos, v.hash_to_pos
        
        # minimal coverage
        proxy.mx('mx=1')
        proxy.strict('1==1')
        
        return
  
  describe "rule split", ()->
    it 'rule length 1', ()->
      g = new Gram
      g.rule 'ret', 'a'
      g.optimize()
      
      sum = 0
      for list in g.rule_1_by_arg
        sum += list.length
      assert.equal sum, 1
      
      sum = 0
      for list in g.rule_2_by_arg
        sum += list.length
      assert.equal sum, 0
    
    it 'rule length 2', ()->
      g = new Gram
      g.rule 'ret', 'a b'
      g.optimize()
      
      sum = 0
      for list in g.rule_1_by_arg
        sum += list.length
      assert.equal sum, 0
      
      sum = 0
      for list in g.rule_2_by_arg
        sum += list.length
      assert.equal sum, 1
    
    it 'rule length 1,2', ()->
      g = new Gram
      g.rule 'ret', 'a b?'
      g.optimize()
      
      sum = 0
      for list in g.rule_1_by_arg
        sum += list.length
      assert.equal sum, 1
      
      sum = 0
      for list in g.rule_2_by_arg
        sum += list.length
      assert.equal sum, 1
    
    it 'rule length 3', ()->
      g = new Gram
      g.rule 'ret', 'a b c'
      g.optimize()
      util.json_eq g.hash_key_list, ['*', "ret", "proxy_a,b_0"]
      
      sum = 0
      for list in g.rule_1_by_arg
        sum += list.length
      assert.equal sum, 0
      
      list_concat = []
      for list in g.rule_2_by_arg
        list_concat.append list
      assert.equal list_concat.length, 2
      
      [rule_head, rule_tail] = list_concat
      util.json_eq rule_head.sequence, ['a', 'b']
      assert.equal rule_head.ret_hash_key, "proxy_a,b_0"
      
      util.json_eq rule_tail.sequence, ['#proxy_a,b_0', 'c']
      assert.equal rule_tail.ret_hash_key, "ret"
      # pp rule_tail
      
      
      node_a = new Node 'a'
      node_b = new Node 'b'
      node_c = new Node 'c'
      
      assert rule_head.strict_rule_fn([node_a,node_b])
      assert !rule_head.strict_rule_fn([node_b]) # вернёт false на первой проверке, до второй не дойдет
      util.throws ()-> # упадёт на второй проверке
        rule_head.strict_rule_fn([node_a])
      
      node_head = new Node
      # rule_head.mx_rule_fn([node_a,node_b], node_head.mx_hash)
      test_hash = {}
      rule_head.mx_rule_fn([node_a,node_b], test_hash)
      assert.equal h_count(test_hash), 0
      
      # node_head.mx_hash.hash_key = 'proxy_a,b_0'
      
      # Прим. Оно даже не должно смотреть на arg_list[0] т.к. его не должно быть в проверке
      # Проверка на hash_key вынесена из strict'а намеренно т.к. должна выполняться на уровне merge_pair
      assert rule_tail.strict_rule_fn([null,node_c])
      # asset rule_tail.strict_rule_fn([node_head,node_c])
    
  describe "rules 1 length", ()->
    it 'zero-rule', ()->
      gram = new Gram
      res = gram.go simple_tok('result')
      assert.equal res.length, 1
      assert.equal res[0].value, 'result'
    
    it 'zero-rule optimize coverage', ()->
      gram = new Gram
      res = gram.go simple_tok('result')
      res = gram.go simple_tok('result')
      assert.equal res.length, 1
      assert.equal res[0].value, 'result'
    
    it 'zero-rule mode_full', ()->
      gram = new Gram
      res = gram.go simple_tok('result'), mode_full : true
      assert.equal res.length, 1
      assert.equal res[0].value, 'result'
    
    it 'invalid expected_token', ()->
      gram = new Gram
      util.throws ()->
        res = gram.go simple_tok('result'),
          mode_full     : true
          expected_token: 'a'
      return
    
    it 'sample', ()->
      gram = new Gram
      gram.rule('sample', 'result')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 2
      assert.equal res[0].value, 'result'
      
      assert.equal res[1].mx_hash.hash_key, 'sample'
      assert.equal res[1].value_view, 'result'
      assert.equal res[1].value_array[0].value, 'result'
    
    it 'sample expected_token', ()->
      gram = new Gram
      gram.rule('sample', 'result')
      res = gram.go simple_tok('result'),
        expected_token : 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'result'
      assert.equal res[0].value_array[0].value, 'result'
    
    it 'sample mode_full expected_token', ()->
      gram = new Gram
      gram.rule('sample', 'result')
      res = gram.go simple_tok('result'),
        mode_full : true
        expected_token : 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'result'
      assert.equal res[0].value_array[0].value, 'result'
    
    it 'mx_hash match reject', ()->
      gram = new Gram
      gram.rule('sample', 'result').strict('$1.a==2')
      tok_list = simple_tok('result')
      tok_list[0][0].mx_hash.a = 1
      res = gram.go tok_list,
        mode_full : true
        expected_token : 'sample'
      
      assert.equal res.length, 0
   
    it 'mx_hash match pass', ()->
      gram = new Gram
      gram.rule('sample', 'result').strict('$1.a==1')
      tok_list = simple_tok('result')
      tok_list[0][0].mx_hash.a = 1
      res = gram.go tok_list,
        mode_full : true
        expected_token : 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'result'
      assert.equal res[0].value_array[0].value, 'result'
    
    it 'mx_hash.hash_key match pass', ()->
      gram = new Gram
      gram.rule('sample', '#a')
      tok_list = simple_tok('result')
      tok_list[0][0].mx_hash.hash_key = 'a'
      res = gram.go tok_list,
        mode_full : true
        expected_token : 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'result'
      assert.equal res[0].value_array[0].value, 'result'
    
    it 'mx_hash.hash_key match reject', ()->
      gram = new Gram
      gram.rule('sample', '#a').strict('0')
      tok_list = simple_tok('result')
      tok_list[0][0].mx_hash.hash_key = 'a'
      res = gram.go tok_list,
        mode_full : true
        expected_token : 'sample'
      
      assert.equal res.length, 0
    
    it 'nest 1', ()->
      gram = new Gram
      gram.rule('sample', '#a')
      gram.rule('a', 'result')
      res = gram.go simple_tok('result'),
        expected_token : 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'result'
      # assert.equal res[0].value_array[0].value_view, 'result'
    
    it 'nest 1 with strict', ()->
      gram = new Gram
      gram.rule('sample', '#a') .strict('#a.test==test')
      gram.rule('a', 'result') .mx('test=test')
      res = gram.go simple_tok('result'),
        expected_token : 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'result'
      # assert.equal res[0].value_array[0].value_view, 'result'
    
    it 'nest 1 with strict[1]', ()->
      gram = new Gram
      gram.rule('sample', '#a') .strict('#a[1].test==test')
      gram.rule('a', 'result') .mx('test=test')
      res = gram.go simple_tok('result'),
        expected_token : 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'result'
      # assert.equal res[0].value_array[0].value_view, 'result'
  
  # coverage reasons
  describe "rules 1 length dedupe", ()->
    it 'sample rule dedupe', ()->
      gram = new Gram
      gram.rule('sample', 'result')
      gram.rule('sample', 'result')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 2
    
    it 'sample rule dedupe mx', ()->
      gram = new Gram
      gram.rule('sample', 'result').mx('a=1')
      gram.rule('sample', 'result').mx('a=1')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 2
    
    it 'sample rule false dedupe mx length', ()->
      gram = new Gram
      gram.rule('sample', 'result')
      gram.rule('sample', 'result').mx('a=1')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 3
    
    it 'sample rule false dedupe mx autoassign', ()->
      gram = new Gram
      gram.rule('sample', 'result').mx('a')
      gram.rule('sample', 'result').mx('b=1')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 3
    
    it 'sample rule false dedupe mx key', ()->
      gram = new Gram
      gram.rule('sample', 'result').mx('a=1')
      gram.rule('sample', 'result').mx('b=1')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 3
    
    it 'sample rule false dedupe mx touch', ()->
      gram = new Gram
      gram.rule('sample', 'result').mx('a=$1')
      gram.rule('sample', 'result').mx('a=1')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 3
    
    it 'sample rule false dedupe mx val', ()->
      gram = new Gram
      gram.rule('sample', 'result').mx('a=1')
      gram.rule('sample', 'result').mx('a=2')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 3
    
    it 'sample rule dedupe strict', ()->
      gram = new Gram
      gram.rule('sample', 'result').strict('1==1')
      gram.rule('sample', 'result').strict('1==1')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 2
    
    it 'sample rule false dedupe strict', ()->
      gram = new Gram
      gram.rule('sample', 'result')
      gram.rule('sample', 'result').strict('1==1')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 3
    
    it 'sample rule false dedupe strict touch', ()->
      gram = new Gram
      gram.rule('sample', 'result').strict('$1')
      gram.rule('sample', 'result').strict('1')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 3
    
    it 'sample rule false dedupe strict val', ()->
      gram = new Gram
      gram.rule('sample', 'result').strict('1==1')
      gram.rule('sample', 'result').strict('2==2')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 3
    
    it 'sample rule dedupe?', ()->
      gram = new Gram
      gram.rule('sample', 'result?')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 2
    
    it 'sample rule dedupe base+?', ()->
      gram = new Gram
      gram.rule('sample', 'result')
      gram.rule('sample', 'result a?')
      res = gram.go simple_tok('result'), mode_full : true
      
      assert.equal res.length, 2
  
  describe "rules 2 length", ()->
    
    it 'sample expected_token', ()->
      gram = new Gram
      gram.rule('sample', 'a b')
      res = gram.go simple_tok('a b'),
        expected_token : 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value, 'a'
      assert.equal res[0].value_array[1].value, 'b'
  
  describe "rules 3 length", ()->
    
    it 'a b c', ()->
      gram = new Gram
      gram.rule('sample', 'a b c')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value, 'a'
      assert.equal res[0].value_array[0].value_array[1].value, 'b'
      assert.equal res[0].value_array[1].value, 'c'
    
    it 'P b c', ()->
      gram = new Gram
      gram.rule('sample', '#p b c')
      gram.rule('p', 'a')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value_view, 'a'
      assert.equal res[0].value_array[0].value_array[1].value, 'b'
      assert.equal res[0].value_array[1].value, 'c'
    
    it 'a P c', ()->
      gram = new Gram
      gram.rule('sample', 'a #p c')
      gram.rule('p', 'b')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value, 'a'
      assert.equal res[0].value_array[0].value_array[1].value_view, 'b'
      assert.equal res[0].value_array[1].value, 'c'
    
    it 'a b P', ()->
      gram = new Gram
      gram.rule('sample', 'a b #p')
      gram.rule('p', 'c')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value, 'a'
      assert.equal res[0].value_array[0].value_array[1].value, 'b'
      assert.equal res[0].value_array[1].value_view, 'c'
    # ###################################################################################################
    
    it 'P b c', ()->
      gram = new Gram
      gram.rule('sample', '#p b c').strict('#p.test==a')
      gram.rule('p', 'a').mx('test=a')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value_view, 'a'
      assert.equal res[0].value_array[0].value_array[1].value, 'b'
      assert.equal res[0].value_array[1].value, 'c'
    
    it 'a P c', ()->
      gram = new Gram
      gram.rule('sample', 'a #p c').strict('#p.test==a')
      gram.rule('p', 'b').mx('test=a')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value, 'a'
      assert.equal res[0].value_array[0].value_array[1].value_view, 'b'
      assert.equal res[0].value_array[1].value, 'c'
    
    it 'a b P', ()->
      gram = new Gram
      gram.rule('sample', 'a b #p').strict('#p.test==a')
      gram.rule('p', 'c').mx('test=a')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value, 'a'
      assert.equal res[0].value_array[0].value_array[1].value, 'b'
      assert.equal res[0].value_array[1].value_view, 'c'
    # ###################################################################################################
    
    it 'P b P [1]', ()->
      gram = new Gram
      gram.rule('sample', '#p b #p').strict('#p[1].test==1')
      gram.rule('p', 'a').mx('test=1')
      gram.rule('p', 'c').mx('test=2')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value_view, 'a'
      assert.equal res[0].value_array[0].value_array[1].value, 'b'
      assert.equal res[0].value_array[1].value_view, 'c'
    
    it 'P b P [2]', ()->
      gram = new Gram
      gram.rule('sample', '#p b #p').strict('#p[2].test==2')
      gram.rule('p', 'a').mx('test=1')
      gram.rule('p', 'c').mx('test=2')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
        reemerge      : false
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value_view, 'a b'
      assert.equal res[0].value_array[0].value_array[0].value_view, 'a'
      assert.equal res[0].value_array[0].value_array[1].value, 'b'
      assert.equal res[0].value_array[1].value_view, 'c'
    
  describe "rules 3 length reemerge", ()->
    
    it 'a b c', ()->
      gram = new Gram
      gram.rule('sample', 'a b c')
      res = gram.go simple_tok('a b c'),
        expected_token: 'sample'
      
      assert.equal res.length, 1
      assert.equal res[0].mx_hash.hash_key, 'sample'
      assert.equal res[0].value_view, 'a b c'
      assert.equal res[0].value_array[0].value, 'a'
      assert.equal res[0].value_array[1].value, 'b'
      assert.equal res[0].value_array[2].value, 'c'
  
  describe "priority bin_op", ()->
    gram = new Gram
    gram.rule('bin_op',  '*|/|%')             .mx('priority=5')
    gram.rule('bin_op',  '+|-')               .mx('priority=6')
    
    base_priority = -9000
    gram.rule('expr',  '( #expr )')           .mx("priority=#{base_priority}")
    
    # gram.rule('expr',  '#expr #bin_op') .mx('priority=#bin_op.priority')       .strict('#expr[1]') # OK
    # gram.rule('expr',  '#expr #bin_op #expr') .mx('priority=#bin_op.priority')       .strict('#expr') # OK
    # gram.rule('expr',  '#expr #bin_op #expr') .mx('priority=#bin_op.priority')       .strict('#expr[1].priority<#bin_op.priority #expr[2].priority<1') # FAIL
    # gram.rule('expr',  '#expr #bin_op #expr') .mx('priority=#bin_op.priority')       .strict('#expr[1].priority<#bin_op.priority 1<#bin_op.priority') # OK
    gram.rule('expr',  '#expr #bin_op #expr') .mx('priority=#bin_op.priority')       .strict('#expr[1].priority<#bin_op.priority #expr[2].priority<#bin_op.priority') # FAIL
    gram.rule('expr',  '#expr #bin_op #expr') .mx('priority=#bin_op.priority')       .strict('#expr[1].priority<#bin_op.priority #expr[2].priority==#bin_op.priority #bin_op.left_assoc')
    
    gram.rule('expr',  'a|b|c')               .mx('priority=-9000')
    
    it 'a', ()->
      res = gram.go simple_tok('a'),
        expected_token: 'expr'
      
      assert.equal res.length, 1
      assert.equal res[0].value_view, 'a'
    
    it 'a + b', ()->
      res = gram.go simple_tok('a + b'),
        expected_token: 'expr'
      
      assert.equal res.length, 1
      assert.equal res[0].value_view, 'a + b'
    
    it 'a + b * c', ()->
      res = gram.go simple_tok('a + b * c'),
        expected_token: 'expr'
      
      assert.equal res.length, 1
      assert.equal res[0].value_view, 'a + b * c'
      assert.equal res[0].value_array[0].value_view, 'a'
      assert.equal res[0].value_array[2].value_view, 'b * c'
    
    it 'a * b + c', ()->
      res = gram.go simple_tok('a * b + c'),
        expected_token: 'expr'
      
      assert.equal res.length, 1
      assert.equal res[0].value_view, 'a * b + c'
      assert.equal res[0].value_array[0].value_view, 'a * b'
      assert.equal res[0].value_array[2].value_view, 'c'

    