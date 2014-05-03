AutoFenc
========

A Vim plugin that tries to automatically detect and set file encoding when
opening a file.

Description
-----------

This Vim plugin tries to automatically detect and set file encoding when
opening a file. It does this in several possible ways, depending on the
configuration.

The following methods are implemented. When a method fails, the plugin tries
the next one.

1. detection of BOM (byte-order-mark) at the beginning of the file, only for
   some multibyte encodings
2. HTML way of encoding detection (via the `<meta>` tag), only for HTML-based
   file types
3. XML way of encoding detection (via the `<?xml ... ?>` declaration), only for
   XML-based file types
4. CSS way of encoding detection (via `@charset 'at-rule'`), only for CSS files
5. checks whether the encoding is specified in a comment (like `# Encoding:
   latin2`), for all file types
6. tries to detect the encoding via the specified external program (the default
   one is [enca](https://github.com/nijel/enca)), for all file types

If the autodetection fails, it is up to Vim and your configuration to set the
encoding.

Installation
------------

The recommended way of installing this plugin is by using
[Pathogen](https://github.com/tpope/vim-pathogen).

If you cannot use Pathogen or you want to install this plugin manually, just
put the `plugin/AutoFenc.vim` file into your `$HOME/.vim/plugin` directory
(Linux-like systems) or `%UserProfile%\vimfiles\plugin` folder (Windows
systems).

Configuration Options
---------------------

The plugin has the following configuration options. You can set them in your
`$HOME/.vimrc` file.

- `g:autofenc_enable` (0 or 1, default 1)

  Enables/disables this plugin.

- `g:autofenc_emit_messages` (0 or 1, default 0)

  Emits messages about the detected/used encoding upon opening a file.

- `g:autofenc_max_file_size` (number >= 0, default 10485760)

  If the size of a file is higher than this value (in bytes), then the
  autodetection will not be performed.

- `g:autofenc_disable_for_files_matching` (regular expression, see the settings
  in `plugin/AutoFenc.vim`)

  If the file (with complete path) matches this regular expression, then the
  autodetection will not be performed. It is by default set to disable
  autodetection for non-local files (e.g. accessed via ftp or scp) because the
  script cannot handle some kind of autodetection for these files. The regular
  expression is matched case-sensitively.

- `g:autofenc_disable_for_file_types` (list of strings, default `[]`)

  If the file type matches some of the filetypes specified in this list, then
  the autodetection will not be performed. The comparison is done
  case-sensitively.

- `g:autofenc_autodetect_bom` (0 or 1, default 0 if `ucs-bom` is in
  `fileencodings`, 1 otherwise)

  Enables/disables detection of encoding by BOM.

- `g:autofenc_autodetect_html` (0 or 1, default 1)

  Enables/disables detection of encoding for HTML-based documents.

- `g:autofenc_autodetect_html_filetypes` (regular expression, see the settings
  in `plugin/AutoFenc.vim`)

  Regular expression for all supported HTML file types.

- `g:autofenc_autodetect_xml` (0 or 1, default 1)

  Enables/disables detection of encoding for XML-based documents.

- `g:autofenc_autodetect_xml_filetypes` (regular expression, see the settings
  in `plugin/AutoFenc.vim`)

  Regular expression for all supported XML file types.

- `g:autofenc_autodetect_css` (0 or 1, default 1)

  Enables/disables detection of encoding for CSS documents.

- `g:autofenc_autodetect_css_filetypes` (regular expression, see the settings
  in `plugin/AutoFenc.vim`)

  Regular expression for all supported CSS file types.

- `g:autofenc_autodetect_comment` (0 or 1, default 1)

  Enables/disables detection of encoding in comments.

- `g:autofenc_autodetect_commentexpr` (regular expression, see the settings in
  `plugin/AutoFenc.vim`)

  Pattern for detection of encodings specified in a comment.

- `g:autofenc_autodetect_num_of_lines` (number >= 0, default 5)

  How many lines from the beginning and from the end of the file should be
  searched for the possible encoding declaration.

- `g:autofenc_autodetect_ext_prog` (0 or 1, default 1)

  Enables/disables detection of encoding via an external program (see
  additional settings below).

- `g:autofenc_ext_prog_path` (string, default `'enca'`)

  Path to the external program. It can be either a relative or absolute path.
  The external program can take any number of arguments, but the last one has
  to be a path to the file for which the encoding is to be detected (it will be
  supplied by this plugin). The output of the program has to be the name of the
  encoding in which the file is saved (a string on a single line).

- `g:autofenc_ext_prog_args` (string, default `'-i -L czech'`)

  Additional program arguments (can be none, i.e. `''`).

- `g:autofenc_ext_prog_unknown_fenc` (string, default `'???'`)

  If the output of the external program is this string, then it means that the
  file encoding was not detected successfully. The string has to be
  case-sensitive.

- `g:autofenc_enc_blacklist` (regular expression, default `''`)

  If the detected encoding matches this regular expression, it will be ignored.

Requirements
------------

The `filetype` plugin has to be be enabled (a line like `filetype plugin on`
has to be in your `$HOME/.vimrc` (Linux-like systems) or `%UserProfile%\_vimrc`
(Windows systems).

Notes
-----

This script is by all means NOT perfect, but it works for me and suits my needs
very well, so it might be also useful for you. Your feedback, opinion,
suggestions, bug reports, patches, simply anything you have to say is welcomed!

There are similar plugins to this one, so if you do not like this one, you can
test these:

* [FencView.vim](http://www.vim.org/scripts/script.php?script_id=1708):
     Mainly supports detection of encodings for asian languages.
* [MultiEnc.vim](http://www.vim.org/scripts/script.php?script_id=1806):
     Obsolete, merged with the previous one.
* [charset.vim](http://www.vim.org/scripts/script.php?script_id=199):
     Not very complete/correct and last update in 2002.
* [Detect encoding from the charset specified in HTML
  files](http://vim.wikia.com/wiki/Detect_encoding_from_the_charset_specified_in_HTML_files):
     Same basic ideas but only for HTML files.

Let me know if there are others and I will add them here.

License
-------

Copyright (c) 2009-2014 Petr Zemek <s3rvac@gmail.com>

Distributed under GNU GPLv2:

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation, either version 2 of the License, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
    more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
