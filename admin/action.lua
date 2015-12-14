local policy    = require('adminPolicy')
local runtime   = require('adminRuntime')

local test = function()
    ngx.say("hello world")
end

local getPolicyId = function()
end

local getPolicy = function()
end

local ab_action = {}

ab_action.policy_set    = policy.set
ab_action.policy_get    = policy.get
ab_action.policy_del    = policy.del
ab_action.policy_check  = policy.check

ab_action.runtime_set   = runtime.set
ab_action.runtime_get   = runtime.get
ab_action.runtime_del   = runtime.del

ab_action.test          = policy.test

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
    if(ab_action[action]) then
        local file = ab_action[action]
        file()
    end
else

end
