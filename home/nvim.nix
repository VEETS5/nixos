{ config, pkgs, ... }:

{
  stylix.targets.nixvim.enable = true;
  programs.nixvim = {
    enable = true;

    extraPlugins = with pkgs.vimPlugins; [
      plenary-nvim
    ];

    # ── Options ───────────────────────────────────────────────────────────
    opts = {
      number         = true;
      relativenumber = true;
      shiftwidth     = 2;
      tabstop        = 2;
      expandtab      = true;
      smartindent    = true;
      wrap           = false;
      scrolloff      = 8;
      signcolumn     = "yes";
      cursorline     = true;
      termguicolors  = true;
      undofile       = true;
    };

    # ── Globals ───────────────────────────────────────────────────────────
    globals.mapleader = " ";

    # ── Keymaps ───────────────────────────────────────────────────────────
    keymaps = [
      # Better window navigation
      { mode = "n"; key = "<C-h>"; action = "<C-w>h"; }
      { mode = "n"; key = "<C-l>"; action = "<C-w>l"; }
      { mode = "n"; key = "<C-j>"; action = "<C-w>j"; }
      { mode = "n"; key = "<C-k>"; action = "<C-w>k"; }
      # Move lines up/down
      { mode = "v"; key = "J"; action = ":m '>+1<CR>gv=gv"; }
      { mode = "v"; key = "K"; action = ":m '<-2<CR>gv=gv"; }
      # Keep cursor centered
      { mode = "n"; key = "<C-d>"; action = "<C-d>zz"; }
      { mode = "n"; key = "<C-u>"; action = "<C-u>zz"; }
      # Telescope
      { mode = "n"; key = "<leader>ff"; action = "<cmd>Telescope find_files<cr>"; }
      { mode = "n"; key = "<leader>fg"; action = "<cmd>Telescope live_grep<cr>"; }
      { mode = "n"; key = "<leader>fb"; action = "<cmd>Telescope buffers<cr>"; }
      # LSP
      { mode = "n"; key = "gd"; action = "<cmd>lua vim.lsp.buf.definition()<cr>"; }
      { mode = "n"; key = "K";  action = "<cmd>lua vim.lsp.buf.hover()<cr>"; }
      { mode = "n"; key = "<leader>ca"; action = "<cmd>lua vim.lsp.buf.code_action()<cr>"; }
      { mode = "n"; key = "<leader>rn"; action = "<cmd>lua vim.lsp.buf.rename()<cr>"; }
      # Clear search highlight
      { mode = "n"; key = "<leader>h"; action = "<cmd>nohlsearch<cr>"; }
    ];

    # ── Plugins ───────────────────────────────────────────────────────────
    plugins = {
      extraPlugins = [ pkgs.vimPlugins.plenary-nvim ];
      # Treesitter
      treesitter = {
        enable = true;
        settings.highlight.enable = true;
        settings.indent.enable = true;
      };

      # Telescope
      telescope = {
        enable = true;
      };
      # Autopairs
      nvim-autopairs.enable = true;

      # Gitsigns
      gitsigns = {
        enable = true;
        settings.signs = {
          add.text          = "▎";
          change.text       = "▎";
          delete.text       = "";
          topdelete.text    = "";
          changedelete.text = "▎";
        };
      };

      # LSP
      lsp = {
        enable = true;
        servers = {
          rust_analyzer = {
            enable = true;
            installCargo = true;
            installRustc = true;
          };
          nixd.enable = true;
        };
      };

      # LSP completion
      cmp = {
        enable = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "buffer"; }
            { name = "path"; }
          ];
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>"     = "cmp.mapping.abort()";
            "<CR>"      = "cmp.mapping.confirm({ select = true })";
            "<Tab>"     = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            "<S-Tab>"   = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
          };
        };
      };

      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable   = true;
      cmp-path.enable     = true;

      # Lualine statusbar inside nvim
      lualine = {
        enable = true;
      };

      # Web devicons
      web-devicons.enable = true;
    };
  };
}
