local modulename = 'abtestingErrorInfo'
local _M = {}

_M._VERSION = '0.0.1'

_M.info = {
    --	index			    code    desc
    --	SUCCESS
    ["SUCCESS"]			= { 200,   'success '},
    
    --	System Level ERROR
    ['REDIS_ERROR']		= { 40101, 'redis error for '},
    ['POLICY_DB_ERROR']		= { 40102, 'policy in db error '},
    ['RUNTIME_DB_ERROR']	= { 40103, 'runtime info in db error '},
  
    ['LUA_RUNTIME_ERROR']	= { 40201, 'lua runtime error '},
    ['BLANK_INFO_ERROR']	= { 40202, 'errinfo blank in handler '},
    
    --	Service Level ERROR
    --	input or parameter error
    ['PARAMETER_NONE']		= { 50101, 'expected parameter for '},
    ['PARAMETER_ERROR']		= { 50102, 'parameter error for '},
    ['PARAMETER_NEEDED']	= { 50103, 'need parameter for '},
    ['PARAMETER_TYPE_ERROR']	= { 50104, 'parameter type error for '},
    
    --	input policy error
    ['POLICY_INVALID_ERROR']	= { 50201, 'policies invalid for ' },
    
    ['POLICY_BUSY_ERROR']	= { 50202, 'policy is busy and policyID is ' },
    
    --	redis connect error
    ['REDIS_CONNECT_ERROR']	= { 50301, 'redis connect error for '},
    ['REDIS_KEEPALIVE_ERROR']   = { 50302, 'redis keepalive error for '},
    
    --	runtime error
    ['POLICY_BLANK_ERROR']	= { 50401, 'policy contains no data '},
    ['RUNTIME_BLANK_ERROR']     = { 50402, 'expect runtime info for '},
    ['MODULE_BLANK_ERROR']	= { 50403, 'no required module for '},
    ['USERINFO_BLANK_ERROR']	= { 50404, 'no userinfo fetched from '},
    
    --  unknown reason
    ['UNKNOWN_ERROR']		= { 50501, 'unknown reason '},
}

return _M
