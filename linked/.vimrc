set ai " autoindent (filetype indenting instead)
set autoindent " copy indent from current line when starting new one
set copyindent " follow the conventions laid before us
set cursorline " highlight the current cursor line
set expandtab " expand tab to spaces
set gdefault " Add the g flag to search/replace by default
set ignorecase " ignore case when searching
set mat=5 " how many tenths of a second to blink matching brackets for
set mouse=a " allow mouse usage
set number " show line numbers
set relativenumber " show relative line numbers
set ruler " always show current positions along the bottom
set scrolloff=3 " start scolling three lines before the bottom
set shiftwidth=4 " unify
set showmatch " show matching brackets
set smartcase " if you include mixed case in a search, assumes you want case-sensitive
set tabstop=4 " real tabs should be 4, but they will show with set list on
set termguicolors "  true color terminal colors
set textwidth=88 " point at which text wraps
syntax on " syntax highlighting
autocmd BufWritePre * :%s/\s\+$//e " Strip trailing whitespace automatically

" Centralize backups, swapfiles and undo history
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
	set undodir=~/.vim/undo
endif

" yank to clipboard
if has("clipboard")
    set clipboard=unnamed " copy to the system clipboard
    if has("unnamedplus") " X11 support
        set clipboard+=unnamedplus
    endif
endif
