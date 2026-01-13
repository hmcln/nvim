local M = {}

M.load = function(client, bufnr)
  local map = vim.keymap.set

  local function lsp_map(provider, mode, lhs, rhs, desc, opts)
    local options = { buffer = bufnr, silent = true, desc = desc }
    if opts then
      options = vim.tbl_extend("force", options, opts)
    end

    if client.server_capabilities[provider] then
      map(mode, lhs, rhs, options)
    else
      map(mode, lhs, function()
        vim.notify(
          ("Server does not support %s"):format(provider),
          vim.log.levels.WARN,
          { title = client.name }
        )
      end, options)
    end
  end

  lsp_map("definitionProvider", "n", "gd", vim.lsp.buf.definition, "LSP symbol definition")
  lsp_map("typeDefinitionProvider", "n", "go", vim.lsp.buf.type_definition, "LSP symbol type definition")
  lsp_map("implementationProvider", "n", "gm", vim.lsp.buf.implementation, "LSP symbol implementation")
  lsp_map("referencesProvider", "n", "gr", vim.lsp.buf.references, "LSP symbol references")
  lsp_map("signatureHelpProvider", "n", "gh", vim.lsp.buf.signature_help, "LSP signature help")
  lsp_map("codeActionProvider", "n", "ga", vim.lsp.buf.code_action, "LSP code action")
  lsp_map("renameProvider", "n", "<leader>rn", vim.lsp.buf.rename, "LSP rename symbol")

  map("n", "gD", vim.diagnostic.setqflist, { buffer = bufnr, silent = true, desc = "LSP open diagnostics list" })
  map("n", "gl", vim.diagnostic.open_float, { buffer = bufnr, silent = true, desc = "LSP show line diagnostics" })
  map("n", "]d", vim.diagnostic.goto_next, { buffer = bufnr, silent = true, desc = "LSP goto next diagnostic" })
  map("n", "[d", vim.diagnostic.goto_prev, { buffer = bufnr, silent = true, desc = "LSP goto previous diagnostic" })
end

return M
