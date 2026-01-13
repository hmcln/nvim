local M = {}

-- Toggle formatting per filetype. If a formatter is set, we only use that
-- client; otherwise we let Neovim pick from active LSPs.
M.format_on_save_filetypes = {
  lua = { enabled = true },
  cs = { enabled = false, formatter = "omnisharp" },
  javascript = { enabled = true },
  html = { enabled = true },
  rust = { enabled = true, formatter = "rust_analyzer" },
  nix = { enabled = true },
}

local function format_current_buffer(opts)
  local params = { async = false }
  if opts.formatter then
    params.filter = function(client) return client.name == opts.formatter end
  end
  if opts.bufnr then
    params.bufnr = opts.bufnr
  end
  vim.lsp.buf.format(params)
end

M.setup = function()
  -- Toggle format on save for the current buffer's filetype
  vim.api.nvim_create_user_command("ToggleFormatOnSave", function()
    local filetype = vim.bo.filetype
    local format_data = M.format_on_save_filetypes[filetype]
    if format_data == nil then
      vim.notify(
        "Format on save is not configured for filetype " .. filetype,
        vim.log.levels.INFO,
        { title = "Formatting" }
      )
      return
    end
    format_data.enabled = not format_data.enabled
    vim.notify(
      "Format on save for filetype " .. filetype .. " set to " .. tostring(format_data.enabled),
      vim.log.levels.INFO,
      { title = "Formatting" }
    )
  end, {})

  -- Save without triggering other autocmds, formatting first when configured
  vim.api.nvim_create_user_command("W", function()
    local format_data = M.format_on_save_filetypes[vim.bo.filetype]
    if format_data then
      format_current_buffer({ formatter = format_data.formatter })
    else
      vim.lsp.buf.format()
    end
    vim.cmd(":noautocmd w")
  end, {})
end

local group = vim.api.nvim_create_augroup("LspFormatting", {})
M.on_attach = function(client, bufnr)
  if not client.supports_method("textDocument/formatting") then
    return
  end

  vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    buffer = bufnr,
    callback = function()
      local format_data = M.format_on_save_filetypes[vim.bo.filetype]
      if format_data == nil or not format_data.enabled then
        return
      end
      format_current_buffer({ formatter = format_data.formatter, bufnr = bufnr })
    end,
  })
end

return M
