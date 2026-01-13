local function nix_enabled()
  return os.getenv("NIX_NEOVIM") == "1"
end

local function build_on_attach(base_on_attach)
  return function(client, bufnr)
    if base_on_attach then
      base_on_attach(client, bufnr)
    end
    require("plugins.lsp.formatting").on_attach(client, bufnr)
    require("plugins.lsp.mappings").load(client, bufnr)
    require("lsp_signature").on_attach({
      max_height = 100,
      max_width = 120,
      doc_lines = 100,
      floating_window = false,
      hint_enable = false,
      hint_prefix = "󰅲 ",
      toggle_key = "<C-s>",
    }, bufnr)
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

return {
  -- Disable Mason on Nix; keep it elsewhere
  {
    "mason-org/mason.nvim",
    enabled = not nix_enabled(),
    opts = {
      ui = { border = "rounded" },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    enabled = not nix_enabled(),
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "ray-x/lsp_signature.nvim",
      {
        "JManch/ltex_extra.nvim",
        branch = "file_watcher",
      },
      "hrsh7th/cmp-nvim-lsp",
    },
    opts = function(_, opts)
      vim.lsp.set_log_level("OFF")
      require("lspconfig.ui.windows").default_options.border = "rounded"
      require("plugins.lsp.diagnostics").setup()
      require("plugins.lsp.formatting").setup()

      opts.servers = opts.servers or {}
      opts.setup = opts.setup or {}
      opts.servers["*"] = opts.servers["*"] or {}

      local capabilities =
        require("cmp_nvim_lsp").default_capabilities(opts.servers["*"].capabilities or {})
      opts.servers["*"].capabilities = capabilities

      local on_attach = build_on_attach(opts.on_attach)
      opts.on_attach = on_attach

      local servers = require("plugins.lsp.servers").servers(on_attach, capabilities)

      if nix_enabled() then
        -- Skip Mason entirely; set up servers directly and prevent LazyVim from touching them
        opts.mason = false
        for name, setup in pairs(servers) do
          opts.servers[name] = opts.servers[name] or {}
          opts.setup[name] = function()
            setup()
            return true -- signal LazyVim to skip default setup
          end
        end
      else
        -- Non-Nix: still use Mason, but reuse our server configs where defined
        for name, setup in pairs(servers) do
          opts.servers[name] = opts.servers[name] or {}
          opts.setup[name] = setup
        end
      end

      return opts
    end,
  },
}
