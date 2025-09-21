---@class neotest-node._AdapterConfig
---@field filter_dirs? string[]

local async = require("neotest.async")
local lib = require("neotest.lib")

local base = require("neotest-node.base")

---@param config neotest-node._AdapterConfig
---@return neotest.Adapter
return function(config)
  ---@type neotest.Adapter
  return {
    name = "neotest-node",
    root = function(path) return lib.files.match_root_pattern("package.json")(path) end,
    filter_dir = function(name)
      local get_filter_dirs = base.get_filter_dirs

      if config.filter_dirs then
        get_filter_dirs = function() return config.filter_dirs end
      end

      for _, filter_dir in ipairs(get_filter_dirs()) do
        if name == filter_dir then
          return false
        end
      end

      return true
    end,
    is_test_file = function(file_path)
      if file_path == nil then
        return false
      end
      local is_test_file = false

      if string.match(file_path, "__tests__") then
        is_test_file = true
      end

      for _, x in ipairs({ "e2e", "spec", "test" }) do
        for _, ext in ipairs({ "js", "jsx", "coffee", "ts", "tsx" }) do
          if string.match(file_path, "%." .. x .. "%." .. ext .. "$") then
            is_test_file = true
            break
          end
        end
      end

      return is_test_file
    end,
    discover_positions = function(file_path)
      local query = [[
    ; -- Namespaces --
    ; Matches: `describe('context') / suite('context')`
    ((call_expression
      function: (identifier) @func_name (#any-of? @func_name "describe" "suite")
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition
    ; Matches: `describe.only('context') / suite.only('context')`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "describe" "suite")
      )
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition
    ; Matches: `describe.each(['data'])('context') / suite.each(['data'])('context')`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "describe" "suite")
        )
      )
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition

    ; -- Tests --
    ; Matches: `test('test') / it('test')`
    ((call_expression
      function: (identifier) @func_name (#any-of? @func_name "it" "test")
      arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
    )) @test.definition
    ; Matches: `test.only('test') / it.only('test')`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "test" "it")
      )
      arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
    )) @test.definition
    ; Matches: `test.each(['data'])('test') / it.each(['data'])('test')`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "it" "test")
        )
      )
      arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
    )) @test.definition
  ]]
      query = query .. string.gsub(query, "arrow_function", "function_expression")
      return lib.treesitter.parse_positions(file_path, query, { nested_tests = true })
    end,
    ---@param args neotest.RunArgs
    ---@return neotest.RunSpec
    build_spec = function(args)
      local file_path = args.tree:data().path
      local type = args.tree:data().type

      local command = {
        "node",
        "--test",
        "--test-reporter=tap",
        "--experimental-strip-types",
        "--experimental-transform-types",
        "--no-warnings=ExperimentalWarning",
      }

      if type == "test" then
        table.insert(command, "--test-name-pattern=" .. args.tree:data().name)
      end

      table.insert(command, file_path)

      ---@type neotest.RunSpec
      return {
        command = command,
        cwd = vim.fn.getcwd(),
        context = args.tree:data(),
      }
    end,
    ---@param spec neotest.RunSpec
    ---@param result_output neotest.StrategyResult
    ---@return neotest.Result[]
    results = function(spec, result_output)
      if not type(result_output) == "table" or not result_output.output then
        vim.notify("Unknown result_output structure: " .. vim.inspect(result_output), vim.log.levels.ERROR)
        return {}
      end

      local file_content = async.fn.readfile(result_output.output)

      if not file_content or #file_content == 0 then
        vim.notify("Test output is empty", vim.log.levels.ERROR)
        return {}
      end

      local results = {}
      local context_stack = {}
      local last_test_key = nil

      local errors = {}
      local is_error = false
      local error = {}

      for _, line in ipairs(file_content) do
        if is_error == false then
          if line:match("# Subtest:") then
            local padding, subtest_name = line:match("^(%s*)# Subtest: (.+)$")
            local padding_length = padding and #padding or 0
            local test_level = padding_length / 4 + 1

            if subtest_name then
              context_stack[test_level] = subtest_name
            end

            if last_test_key and results[last_test_key] and #errors > 0 then
              results[last_test_key].errors = errors
              errors = {}
            end

            if #context_stack > test_level then
              context_stack[#context_stack] = nil
            end
          elseif line:match("ok %d+") then
            local test_indent, test_status, test_name = line:match("^(%s*)(%w*%s*ok) %d+ %- (.+)$")

            if test_status and test_name then
              local status = test_status == "ok" and "passed" or "failed"
              local test_result_level = #test_indent / 4 + 1

              ---@diagnostic disable-next-line: unused-local
              local full_context = table.concat(context_stack, "::", 1, test_result_level)
              local test_key = spec.context.id
              results[test_key] = {
                status = status,
                short = test_name .. ": " .. test_status,
                output = result_output.output,
              }
              last_test_key = test_key
            end
          elseif line:match("error: |-") then
            is_error = true
          end
        end

        if is_error == true then
          if line:match("TestContext") and is_error then
            local line_number = line:match("TestContext.*:(%d+):%d+%)")
            error.line = line_number
          elseif line:match("code: ") or line:match("%.%.%.") then
            is_error = false
            table.insert(errors, error)
            error = {}
          elseif not line:match("error: |-") then
            local initial_message = ""
            if error.message then
              initial_message = error.message
            end
            local new_message = line:match("^%s+(.+)")
            error.message = initial_message .. "\n" .. new_message
          end
        end
      end

      return results
    end,
  }
end
