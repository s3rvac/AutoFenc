" File:    AutoFenc.vim
" Brief:   Tries to automatically detect file encoding.
" Author:  Petr Zemek <s3rvac@gmail.com>
" Version: 1.5.1
"
" Description:
"   A Vim plugin that tries to automatically detect and set file encoding when
"   opening a file. See https://github.com/s3rvac/AutoFenc for more details.
"
" License:
"   Copyright (C) 2009-2014 Petr Zemek
"
"   This program is free software: you can redistribute it and/or modify it
"   under the terms of the GNU General Public License as published by the Free
"   Software Foundation, either version 2 of the License, or (at your option)
"   any later version.
"
"   This program is distributed in the hope that it will be useful, but WITHOUT
"   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
"   FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
"   more details.
"
"   You should have received a copy of the GNU General Public License
"   along with this program. If not, see <http://www.gnu.org/licenses/>.
"

" Check if the plugin was already loaded. Also, die gracefully if the used Vim
" version is too old.
if exists('autofenc_loaded') || v:version < 700
	finish
endif
" Make the loaded variable actually useful by including the version number.
let autofenc_loaded = '1.5.1'

" This plugin uses line continuations.
if &cpo =~ 'C'
	let s:oldcpo = &cpo
	set cpo-=C
endif

"-------------------------------------------------------------------------------
" Checks whether the selected variable (first parameter) is already set and
" if not, it sets it to the value of the second parameter.
"-------------------------------------------------------------------------------
function s:CheckAndSetVar(var, value)
	if !exists(a:var)
		exec 'let ' . a:var . ' = ' . string(a:value)
	endif
endfunction

" Configuration options initialization (see the script description for more
" information).
call s:CheckAndSetVar('g:autofenc_enable', 1)
call s:CheckAndSetVar('g:autofenc_emit_messages', 0)
call s:CheckAndSetVar('g:autofenc_max_file_size', 10485760)
call s:CheckAndSetVar('g:autofenc_disable_for_files_matching', '^[-_a-zA-Z0-9]\+://')
call s:CheckAndSetVar('g:autofenc_disable_for_file_types', [])
call s:CheckAndSetVar('g:autofenc_autodetect_bom', (&fileencodings !~# 'ucs-bom'))
call s:CheckAndSetVar('g:autofenc_autodetect_html', 1)
call s:CheckAndSetVar('g:autofenc_autodetect_html_filetypes', '^\(html.*\|xhtml\|aspperl\|aspvbs\|cf\|dtml\|gsp\|jsp\|mason\|php\|plp\|smarty\|spyce\|webmacro\)$')
call s:CheckAndSetVar('g:autofenc_autodetect_xml', 1)
call s:CheckAndSetVar('g:autofenc_autodetect_xml_filetypes', '^\(xml\|xquery\|xsd\|xslt\?\|ant\|dsl\|mxml\|svg\|wsh\|xbl\)$')
call s:CheckAndSetVar('g:autofenc_autodetect_css', 1)
call s:CheckAndSetVar('g:autofenc_autodetect_css_filetypes', '^\(css\|sass\)$')
call s:CheckAndSetVar('g:autofenc_autodetect_comment', 1)
call s:CheckAndSetVar('g:autofenc_autodetect_commentexpr', '\c^\A\(.*\s\)\?\(\(\(file\)\?en\)\?coding\|charset\)[:=]\?\s*\zs[-A-Za-z0-9_]\+')
call s:CheckAndSetVar('g:autofenc_autodetect_num_of_lines', 5)
call s:CheckAndSetVar('g:autofenc_autodetect_ext_prog', 1)
call s:CheckAndSetVar('g:autofenc_ext_prog_path', 'enca')
call s:CheckAndSetVar('g:autofenc_ext_prog_args', '-i -L czech')
call s:CheckAndSetVar('g:autofenc_ext_prog_unknown_fenc', '???')
call s:CheckAndSetVar('g:autofenc_enc_blacklist', '')

"-------------------------------------------------------------------------------
" Normalizes the selected encoding and returns it, so it can be safely used as
" a new encoding. This function should be called before a new encoding is set.
"-------------------------------------------------------------------------------
function s:NormalizeEncoding(enc)
	let nenc = tolower(a:enc)

	" The recent versions of the TOhtml runtime plugin have some nice charset
	" to encoding functions which even allow user overrides. Use them if
	" available.
	let nenc2 = ""
	silent! let nenc2 = tohtml#EncodingFromCharset(nenc)
	if nenc2 != ""
		return nenc2
	" If the TOhtml function is unavailable, at least handle some canonical
	" encoding names in Vim.
	elseif nenc =~ 'iso[-_]8859-1'
		return 'latin1'
	elseif nenc =~ 'iso[-_]8859-2'
		return 'latin2'
	elseif nenc ==? 'gb2312'
		return 'cp936' " GB2312 imprecisely means CP936 in HTML
	elseif nenc =~ '\(cp\|win\(dows\)\?\)-125\d'
		return 'cp125'.nenc[strlen(nenc)-1]
	elseif nenc == 'utf8'
		return 'utf-8'
	elseif g:autofenc_emit_messages && nenc !~ '^\%(8bit-\|2byte-\)\?\%(latin[12]\|utf-8\|utf-16\%(le\)\?\|ucs-[24]\%(le\)\?\|iso-8859-\d\{1,2}\|cp\d\{3,4}\)$'
		echomsg 'AutoFenc: detected unrecognized charset, trying fenc='.nenc
	endif

	return nenc
endfunction

"-------------------------------------------------------------------------------
" Sets the selected file encoding. Returns 1 if the file was reloaded,
" 0 otherwise.
"-------------------------------------------------------------------------------
function s:SetFileEncoding(enc)
	let nenc = s:NormalizeEncoding(a:enc)

	" Check whether we're not trying to set the current file encoding.
	if nenc != "" && nenc !=? &fenc
		if exists('&autochdir') && &autochdir
			" Other autocmds may have changed the window's working directory;
			" when 'autochdir' is set, the :edit will reset that, so
			" temporarily disable the setting.
			let old_autochdir = &autochdir
			set noautochdir
		endif
		try
			" Set the file encoding and reload it, keeping any user-specified
			" fileformat, and keeping any bad bytes in case the header is wrong
			" (this won't let the user save if a conversion error happened on
			" read).
			exec 'edit ++enc='.nenc.' ++ff='.&ff.' ++bad=keep'
		finally
			if exists('old_autochdir')
				let &autochdir = old_autochdir
			endif
		endtry

		" The file was reloaded.
		return 1
	else
		" The file was not reloaded.
		return 0
	endif
endfunction

"-------------------------------------------------------------------------------
" Tries to detect a BOM (byte order mark) at the beginning of the file to
" detect multibyte encodings. If there is a BOM, it returns the appropriate
" encoding, otherwise the empty string is returned.
"-------------------------------------------------------------------------------
function s:BOMEncodingDetection()
	" The implementation of this function is based on a part of the
	" FencsView.vim plugin by Ming Bai
	" (http://www.vim.org/scripts/script.php?script_id=1708).

	" Get the first line of the file.
	let file_content = readfile(expand('%:p'), 'b', 1)
	if file_content == []
		" Empty file
		return ''
	endif
	let first_line = file_content[0]

	" Check whether it contains BOM and if so, return appropriate encoding.
	" Note: If the index is out of bounds, ahx is set to '' automatically.
	let ah1 = first_line[0]
	let ah2 = first_line[1]
	let ah3 = first_line[2]
	let ah4 = first_line[3]
	" TODO: I don't know why but if there is a NUL byte, the char2nr() function
	"       transforms it to a newline (0x0A) instead of 0x00...
	let a1  = char2nr(ah1) == 0x0A ? 0x00 : char2nr(ah1)
	let a2  = char2nr(ah2) == 0x0A ? 0x00 : char2nr(ah2)
	let a3  = char2nr(ah3) == 0x0A ? 0x00 : char2nr(ah3)
	let a4  = char2nr(ah4) == 0x0A ? 0x00 : char2nr(ah4)
	if a1.a2.a3.a4 == 0x00.0x00.0xfe.0xff
		return 'utf-32'
	elseif a1.a2.a3.a4 == 0xff.0xfe.0x00.0x00
		return 'utf-32le'
	elseif a1.a2.a3 == 0xef.0xbb.0xbf
		return 'utf-8'
	elseif a1.a2 == 0xfe.0xff
		return 'utf-16'
	elseif a1.a2 == 0xff.0xfe
		return 'utf-16le'
	endif

	" There was no legal BOM.
	return ''
endfunction

"-------------------------------------------------------------------------------
" Tries the HTML way of encoding detection of the current file and returns the
" detected encoding (or the empty string, if the encoding was not detected).
"-------------------------------------------------------------------------------
function s:HTMLEncodingDetection()
	" This method is based on the meta tag in the head of the HTML document
	" (<meta http-equiv="Content-Type" ...).

	" Store the actual position in the file and move to the very first line
	" in the file.
	let curpos=getpos('.')
	keepjumps 1

	let enc = ''

	" The following regexp is a modified version of the regexp found here:
	" http://vim.wikia.com/wiki/Detect_encoding_from_the_charset_specified_in_HTML_files
	let charset_line = search('\c<meta\_s\+http-equiv=\([''"]\?\)Content-Type\1\_s\+content=\([''"]\)[A-Za-z]\+/[+A-Za-z]\+;\_s*charset=[-A-Za-z0-9_]\+\2', 'nc', g:autofenc_autodetect_num_of_lines)
	" If charset line was not found, try attributes in reverse order since
	" order is not actually important.
	if charset_line == 0
		let charset_line = search('\c<meta\_s\+content=\([''"]\)[A-Za-z]\+/[+A-Za-z]\+;\_s*charset=[-A-Za-z0-9_]\+\1\_s\+http-equiv=\([''"]\?\)Content-Type\2', 'nc', g:autofenc_autodetect_num_of_lines)
	endif
	" Detect in HTML version 5.
	if charset_line == 0
		let charset_line = search('\c<meta\_s\+charset=\([''"]\)[-A-Za-z0-9_]\+\1', 'nc', g:autofenc_autodetect_num_of_lines)
	endif
	if charset_line != 0
		let enc = matchstr(getline(charset_line), 'charset=\([''"]\)\?\zs[-A-Za-z0-9_]\+\ze\1')
	endif

	" Restore the original position in the file.
	call setpos('.', curpos)

	return enc
endfunction

"-------------------------------------------------------------------------------
" Tries the XML way of encoding detection of the current file and returns the
" detected encoding (or the empty string, if the encoding was not detected).
"-------------------------------------------------------------------------------
function s:XMLEncodingDetection()
	" The first part of this method is based on the first line of XML files
	" (<?xml version="..." encoding="..."?>)

	" Store the actual position in the file and move to the very first line in
	" the file.
	let curpos=getpos('.')
	keepjumps 1

	let enc = ''

	let charset_line = search('\c<?xml\s\+version="[.0-9]\+"\s\+encoding="[-A-Za-z0-9_]\+"', 'nc', g:autofenc_autodetect_num_of_lines)
	if charset_line != 0
		let enc = matchstr(getline(charset_line), 'encoding="\zs[-A-Za-z0-9_]\+')
	endif

	" Restore the original position in the file.
	call setpos('.', curpos)

	" If there was no encoding specified, return utf-8 (the check for BOM
	" should be done in another function - if the user wish that).
	return enc != '' ? enc : 'utf-8'
endfunction

"-------------------------------------------------------------------------------
" Tries the CSS way of encoding detection of the current file and returns the
" detected encoding (or the empty string, if the encoding was not detected).
"-------------------------------------------------------------------------------
function s:CSSEncodingDetection()
	" This method is based on the @charset 'at-rule'
	" (see http://www.w3.org/International/questions/qa-css-charset)

	" Store the actual position in the file and move to the very first line in
	" the file.
	let curpos=getpos('.')
	keepjumps 1

	let enc = ''

	" Note: The specs says that this line should be the first line in the file,
	"       but I'm searching every line in the file (some comments could
	"       perhaps precede the @charset in practice). If you don't like it,
	"       you are encouraged to change the code :).
	let charset_line = search('\c^\s*@charset\s\+"[-A-Za-z0-9_]\+"', 'nc', g:autofenc_autodetect_num_of_lines)
	if charset_line != 0
		let enc = matchstr(getline(charset_line), '^\s*@charset\s\+"\zs[-A-Za-z0-9_]\+')
	endif

	" Restore the original position in the file.
	call setpos('.', curpos)

	return enc
endfunction

"-------------------------------------------------------------------------------
" Tries to detect the encoding via encoding specified in a comment. The file is
" searched for a line like '# encoding: utf-8' and the file encoding is
" returned according to this line. If there is no such line, the empty string
" is returned.
"
" The default format of the comment that specifies encoding is some
" non-alphabetic characters at the beginning of the line, then 'charset'
" or '[[file]en]coding' (without quotes, case insensitive), which is followed
" by optional ':' (and whitespace) and the name of the encoding.
"-------------------------------------------------------------------------------
function s:CommentEncodingDetection()
	" Get first and last X lines from the file (according to the
	" configuration).
	let num_of_lines = g:autofenc_autodetect_num_of_lines
	let lines_to_search_enc = readfile(expand('%:p'), '', num_of_lines)
	let lines_to_search_enc += readfile(expand('%:p'), '', -num_of_lines)

	" Check all of the returned lines.
	for line in lines_to_search_enc
		let enc = matchstr(line, g:autofenc_autodetect_commentexpr)
		if enc != ''
			return enc
		endif
	endfor

	return ''
endfunction

"-------------------------------------------------------------------------------
" A safe version of shellescape. Use it instead of shellescape().
"-------------------------------------------------------------------------------
function s:SafeShellescape(path)
	try
		if exists('*shellescape')
			" On MS Windows, we need to disable the option shellslash before
			" calling shellescape() because otherwise, it may do stupid things
			" (see, e.g.,
			" http://vim.1045645.n5.nabble.com/shellescape-doesn-t-work-in-Windows-with-shellslash-set-td1211618.html).
			if has("win32") || has("win64")
				let old_ssl = &shellslash
				set noshellslash
			endif
			return shellescape(a:path)
		else
			" The shellescape({string}) function only exists since Vim 7.0.111.
			" Try to crudely support plain Vim 7.0, too.
			return '"'.substitute(a:path, '"', '\\"', 'g').'"'
		endif
	finally
		if exists('old_ssl')
			let &shellslash = old_ssl
		endif
	endtry
endfunction

"-------------------------------------------------------------------------------
" Tries to detect the file encoding via the selected external program. If the
" program is not executable or there is some error, it returns the empty
" string. Otherwise, the detected encoding is returned.
"-------------------------------------------------------------------------------
function s:ExtProgEncodingDetection()
	if executable(g:autofenc_ext_prog_path)
		" Get full path of the currently edited file.
		let file_path = expand('%:p')

		" Create the complete external program command by appending program
		" arguments and the current file path to the external program.
		let ext_prog_cmd = g:autofenc_ext_prog_path.' '.g:autofenc_ext_prog_args.' '.s:SafeShellescape(file_path)

		" Run it to get the encoding.
		let enc = system(ext_prog_cmd)
		if v:shell_error != 0
			" An error occurred.
			return ''
		endif

		" Remove trailing newline from the output (system() removes any \r from
		" the result automatically).
		let enc = substitute(enc, '\n', '', '')

		if enc != g:autofenc_ext_prog_unknown_fenc
			" The encoding was (probably) detected successfully.
			return enc
		endif
	endif

	return ''
endfunction

"-------------------------------------------------------------------------------
" Tries to detect encoding of the current file via several ways (according
" to the configuration) and returns it. If the encoding was not detected
" successfully, it returns the empty string - this can happen because:
"  - the file is in unknown encoding
"  - the file is not stored anywhere (e.g. a new file was opened)
"  - autodetection is disabled for this file (either the file is too large
"    or autodetection is disabled for this file, see configuration)
"-------------------------------------------------------------------------------
function s:DetectFileEncoding()
	" Check whether the autodetection should be performed (see function
	" description for more information).
	let file_path = expand('%:p')
	let file_size = getfsize(file_path)
	if file_path == '' ||
			\ file_size > g:autofenc_max_file_size || file_size < 0 ||
			\ file_path =~ g:autofenc_disable_for_files_matching ||
			\ index(g:autofenc_disable_for_file_types, &ft, 0, 1) != -1
		return ''
	endif

	" BOM encoding detection.
	if g:autofenc_autodetect_bom
		let enc = s:BOMEncodingDetection()
		if enc != ''
			return enc
		endif
	endif

	" HTML encoding detection.
	if g:autofenc_autodetect_html && &filetype =~? g:autofenc_autodetect_html_filetypes
		let enc = s:HTMLEncodingDetection()
		if enc != ''
			return enc
		endif
	endif

	" XML encoding detection.
	if g:autofenc_autodetect_xml && &filetype =~? g:autofenc_autodetect_xml_filetypes
		let enc = s:XMLEncodingDetection()
		if enc != ''
			return enc
		endif
	endif

	" CSS encoding detection.
	if g:autofenc_autodetect_css && &filetype =~? g:autofenc_autodetect_css_filetypes
		let enc = s:CSSEncodingDetection()
		if enc != ''
			return enc
		endif
	endif

	" Comment encoding detection.
	if g:autofenc_autodetect_comment
		let enc = s:CommentEncodingDetection()
		if enc != ''
			return enc
		endif
	endif

	" External program encoding detection.
	if g:autofenc_autodetect_ext_prog
		let enc = s:ExtProgEncodingDetection()
		if enc != ''
			return enc
		endif
	endif

	" The encoding was not detected.
	return ''
endfunction

"-------------------------------------------------------------------------------
" Main plugin function. Tries to autodetect the correct file encoding and sets
" the detected one (if any). If the ASCII encoding is detected, it does nothing
" so allow Vim to set its internal encoding instead.
"-------------------------------------------------------------------------------
function s:DetectAndSetFileEncoding()
	let enc = s:DetectFileEncoding()

	" Don't call again on the nested trigger from the edit.
	let b:autofenc_done = enc

	if (enc != '') && (enc !=? 'ascii') &&
			\ (g:autofenc_enc_blacklist == '' || enc !~? g:autofenc_enc_blacklist)
		if s:SetFileEncoding(enc)
			if g:autofenc_emit_messages
				echomsg "AutoFenc: Detected [".enc."] from file, loaded with fenc=".&fenc
			endif
		endif
	endif
endfunction

" Set the detected file encoding.
if g:autofenc_enable
	augroup AutoFenc
		au!
		" We need to check that we're not in the middle of a reload due to this
		" plugin otherwise can recurse forever. But unlet the variable to allow
		" re-detection on the next read of this buffer if it is just unloaded.
		au BufRead * nested
			\ if !exists('b:autofenc_done') |
			\   if v:cmdarg !~ '++enc' |
			\     call s:DetectAndSetFileEncoding() |
			\   endif |
			\ else |
			\   unlet b:autofenc_done |
			\ endif
	augroup END
endif

" Restore line continuations (and the rest of &cpo) when done.
if exists('s:oldcpo')
	let &cpo = s:oldcpo
	unlet s:oldcpo
endif

" vim: noet
