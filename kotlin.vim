
" By BingLi224
"
" Kotlin Tools
"
" The compilation errors will be added to the source code with notation:
" 	// :ERR:
"
" To add jar or paths for compilation in the source code, type in:
" 	// :CP: <path>
" for example:
"	// :CP:	C:\Workspace\lib\pack1.jar
"	// :CP:	C:\Workspace\lib\pack2.jar
"
" Prerequisites:
" + "kotlin.bat" and "kotlinc.bat" path
" + "java.exe| path
"
" 14:50 THA 19/08/2018
"
" Initial.
"
" 01:41 THA 01/10/2018
"
" Fix the error notation
"
" 18:58 THA 14/10/2018
"
" Fix the error notation
" Add the -cp for compilation from notations in souce code

" set class path
if ! exists ( "t:classpath" )
	"	let t:classpath = t:classpath . ";" . expand ( '%:p:h' )
	"else
	let t:classpath = expand ( '%:p:h' )
endif

function! SetPaths ( )
	" set src path
	"if !exists ( "t:srcpath" )
		let t:srcpath = expand ( '%:p:h' )
	"endif

	" set default class path
	"if !exists ( "t:classpath" )
		let t:classpath = expand ( '%:p:h' )
	"endif

	" set default class name
	"if !exists ( "t:classname" )
		let t:classname = expand ( '%:t:r' )
	"endif
	
	" remember current line
	let current_pos = getpos ( '.' )

	let pos = searchpos ( "^\\s\*package\\s" )
	" !! assume that the pattern is "^package [name];"
	let t:package = matchstr ( getline ( pos[0] ), '[^;]\+', pos[1] + 7 )
	let t:dir = ''
	
	if t:package != ''
		" chdir to the root

		let fpath = split ( t:classpath, "[\\\/]" )
		let cpath = split ( t:package, '\.' )
		let b_found_path = 0
		if len ( cpath ) < len ( fpath ) && len ( cpath ) > 0
			let b_found_path = 1
			for idx in range ( 0, len ( cpath ) - 1 )
				if cpath[ idx ] !=? fpath[ idx + len ( fpath ) - len ( cpath ) ]
					let b_found_path = 0
					break
				endif
			endfor
		endif

		if b_found_path != 0
			" change the dir of t:classpath
			let t:dir = join ( fpath[ 0 : len ( fpath ) - len ( cpath ) - 1 ], '\' )
			echo t:classpath . "Added classpath: " . t:dir
			let t:classpath = t:dir . ';' . t:classpath
		endif

		" set the full classname
		let t:classname = t:package . '.' . t:classname
	endif

	" find extra -cp
	let pos = searchpos ( "\/\/\\s*:CP:\\s\\+\\S" )
	while pos[ 0 ] > 0
		if ! exists ( "first_pos" )
			" remember first match
			let first_pos = pos
		elseif first_pos[ 0 ] == pos[ 0 ] && first_pos[ 1 ] == pos[ 1 ]
			" end of search
			break
		endif
		
		" add the -cp
		let t:classpath .= ";" . matchstr ( getline ( pos[0] ), ':CP:\s\+\zs\S\+\ze' )
		echo "Add -cp " . matchstr ( getline ( pos[0] ), ':CP:\s\+\zs\S\+\ze' )

		" find next one
		let pos = searchpos ( "\/\/\\s*:CP:\\s\\+\\S" )
	endwhile
	
	" change from / \ to .
	let t:classname = substitute ( substitute ( t:classname, "//", '.', 'g' ), "\/", '.', 'g' )

	echo "srcp=\t" . t:srcpath . "\nclassp=\t" . t:classpath . "\nclassn=\t" . t:classname . "\nt:package=\t" . t:package . "\nt:dir=\t" . t:dir . "\n"

	" return to current working line
	":exe current_pos
	:call setpos( '.', current_pos )
endfunction

" Compile current Kt file to Jar
function! KotlinCompile2Jar ( )
	" save the current file
	:w

	" set dir to this file
	"l`=t:srcpath`
	" compile this file
	" exec \":!kotlinc.bat \" . expand ( \"%:t\" )

	:call SetPaths ( )

	echo "====== getcwd ================\n"
	echo getcwd ( )
	cd `=t:srcpath`
	if exists ( t:dir ) && t:dir != ""
		let t:kt_result = system( "kotlinc.bat -jvm-target 1.8 -cp " . t:classpath . " " . expand ( "%:t" ) . " -include-runtime -d " . t:dir . "/" . t:classname . ".jar" )
		echo "kotlinc.bat -jvm-target 1.8 -cp " . t:classpath . " " . expand ( "%:t" ) . " -include-runtime -d " . t:dir . "/" . t:classname . ".jar"
	else
		let t:kt_result = system( "kotlinc.bat -jvm-target 1.8 -cp " . t:classpath . " " . expand ( "%:t" ) . " -include-runtime -d " . t:classname . ".jar" )
		echo "kotlinc.bat -jvm-target 1.8 -cp " . t:classpath . " " . expand ( "%:t" ) . " -include-runtime -d " . t:classname . ".jar"
	endif

	" show error(s) into the source code file
	let h_err_msg = { }
	let h_err_point = { }
	let h_err_code = { }
	let b_mode = 0
	" error lineno
	let int_errln = 0
	" error column
	let int_errcol = 0
	" foreach line from compile result
	"for str_line in split ( t:kt_result, "\n" )
	let arr_lines = split ( t:kt_result, "\n" )
	let idx_line = 0
	while idx_line < len ( arr_lines )
		let str_line = arr_lines[ idx_line ]
		if len ( str_line ) > 0 && "" == substitute ( str_line, "^\\d\\+ errors\\?$", '', '' )
			break
		endif
		let idx_line = idx_line + 1

		echo str_line
		"echo ":::" . b_mode . ":::" . str_line
		let subtxt = split ( str_line, ":" )
		" if this line is file name, line no., and error message
		if b_mode == 0
				\ && len ( subtxt ) > 4
				\ && subtxt[ 0 ] == expand ( "%:p:t" )
				\ && len ( subtxt[ 1 ] ) > 1 && substitute ( subtxt[ 1 ], "\\d", "", "g" ) == ""
				\ && subtxt[ 3 ] == ' error'
			" remember the error char index
			let int_errcol = str2nr ( subtxt[ 2 ] )
			" remember the error line no.
			let int_errln = str2nr ( subtxt[ 1 ] )
			if ( !has_key ( h_err_msg, int_errln ) )
				" add data as the first one with new list
				let h_err_msg[ int_errln ] = [
					\ join ( subtxt[ 3 : ], ":" )
					\ ]
			else
				" add data to the error in same line
				call add ( h_err_msg[ int_errln ], join ( subtxt[ 3 : ], ":" ) )
			endif

			let b_mode = 1
		elseif b_mode == 1
			" error code
			if ( !has_key ( h_err_code, int_errln ) )
				" add data as the first one with new list
				let h_err_code[ int_errln ] = [ str_line ]
			else
				" add data to the error in same line
				call add ( h_err_code[ int_errln ], str_line )
			endif
			let b_mode = 2
		elseif b_mode == 2
			" error pointing
			"
			" if this line is not error pointing, restart as new
			" info
			if strlen ( substitute ( str_line, "^\\s\\{}^$", '', '' ) ) > 0
				let b_mode = 0
				"redo
				let idx_line = idx_line - 1
				continue
			endif

			" TEMP: convert str_line to the column of target error
			" IF the first char is tab, remove 2
			"if strlen ( str_line ) > strlen ( substitute ( str_line, "^\\t", "", "" ) )
			"	substitute ( str_line, "
			"let str_line = strlen ( str_line ) - 3
			"echo str_line
			let str_org = getline ( int_errln )
			for idx in range ( 0, int_errcol )
				if str_org[idx] == "\t"
					let str_line = '       ' . str_line
				endif
			endfor

			let str_line = substitute (
				\ substitute (
					\ substitute ( str_line, "\t", '        ', 'g' ),
					\ " ", '-', 'g'
					\ ),
				\ "^..", '//', '' )
			if len ( str_line ) >= 3
				" convert str_line to error pointing
				"let str_line = '//' . repeat ( '-', str_line ) . '^'
				if ( !has_key ( h_err_point, int_errln ) )
					" add data as the first one with new list
					let h_err_point[ int_errln ] = [ str_line ]
				else
					" add data to the error in same line
					call add ( h_err_point[ int_errln ], str_line )
				endif
			endif
			let b_mode = 0
		endif
	endwhile

	"echo h_err_msg
	"echo len ( keys ( h_err_msg ) )
	"unmenu "&Kotlin\\ Errors."
	if len ( keys ( h_err_msg ) ) <= 0
		return
	endif

	" show the errors in source code
	for idx_err in reverse ( sort ( keys ( h_err_msg ) ) )
		"exec ( 'normal ' . idx_err . "ggo\<Esc>0Di" . join ( h_err_point[ idx_err ], "\n:ERR:" ) )
		exec ( 'normal ' . idx_err . "ggO\<Esc>0Di// :ERR:" . join ( h_err_msg[ idx_err ], "\n:ERR:" ) )
		if ( has_key ( h_err_point, idx_err ) )
			exec ( "normal jo\<Esc>0Di" . join ( h_err_point[ idx_err ], "\n" ) )
		endif

		" show errors into new menu
		for str_err_msg in h_err_msg[ idx_err ]
			exec ( "amenu &Kotlin\\ Errors."
				\ . substitute ( str_err_msg, ' ', '\\ ', 'g' )
				\ . ' :let @/="' . str_err_msg . '"<CR>' )
		endfor
	endfor

	" select the errors
	exec ( "/:ERR:" )
endfunction

" Run current kt file
function! KotlinRunJar ( )
	:call SetPaths ( )

	" set dir to class files
	if exists ( t:dir ) && t:dir != ""
		cd `=t:dir`
	endif
	

	"echo class
	":!start cmd /c echo "kotlin.bat -cp \"" .  t:classpath . "\" " . t:classname
	":!start cmd /c "kotlin.bat -cp \"" .  t:classpath . "\" " . t:classname
	"exec ":!kotlin.bat -cp ". t:classpath . " " . t:classname
	"exec ":!start cmd /c kotlin.bat -cp \"". t:classpath . "\" " . t:classname
	"echo ":!start cmd /k cd " . t:dir . " && kotlin.bat -cp \"". t:classpath . "\" " . t:classname
	"exec ":!start cmd /k cd " . t:dir . " && kotlin.bat -Ddata.dir=\"" . t:dir . "\" -cp \"". t:classpath . "\" " . t:classname . "Kt"
	exec ":!start cmd /k cd " . t:dir . " && java -cp \"". t:classpath . "\" -jar " . t:classname . ".jar"
endfunction

" Compile current Kt file
function! KotlinCompile ( )
	" save the current file
	:w

	" set dir to this file
	"l`=t:srcpath`
	" compile this file
	" exec \":!kotlinc.bat \" . expand ( \"%:t\" )

	:call SetPaths ( )

	echo "====== getcwd ================\n"
	echo getcwd ( )
	cd `=t:srcpath`
	if exists ( t:dir ) && t:dir != ""
		let t:kt_result = system( "kotlinc.bat -jvm-target 1.8 -cp " . t:classpath . " -d " . t:dir . " " . expand ( "%:t" ) )
		"echo "kotlinc.bat -cp " . t:classpath . " -kotlin-home " . t:srcpath . " -d " . t:dir . " " . expand ( "%:t" )
		"let t:kt_result = system( "kotlinc.bat -cp " . t:classpath . " -kotlin-home " . t:srcpath . " -d " . t:dir . " " . expand ( "%:t" ) )
		echo "kotlinc.bat -jvm-target 1.8 -cp " . t:classpath . " -d " . t:dir . " " . expand ( "%:t" )
	else
		let t:kt_result = system( "kotlinc.bat -jvm-target 1.8 -cp " . t:classpath . " " . expand ( "%:t" ) )
		"echo "kotlinc.bat -cp " . t:classpath . " -kotlin-home " . t:srcpath . " " . expand ( "%:t" )
		"let t:kt_result = system( "kotlinc.bat -cp " . t:classpath . " -kotlin-home " . t:srcpath . " " . expand ( "%:t" ) )
		echo "kotlinc.bat -jvm-target 1.8 -cp " . t:classpath . " " . expand ( "%:t" )
	endif

	" show error(s) into the source code file
	let h_err_msg = { }
	let h_err_point = { }
	let h_err_code = { }
	let b_mode = 0
	" error lineno
	let int_errln = 0
	" error column
	let int_errcol = 0
	" foreach line from compile result
	"for str_line in split ( t:kt_result, "\n" )
	let arr_lines = split ( t:kt_result, "\n" )
	let idx_line = 0
	while idx_line < len ( arr_lines )
		let str_line = arr_lines[ idx_line ]
		if len ( str_line ) > 0 && "" == substitute ( str_line, "^\\d\\+ errors\\?$", '', '' )
			break
		endif
		let idx_line = idx_line + 1

		echo str_line
		"echo ":::" . b_mode . ":::" . str_line
		let subtxt = split ( str_line, ":" )
		" if this line is file name, line no., and error message
		if b_mode == 0
				\ && len ( subtxt ) > 4
				\ && subtxt[ 0 ] == expand ( "%:p:t" )
				\ && len ( subtxt[ 1 ] ) > 1 && substitute ( subtxt[ 1 ], "\\d", "", "g" ) == ""
				\ && subtxt[ 3 ] == ' error'
			" remember the error char index
			let int_errcol = str2nr ( subtxt[ 2 ] )
			" remember the error line no.
			let int_errln = str2nr ( subtxt[ 1 ] )
			if ( !has_key ( h_err_msg, int_errln ) )
				" add data as the first one with new list
				let h_err_msg[ int_errln ] = [
					\ join ( subtxt[ 3 : ], ":" )
					\ ]
			else
				" add data to the error in same line
				call add ( h_err_msg[ int_errln ], join ( subtxt[ 3 : ], ":" ) )
			endif

			let b_mode = 1
		elseif b_mode == 1
			" error code
			if ( !has_key ( h_err_code, int_errln ) )
				" add data as the first one with new list
				let h_err_code[ int_errln ] = [ str_line ]
			else
				" add data to the error in same line
				call add ( h_err_code[ int_errln ], str_line )
			endif
			let b_mode = 2
		elseif b_mode == 2
			" error pointing
			"
			" if this line is not error pointing, restart as new
			" info
			if strlen ( substitute ( str_line, "^\\s\\{}^$", '', '' ) ) > 0
				let b_mode = 0
				"redo
				let idx_line = idx_line - 1
				continue
			endif

			" TEMP: convert str_line to the column of target error
			" IF the first char is tab, remove 2
			"if strlen ( str_line ) > strlen ( substitute ( str_line, "^\\t", "", "" ) )
			"	substitute ( str_line, "
			"let str_line = strlen ( str_line ) - 3
			"echo str_line
			let str_org = getline ( int_errln )
			for idx in range ( 0, int_errcol )
				if str_org[idx] == "\t"
					let str_line = '       ' . str_line
				endif
			endfor

			let str_line = substitute (
				\ substitute (
					\ substitute ( str_line, "\t", '        ', 'g' ),
					\ " ", '-', 'g'
					\ ),
				\ "^..", '//', '' )
			if len ( str_line ) >= 3
				" convert str_line to error pointing
				"let str_line = '//' . repeat ( '-', str_line ) . '^'
				if ( !has_key ( h_err_point, int_errln ) )
					" add data as the first one with new list
					let h_err_point[ int_errln ] = [ str_line ]
				else
					" add data to the error in same line
					call add ( h_err_point[ int_errln ], str_line )
				endif
			endif
			let b_mode = 0
		endif
	endwhile

	"echo h_err_msg
	"echo len ( keys ( h_err_msg ) )
	"unmenu "&Kotlin\\ Errors."
	if len ( keys ( h_err_msg ) ) <= 0
		return
	endif

	" show the errors in source code
	for idx_err in reverse ( sort ( keys ( h_err_msg ) ) )
		"exec ( 'normal ' . idx_err . "ggo\<Esc>0Di" . join ( h_err_point[ idx_err ], "\n// :ERR:" ) )
		exec ( 'normal ' . idx_err . "ggO\<Esc>0Di// :ERR:" . join ( h_err_msg[ idx_err ], "\n// :ERR:" ) )
		if ( has_key ( h_err_point, idx_err ) )
			exec ( "normal jo\<Esc>0Di" . join ( h_err_point[ idx_err ], "\n" ) )
		endif

		" show errors into new menu
		for str_err_msg in h_err_msg[ idx_err ]
			exec ( "amenu &Kotlin\\ Errors."
				\ . substitute ( str_err_msg, ' ', '\\ ', 'g' )
				\ . ' :let @/="' . str_err_msg . '"<CR>' )
		endfor
	endfor

	" select the errors
	exec ( "/:ERR:" )
endfunction

" Run current kt file
function! KotlinRun ( )
	:call SetPaths ( )

	" set dir to class files
	if exists ( t:dir ) && t:dir != ""
		cd `=t:dir`
		"exec ":!start cmd /k cd " . t:dir . " && kotlin.bat -Ddata.dir=\"" . t:dir . "\" -cp \"". t:classpath . "\" " . t:classname . "Kt"
	else
		"exec ":!start cmd /k kotlin.bat -cp \"". t:classpath . "\" " . t:classname . "Kt"
	endif
	

	"echo class
	":!start cmd /c echo "kotlin.bat -cp \"" .  t:classpath . "\" " . t:classname
	":!start cmd /c "kotlin.bat -cp \"" .  t:classpath . "\" " . t:classname
	"exec ":!kotlin.bat -cp ". t:classpath . " " . t:classname
	"exec ":!start cmd /c kotlin.bat -cp \"". t:classpath . "\" " . t:classname
	"echo ":!start cmd /k cd " . t:dir . " && kotlin.bat -cp \"". t:classpath . "\" " . t:classname
	"exec ":!start cmd /k cd " . t:dir . " && kotlin.bat -Ddata.dir=\"" . t:dir . "\" -cp \"". t:classpath . "\" " . t:classname . "Kt"
	exec ":!start cmd /k cd " . t:dir . " && kotlin.bat -cp \"". t:classpath . "\" " . t:classname . "Kt"
endfunction

":nnoremap <C-S-K> :call KotlinRun ( )<CR>
:nmap ;K :call KotlinRun ( )<CR>
:nnoremap <C-k> :call KotlinCompile ( )<CR>
:nmap ;k :call KotlinCompile ( )<CR>
:nmap ;;K :call KotlinRunJar ( )<CR>
:nmap ;;k :call KotlinCompile2Jar ( )<CR>

:autocmd BufEnter *.kt :lcd %:p:h

":call SetPaths()

"function
" Make menu for errors
