assert = require 'assert'
util = (require 'fy').test_util

{
  Gram_rule
  Gram
} = require '../src/rule'
{Node} = require '../src/node'

describe 'strict_rule section', ()->
  list = """
    #a
    #a[1]
    #a[1][1:2]
    $1
    $1==1
    $1==$2
    $1+$2
    $1|$2
    $1=="1"
    $1=='1'
    $1+1==$2
    !#a
    !$1
    #a.a
    $1.a
    #a[1:2]
    $1[1:2]
  """.split /\n/g
  for v in list
    do (v)->
      it "#{v} works", ()->
        rule = new Gram_rule
        rule.sequence = ["#a", "#b"]
        rule.hash_to_pos =
          a : [1]
          b : [2]
        rule.strict v
        rule._strict()
        return
  
  list = """
    #
    $
    #a[1
    #a[1 2]
    #a[2:1]
    #a=1
    "
    '
    =
    !
    #a.
    $3
    #c
    #c[1]
    #a[2]
  """.split /\n/g # "'
  for v in list
    do (v)->
      it "#{v} fails", ()->
        util.throws ()->
          rule = new Gram_rule
          rule.sequence = ["#a", "#b"]
          rule.hash_to_pos =
            a : [0]
            b : [1]
          rule.strict v
          rule._strict()
        return
  list = """
    #a
    #a 
     #a
     #a 
    #a #b
    #a #b 
     #a #b 
     #a  #b 
  """.split /\n/g
  for v in list
    do (v)->
      it "#{v} works", ()->
        rule = new Gram_rule
        rule.sequence = ["#a", "#b"]
        rule.hash_to_pos =
          a : [1]
          b : [2]
        rule.strict v
        rule._strict()
        return
  
  it 'check nop', ()->
    rule = new Gram_rule
    rule.sequence = ["#a"]
    rule.hash_to_pos =
      a : [1]
    
    assert rule.strict_rule_fn [new Node 'two']
  
  it 'check', ()->
    rule = new Gram_rule
    rule.sequence = ["#a"]
    rule.hash_to_pos =
      a : [1]
    rule.strict '$1=="one"'
    rule._strict()
    
    assert rule.strict_rule_fn [new Node 'one']
    assert !rule.strict_rule_fn [new Node 'two']
  
  hash = 
    '' : true
    '!$1==0' : true
    '!!$1' : true # true is not representable as number, so just avoid ==1
    '!!!$1==0' : true
    '$1==1' : true
    '$1[0:0]==1' : true
    '$1<=1' : true
    '$1>=1' : true
    '$1!=1' : false
    '$1<>1' : false
    '$1<1'  : false
    '$1>1'  : false
    '$1&&1'  : true
    '$1+1!=2'  : true # привет JS особенности. Пока implicit cast to int
    '+$1+1==2'  : true
    '$1-1==0'  : true
    '+$1-1==0'  : true
    '$1*2==2'  : true
    '2/$1==2'  : true
    '$1||2' : true
    '$1&&2' : true
    '$1&&0' : false
    # it's bool operator
    '$1|2' : true
    '$1&2' : true
    '$1|0' : true
    '$1&0' : false
  
  for k,v of hash
    do (k,v)->
      it "check #{k}", ()->
        rule = new Gram_rule
        rule.sequence = ["#a"]
        rule.hash_to_pos =
          a : [1]
        rule.strict k
        rule._strict()
        
        node = new Node '1'
        node.mx_hash.mx = 1
        
        assert.equal rule.strict_rule_fn([node]), v

  it "proper shift for strict rules and ?", ()->
    g = new Gram
    g.rule("ret", "#a? #b").mx("mx=#b").strict("#b=='2'")
    assert.equal g.initial_rule_list.length, 2
    
    node_a = new Node '1'
    node_a.mx_hash.hash_key = "a"
    
    node_b = new Node '2'
    node_b.mx_hash.hash_key = "b"
    
    [rule2, rule1] = g.initial_rule_list
      
    assert rule2.strict_rule_fn([node_a, node_b])
    assert rule1.strict_rule_fn([node_b])
    