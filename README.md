# neotest-node

Adapter for [neotest](https://github.com/nvim-neotest/neotest) framework to use [Node.js](https://nodejs.org/api/test.html#test-runner) native test runner.

## Setup

### Native Neovim Package Manager (0.12+)


```lua
vim.pack.add({
  "https://github.com/nvim-neotest/neotest",
  "https://github.com/nvim-neotest/nvim-nio",
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/devastion/neotest-node",
}, { confirm = false })

require("neotest").setup({
  adapters = {
    require("neotest-node"),
  },
})
```

### `lazy.nvim`

```lua
return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "devastion/neotest-node"
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-node")
      }
    })
  end
}
```

## Roadmap

- [ ] Support `only` tests
- [ ] Create `nvim-dap` configuration

## Credits

- [Nelfimov/neotest-node-test-runner](https://github.com/Nelfimov/neotest-node-test-runner)
