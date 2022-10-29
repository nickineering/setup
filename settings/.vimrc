set number " show line numbers
syntax on " syntax highlighting
set ruler " always show current positions along the bottom
set showmatch " show matching brackets
set mat=5 " how many tenths of a second to blink matching brackets for

" yank to clipboard
if has("clipboard")
  set clipboard=unnamed " copy to the system clipboard

  if has("unnamedplus") " X11 support
    set clipboard+=unnamedplus
  endif
endif


set ai " autoindent (filetype indenting instead)
set nosi " smartindent (filetype indenting instead)
set cindent " do c-style indenting
set softtabstop=4 " unify
set shiftwidth=4 " unify
set tabstop=4 " real tabs should be 4, but they will show with set list on
set copyindent " but above all -- follow the conventions laid before us
" wrap lines at 120 chars. 80 is somewhat antiquated with nowadays displays.
set textwidth=88
