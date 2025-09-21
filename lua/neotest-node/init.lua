local create_adapter = require("neotest-node.adapter")

---@class neotest-node.AdapterConfig
---@field filter_dirs? string[]

---@param config neotest-node.AdapterConfig
local augment_config = function(config)
  ---@type neotest-node._AdapterConfig
  return {
    filter_dirs = config.filter_dirs,
  }
end

---@class neotest.Adapter
local NodeNeotestAdapter = create_adapter(augment_config({}))

setmetatable(NodeNeotestAdapter, {
  ---@overload fun(config: neotest-node.AdapterConfig): neotest.Adapter
  __call = function(config) return create_adapter(augment_config(config)) end,
})

return NodeNeotestAdapter
