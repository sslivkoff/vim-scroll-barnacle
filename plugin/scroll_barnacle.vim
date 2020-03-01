
" vim-scroll-barnacle

" plugin to add scrollbar to terminal vim windows


" add scrollbar to current window
function SBAddScrollbar()

    call SBInitializeWindowState()

    if exists("w:_sb_has_scrollbar") && w:_sb_has_scrollbar
        return
    endif

    " check for underflow
    if winheight(0) >= line("$") && w:sb_window_behavior == "overflow"
        let w:_sb_off_because_underflow = 1
        return
    endif

    " create contents of scrollbar
    let contents = SBCreateContents()

    " create window
    let w:scrollbuf = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_lines(w:scrollbuf, 0, -1, v:true, contents)
    let opts = {
        \ "relative": "win",
        \ "width": 1,
        \ "height": (winheight(0) - 0),
        \ "col": (winwidth(0) - 1),
        \ "row": 0,
        \ "focusable": g:sb_patch_mouse,
        \ "anchor": "NW",
        \ "style": "minimal"}
    let w:win = nvim_open_win(w:scrollbuf, 0, opts)

    " configure window
    call nvim_win_set_option(w:win, "winhl", "Normal:ScrollbarBar")
    let window = nvim_get_current_win()
    let g:_sb_scrollbar_windows[window] = w:win
    call nvim_set_current_win(w:win)
    set filetype=scrollbar
    let w:original_window = window
    syntax match ScrollBlockBottom /[ ▁▂▃▄▅▆▇█]r/
    highlight ScrollBlockBottom gui=reverse
    call nvim_set_current_win(window)
    let w:_sb_has_scrollbar = 1

endfunction


" create scrollbar contents
function SBCreateContents()

    let n_window_lines = winheight(0)
    let window_lower_bound = line("w0") - 1
    let window_upper_bound = line("w$") - 1
    let lines_per_block = (line("$")) / (winheight(0) + 0.0)

    if g:sb_bar_style == "solid"
        let n_subblocks_per_block = 8
        let min_subblocks = 8
        let upper_block_glyphs = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        let lower_block_glyphs = ["█r", "▇r", "▆r", "▅r", "▄r", "▃r", "▂r", "▁r", " r"]
        let subblock_glyphs = []
    elseif g:sb_bar_style == "double dot"
        let n_subblocks_per_block = 4
        let min_subblocks = 1
        let upper_block_glyphs = [" ", "⣀", "⣤", "⣶", "⣿"]
        let lower_block_glyphs = [" ", "⠉", "⠛", "⠿", "⣿"]
        let subblock_glyphs = [[], ["⠉", "⠒", "⠤", "⣀"], ["⠛", "⠶", "⣤"], ["⠿", "⣶"], ["⣿"]]
    elseif g:sb_bar_style == "left dot"
        let n_subblocks_per_block = 4
        let min_subblocks = 1
        let upper_block_glyphs = [" ", "⡀", "⡄", "⡆", "⡇"]
        let lower_block_glyphs = [" ", "⠁", "⠃", "⠇", "⡇"]
        let subblock_glyphs = [[], ["⠁", "⠂", "⠄", "⡀"], ["⠃", "⠆", "⡄"], ["⠇", "⡆"], ["⡇"]]
    elseif g:sb_bar_style == "right dot"
        let n_subblocks_per_block = 4
        let min_subblocks = 1
        let upper_block_glyphs = [" ", "⢀", "⢠", "⢰", "⢸"]
        let lower_block_glyphs = [" ", "⠈", "⠘", "⠸", "⢸"]
        let subblock_glyphs = [[], ["⠈", "⠐", "⠠", "⢀"], ["⠘", "⠰", "⢠"], ["⠸", "⢰"], ["⢸"]]
    else
        echoerr "unkown scrollbar style: " . string(g:sb_bar_style)
    endif

    let fill_glyph = upper_block_glyphs[-1]

    let n_total_blocks = winheight(0)
    let n_total_subblocks = n_total_blocks * n_subblocks_per_block
    let n_subblocks = (window_upper_bound - window_lower_bound + 1) * n_total_subblocks / (line("$") + 0.0)
    let n_subblocks = float2nr(round(n_subblocks))
    if n_subblocks < min_subblocks
        let n_subblocks = min_subblocks
    endif

    let float_first_block = (line("w0") - 1) / lines_per_block
    let float_first_subblock = float_first_block * n_subblocks_per_block
    let int_first_subblock = float2nr(round(float_first_subblock))
    let int_last_subblock = int_first_subblock + n_subblocks - 1
    let int_first_block = float2nr(floor(int_first_subblock / (n_subblocks_per_block + 0.0)))
    let int_last_block = float2nr(floor(int_last_subblock / (n_subblocks_per_block + 0.0)))
    let subblocks_in_first_block = n_subblocks_per_block - int_first_subblock % n_subblocks_per_block
    let subblocks_in_last_block = 1 + int_last_subblock % n_subblocks_per_block

    let contents = []
    let b = 0
    while b < n_total_blocks
        if b < int_first_block
            " empty
            let contents = contents + [" "]
        elseif b == int_first_block && b == int_last_block
            " subblock
            if len(subblock_glyphs) == 0
                " no subblock rendering
                let contents = contents + [fill_glyph]
            else
                " subblock rendering
                let first_subblock_in_block = n_subblocks_per_block - subblocks_in_first_block
                let glyph = subblock_glyphs[n_subblocks][first_subblock_in_block]
                let contents = contents + [glyph]
            endif
        elseif b == int_first_block
            " top block
            let contents = contents + [upper_block_glyphs[subblocks_in_first_block]]
        elseif int_first_block < b && b < int_last_block
            " middle block
            let contents = contents + [fill_glyph]
        elseif b == int_last_block
            " bottom block
            let contents = contents + [lower_block_glyphs[subblocks_in_last_block]]
        elseif b > int_last_block
            " empty
            let contents = contents + [" "]
        endif

        let b = b + 1
    endwhile

    return contents
endfunction


" remove scrollbar from current window
function SBRemoveScrollbar()
    if exists("w:_sb_has_scrollbar") && w:_sb_has_scrollbar
        call nvim_win_close(w:win, 1)
        unlet g:_sb_scrollbar_windows[string(nvim_get_current_win())]
    endif
    let w:_sb_has_scrollbar = 0
endfunction


" remove scrollbars that became orphaned when vim windows closed
function SBRemoveOrphanScrollbars()
    let all_windows = nvim_list_wins()
    for win_pair in items(g:_sb_scrollbar_windows)
        if index(all_windows, str2nr(win_pair[0])) < 0
            call nvim_win_close(win_pair[1], 1)
            unlet g:_sb_scrollbar_windows[win_pair[0]]
        endif
    endfor
endfunction


" return whether current window has a scrollbar
function SBHasScrollbar()
    " disable functionality if using tabs, see README.md
    if g:_sb_tab_disabled
        return 0
    end

    return exists("w:_sb_has_scrollbar") && w:_sb_has_scrollbar
endfunction


" redraw scrollbar contents, this is main function to update scrollbar
function SBRedrawScrollbar()
    if &filetype == "scrollbar"
        return
    endif

    " check for underflow
    if winheight(0) >= line("$")
        call SBRemoveScrollbar()
        let w:_sb_off_because_underflow = 1

    " check for overflow
    elseif exists("w:_sb_off_because_underflow")
        \ && w:_sb_off_because_underflow
        \ && winheight(0) < line("$")
        call SBAddScrollbar()
        let w:_sb_off_because_underflow = 0

    " redraw existing scrollbar
    elseif SBHasScrollbar()
        let new_contents = SBCreateContents()
        call nvim_buf_set_lines(w:scrollbuf, 0, -1, 0, new_contents)
        call nvim_win_set_cursor(w:win, [1, 0])
    endif
endfunction


" reset scrollbar, used when window has changed size
function SBResetScrollbar()
    if SBHasScrollbar()
        call SBRemoveScrollbar()
        call SBAddScrollbar()
    endif
endfunction


" toggle scrollbar on or off
function SBToggleScrollbar()
    if SBHasScrollbar()
        call SBRemoveScrollbar()
    elseif exists("w:_sb_off_because_underflow")
        \ && w:_sb_off_because_underflow
        let w:_sb_window_behavior = "always"
        call SBAddScrollbar()
    else
        call SBAddScrollbar()
    endif
endfunction


" patch keys whose scrolling actions cannot be detected by vim events
function SBPatchKeys()
    " use `<C-o>` in insert mode shortcuts to temporarily leave insert mode
    " add `gv` after visual mode shortcuts to restore selection

    nmap <silent> zz zz:call SBRedrawScrollbar()<cr>
    vmap <silent> zz zz:call SBRedrawScrollbar()<cr>gv
    nmap <silent> zt zt:call SBRedrawScrollbar()<cr>
    vmap <silent> zt zt:call SBRedrawScrollbar()<cr>gv
    nmap <silent> zb zb:call SBRedrawScrollbar()<cr>
    vmap <silent> zb zb:call SBRedrawScrollbar()<cr>gv
    nmap <silent> <C-e> <C-e>:call SBRedrawScrollbar()<cr>
    vmap <silent> <C-e> <C-e>:call SBRedrawScrollbar()<cr>gv
    nmap <silent> <C-y> <C-y>:call SBRedrawScrollbar()<cr>
    vmap <silent> <C-y> <C-y>:call SBRedrawScrollbar()<cr>gv

    nmap <silent> <ScrollWheelUp> <ScrollWheelUp>:call SBRedrawScrollbar()<cr>
    nmap <silent> <ScrollWheelDown> <ScrollWheelDown>:call SBRedrawScrollbar()<cr>
    imap <silent> <ScrollWheelUp> <ScrollWheelUp><C-o>:call SBRedrawScrollbar()<cr>
    imap <silent> <ScrollWheelDown> <ScrollWheelDown><C-o>:call SBRedrawScrollbar()<cr>
    vmap <silent> <ScrollWheelUp> <ScrollWheelUp>:call SBRedrawScrollbar()<cr>gv
    vmap <silent> <ScrollWheelDown> <ScrollWheelDown>:call SBRedrawScrollbar()<cr>gv
endfun


" move window according to where scrollbar is clicked
function SBHandleMouseClick()
    if &filetype == "scrollbar"
        let scrollblock = line(".") - 1
        call nvim_set_current_win(w:original_window)
        let lines_per_block = (line("$")) / (winheight(0) + 0.0)
        let new_line = scrollblock * lines_per_block
        let new_line = float2nr(round(new_line) + 1)
        exec(":" . string(new_line))
        call feedkeys("zt")
    endif
endfun


" patch mouse clicks to manipulate scrollbar
function SBPatchMouse()
    nnoremap <silent> <LeftMouse> <LeftMouse>:call SBHandleMouseClick()<cr>
endfun


" initialize window's scrollbar configuration state
function SBInitializeWindowState()
    if !exists("w:_sb_initialized") || !w:_sb_initialized
        let w:_sb_initialized = 1
        if g:sb_default_behavior == "always" || g:sb_default_behavior == "overflow"
            let w:sb_window_behavior = g:sb_default_behavior
            call SBAddScrollbar()
        endif
    end
endfunction


"
" " tab functionality
"

let g:_sb_tab_disabled = 0


" disable functionality if using tabs, see README.md
function SBDisableForTabs()
    let g:sb_default_behavior = "never"

    for win_pair in items(g:_sb_scrollbar_windows)
        call nvim_win_close(win_pair[1], 1)
    endfor
    let g:_sb_scrollbar_windows = {}

    if !g:_sb_tab_disabled
        echon "vim-scroll-barnacle disabled for tabs (see README.md)"
    endif

    let g:_sb_tab_disabled = 1
endfunction


"
" " initialize plugin
"

" neovim only
if has('nvim')

    " set defaults
    if !exists("g:sb_default_behavior")
        let g:sb_default_behavior = "overflow"
    end
    if !exists("g:sb_bar_style")
        let g:sb_bar_style = "solid"
    end
    if !exists("g:sb_patch_keys")
        let g:sb_patch_keys = 1
    end
    if !exists("g:sb_patch_mouse")
        let g:sb_patch_mouse = 1
    end
    if !exists("g:_sb_scrollbar_windows")
        let g:_sb_scrollbar_windows = {}
    end

    " patch keys and mouse
    if g:sb_patch_keys
        call SBPatchKeys()
    endif
    if g:sb_patch_mouse
        call SBPatchMouse()
    endif

    " set commands
    command ScrollbarOn call SBAddScrollbar()
    command ScrollbarOff call SBRemoveScrollbar()
    command ScrollbarToggle call SBToggleScrollbar()

    " set autocmds
    augroup scroll_barnacle
        autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI,InsertLeave,FileChangedShellPost,BufEnter * call SBRedrawScrollbar()
        autocmd VimResized * call SBResetScrollbar()
        autocmd WinEnter * call SBRemoveOrphanScrollbars()
        autocmd WinEnter,BufWinEnter * call SBInitializeWindowState()
        autocmd WinLeave * call SBRedrawScrollbar()

        " disable functionality if using tabs, see README.md
        autocmd TabLeave * call SBDisableForTabs()
    augroup end
else
    echo "vim-scroll-barnacle only available in neovim"
endif

