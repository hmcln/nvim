return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    dap.defaults.fallback.exception_breakpoints = { "uncaught" }

    for _, adapterType in ipairs({ "node", "chrome", "msedge" }) do
      local pwaType = "pwa-" .. adapterType

      dap.adapters[pwaType] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "node",
          args = {
            vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
            "${port}",
          },
        },
      }

      -- this allow us to handle launch.json configurations
      -- which specify type as "node" or "chrome" or "msedge"
      dap.adapters[adapterType] = function(cb, config)
        local nativeAdapter = dap.adapters[pwaType]

        config.type = pwaType

        if type(nativeAdapter) == "function" then
          nativeAdapter(cb, config)
        else
          cb(nativeAdapter)
        end
      end
    end

    local enter_launch_url = function()
      local co = coroutine.running()
      return coroutine.create(function()
        vim.ui.input({ prompt = "Enter URL: ", default = "http://localhost:" }, function(url)
          if url == nil or url == "" then
            return
          else
            coroutine.resume(co, url)
          end
        end)
      end)
    end

    for _, language in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact", "vue" }) do
      dap.configurations[language] = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch file using Node.js (nvim-dap)",
          program = "${file}",
          cwd = "${workspaceFolder}",
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to process using Node.js (nvim-dap)",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
        },
        -- requires ts-node to be installed globally or locally
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch file using Node.js with ts-node/register (nvim-dap)",
          program = "${file}",
          cwd = "${workspaceFolder}",
          runtimeArgs = { "-r", "ts-node/register" },
        },
        {
          type = "pwa-chrome",
          request = "launch",
          name = "Launch Chrome (nvim-dap)",
          url = enter_launch_url,
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
          runtimeArgs = { "-enable-features=UseOzonePlatform --ozone-platform=wayland" },
        },
        {
          type = "pwa-msedge",
          request = "launch",
          name = "Launch Edge (nvim-dap)",
          url = enter_launch_url,
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
        },
      }
    end

    table.insert(dap.configurations.python, {
      type = "python",
      request = "attach",
      name = "Attach to Docker",
      host = function()
        local value = vim.fn.input("Host [127.0.0.1]: ")
        if value ~= "" then
          return value
        end
        return "127.0.0.1"
      end,
      port = function()
        return tonumber(vim.fn.input("Port [5678]: ")) or 5678
      end,
      pathMappings = {
        {
          localRoot = function()
            local value = vim.fn.input("Local Root [cwd]: ")
            if value ~= "" then
              return value
            end
            return vim.fn.getcwd()
          end,
          remoteRoot = function()
            local value = vim.fn.input("Remote Root [/]: ")
            if value ~= "" then
              return value
            end
            return "/"
          end,
        },
      },
    })

    table.insert(dap.configurations.python, {
      type = "python",
      request = "attach",
      name = "AROS - Attach to Docker Container (port 5677)",
      host = "localhost",
      port = 5677,
      pathMappings = {
        {
          localRoot = vim.fn.getcwd() .. "/backend/src", -- Your local path
          remoteRoot = "/aros/src", -- Path inside the container
        },
      },
    })

    dap.adapters.coreclr = {
      type = "executable",
      command = "C:/Users/sfree/AppData/Local/nvim-data/mason/packages/netcoredbg/netcoredbg/netcoredbg.exe",
      args = { "--interpreter=vscode" },
    }

    local dotnet_build_project = function()
      local default_path = vim.fn.getcwd() .. "/"

      if vim.g["dotnet_last_proj_path"] ~= nil then
        default_path = vim.g["dotnet_last_proj_path"]
      end

      local path = vim.fn.input("Path to your *proj file", default_path, "file")

      vim.g["dotnet_last_proj_path"] = path

      local cmd = "dotnet build -c Debug " .. path .. " > /dev/null"

      print("")
      print("Cmd to execute: " .. cmd)

      local f = os.execute(cmd)

      if f == 0 then
        print("\nBuild: ✔️ ")
      else
        print("\nBuild: ❌ (code: " .. f .. ")")
      end
    end

    local dotnet_get_dll_path = function()
      local request = function()
        return vim.fn.input("Path to dll to debug: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
      end

      if vim.g["dotnet_last_dll_path"] == nil then
        vim.g["dotnet_last_dll_path"] = request()
      else
        if vim.fn.confirm("Change the path to dll?\n" .. vim.g["dotnet_last_dll_path"], "&yes\n&no", 2) == 1 then
          vim.g["dotnet_last_dll_path"] = request()
        end
      end

      return vim.g["dotnet_last_dll_path"]
    end

    dap.configurations.cs = {
      {
        type = "coreclr",
        name = "Launch - coreclr (nvim-dap)",
        request = "launch",
        program = function()
          if vim.fn.confirm("Rebuild first?", "&yes\n&no", 2) == 1 then
            dotnet_build_project()
          end

          return dotnet_get_dll_path()
        end,
      },
    }

    local convertArgStringToArray = function(config)
      local c = {}

      for k, v in pairs(vim.deepcopy(config)) do
        if k == "args" and type(v) == "string" then
          c[k] = require("dap.utils").splitstr(v)
        else
          c[k] = v
        end
      end

      return c
    end

    for key, _ in pairs(dap.configurations) do
      dap.listeners.on_config[key] = convertArgStringToArray
    end

    dap.listeners.before.attach.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.launch.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated.dapui_config = function()
      dapui.close()
    end
    dap.listeners.before.event_exited.dapui_config = function()
      dapui.close()
    end

    vim.keymap.set("n", "<Leader>dt", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
    vim.keymap.set("n", "<Leader>dbc", dap.clear_breakpoints, { desc = "Clear all breakpoints" })
    vim.keymap.set("n", "<Leader>dbl", dap.list_breakpoints, { desc = "Clear all breakpoints" })

    local continue = function()
      -- support for vscode launch.json is partial.
      -- not all configuration options and features supported
      if vim.fn.filereadable(".vscode/launch.json") then
        require("dap.ext.vscode").getconfigs()
      end
      dap.continue()
    end

    vim.keymap.set("n", "<Leader>dc", continue, { desc = "Continue" })
  end,
}
