local policyModule  = require('abtesting.adapter.policy')
local redisModule   = require('abtesting.utils.redis')
local systemConf    = require('abtesting.utils.init')
local handler       = require('abtesting.error.handler').handler
local utils         = require('abtesting.utils.utils')
local ERRORINFO     = require('abtesting.error.errcode').info

local cjson         = require('cjson.safe')
local doresp        = utils.doresp
local dolog         = utils.dolog

local redisConf     = systemConf.redisConf
local divtypes      = systemConf.divtypes
local prefixConf    = systemConf.prefixConf
local policyLib     = prefixConf.policyLibPrefix
local runtimeLib    = prefixConf.runtimeInfoPrefix
local domain_name   = prefixConf.domainname


local policy    = require("admin/policy")
local runtime   = require('admin/runtime')
local ab_action = {}

ab_action.policy_check  = policy.check
ab_action.policy_set    = policy.set
ab_action.policy_get    = policy.get
ab_action.policy_del    = policy.del

ab_action.runtime_set   = runtime.set
ab_action.runtime_del   = runtime.del
ab_action.runtime_get   = runtime.get

local get_uriargs_error = function()
    local info = ERRORINFO.ACTION_BLANK_ERROR
    local response = doresp(info, 'user req')
    dolog(info, desc)
    ngx.say(response)
    return 
end

local get_action_error = function()
    local info = ERRORINFO.ACTION_BLANK_ERROR
    local response = doresp(info, 'user req')
    dolog(info, desc)
    ngx.say(response)
    return 
end

local do_action_error = function()
    local info = ERRORINFO.DOACTION_ERROR
    local desc = action
    local response = doresp(info, desc)
    dolog(info, desc)
    ngx.say(response)
    return
end

local red = redisModule:new(redisConf)
local ok, err = red:connectdb()
if not ok then
    local info = ERRORINFO.REDIS_CONNECT_ERROR
    local response = doresp(info, err)
    dolog(info, desc)
    ngx.say(response)
    return
end

local args = ngx.req.get_uri_args()
if args then
    local action = args.action
    local do_action = ab_action[action]
    if do_action then
        do_action({['db']=red})
--        local ok, info = do_action(policy, {['db']=red})
--        if not ok then
--            do_action_error()
--        end
    else
        doaction_error()
    end
else
    get_uriargs_error()
end
