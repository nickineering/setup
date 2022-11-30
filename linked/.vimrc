set ai " autoindent (filetype indenting instead)
set cindent " do c-style indenting
set copyindent " but above all -- follow the conventions laid before us
set mat=5 " how many tenths of a second to blink matching brackets for
set nosi " smartindent (filetype indenting instead)
set number " show line numbers
set ruler " always show current positions along the bottom
set shiftwidth=4 " unify
set showmatch " show matching brackets
set softtabstop=4 " unify
set tabstop=4 " real tabs should be 4, but they will show with set list on
set textwidth=88
syntax on " syntax highlighting

" yank to clipboard
if has("clipboard")
    set clipboard=unnamed " copy to the system clipboard

    if has("unnamedplus") " X11 support
        set clipboard+=unnamedplus
    endif
endif
