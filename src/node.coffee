require 'fy'
module = @
class @Node
  mx_hash       : {}
  hash_key_idx  : 0
  value         : ''
  value_view    : ''
  value_array   : []
  line          : -1
  pos           : -1
  a             : 0
  b             : 0
  
  constructor   : (value = '', mx_hash = {})->
    @mx_hash    = mx_hash
    @value      = value
    @value_array  = []
  
  cmp       : (t) ->
    for k,v of @mx_hash
      return false if v != t.mx_hash[k]
    return false if @value != t.value
    true
  
  name : (name)->
    ret = []
    for v in @value_array
      ret.push v if v.mx_hash.hash_key == name
    ret
  
  str_uid : ()->
    "#{@value} #{JSON.stringify @mx_hash}"
  
  clone : ()->
    ret = new module.Node
    for k,v of @
      continue if typeof v == 'function'
      ret[k] = clone v unless ret[k] == v
    ret
  
