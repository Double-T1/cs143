/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

static int comment_layers;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
%}

/*
 * Define names for regular expressions here.
 */

%Start		INLINE_COMMENT
%Start		ENCLOSED_COMMENT  
%Start		STRING_CONST      

%%

 /*
  * This scanner categorizes the COOL program into lexemes of different type of 
  * tokens.
  *
  * Token types include comments(enclosed, inline), C-style string constants,
  * integers, identitfiers, special notations(*,+,<-...etc.), keywords(if, else,
  * while, case...erc.), white space(blank,\n,\t,\f...etc.).
  */ 

 /*
  *  enclosed comments
  */

 /* are we allowed to start an enclosed comment in an inline comment?*/
<ENCLOSED_COMMENT,INITIAL>"(*" {
     ++comment_layers;
     BEGIN(ENCLOSED_COMMENT);
}

 /* anything not a new line or * or (.
  * if it  statrts with a *, it might be *). If it starts with a (, it might be 
  * (*.
  */ 
<ENCLOSED_COMMENT>[^*\n(]* {} 

 /* a new line*/
<ENCLOSED_COMMENT>(\n) { ++curr_lineno; }

 /* a single * or ( or ) is considered to be within the enclosed comment */
<ENCLOSED_COMMENT>[*()] {}

<ENCLOSED_COMMENT>"*)" {
	if (--comment_layers == 0){
	   BEGIN(0);
	};
}

 /* reached EOF before comments closed */
<ENCLOSED_COMMENT><<EOF>> {
	BEGIN(0);
	yylval.error_msg = "EOF in comment";
	return ERROR;
}

 /* "*)" in the state of initial */
"*)" {
     yylval.error_msg = "Unmatched *)";
     return ERROR;
}

 /* Inline comments */
<INITIAL>"--" {
     BEGIN(INLINE_COMMENT);
}

 /* any character besides return is part of the comment*/
<INLINE_COMMENT>[^\n]* {}

 /* the comment ends if a return is encountered*/
<INLINE_COMMENT>(\n) { 
	++curr_lineno;
	BEGIN(0);
}

 /* the comment ends encountering EOF*/
<INLINE_COMMENT><<EOF>> {
	BEGIN(0);
}

 /*
  * String Constants (c syntax)
  * Escape sequence \c is accepted for all characters c. Except for
  * \n \t \b \f, the reuslt if c.
  *
  * Values and Functions provided by flex
  * 1. yytext is a string pointer that contains the matched substring. It is 
  * automatically renewed for each lexeme
  * 2. yyleng is the length of the yytext string
  * 3. yymore() is a function that appends the newly matched pattern to the 
  * previous yytext instead of replacing it.
  *
  */ 

<INITIAL>(\") {
	BEGIN(STRING_CONST);
	yymore();
}

 /* anything besides '\','"','\n' can be directly considered part of the string
  */
<STRING_CONST>[^\\\"\n]* { yymore(); }

 /* an escape character that isn't followed by a new line */
<STRING_CONST>(\\)[^\n] { yymore(); }

 /* an escape character that is followed by a new line */
<STRING_CONST>(\\)(\n) {
	++curr_lineno;
	yymore();
} 

 /* EOF within the string */
 /* yy_flush_buffer might be better instead of yyrestart(yyin) */
<STRING_CONST><<EOF>> {
	yylval.error_msg = "EOF in string constant";
	BEGIN(0);
	yyrestart(yyin);
	return ERROR;	      
}

 /* meets a null in the middle */
 /* doesn't work, but why?? */
<STRING_CONST>(\0) {
	yylval.error_msg = "String contains null character";
	BEGIN(0);
	return ERROR;
}

 /* meets a return in the middle */
<STRING_CONST>(\n) {
	yylval.error_msg = "Unterminated string constant";
	++curr_lineno;
	return ERROR;
}

 /* with the string ending, we deal with the specail characters: b,t,n,f */
 /* can we use string_view instead of substrings? */
<STRING_CONST>(\") {
	std::string input(yytext,yyleng);
	input = input.substr(1,input.size()-2);
	
	if (input.find('\0') != std::string::npos) {
	   yylval.error_msg = "String contains null character";
	   BEGIN(0);
	   return ERROR;
	}
	
	std::string output = "";
	std::string::size_type pos;
	
	while ((pos = input.find('\\')) != std::string::npos) {
	      output += input.substr(0,pos);
	      
	      /* what if pos is the last character? */
	      switch(input[pos+1]) {
	      	case 'b':
		     output += "\b";
		     break;
		case 't':
		     output += "\t";
		     break;
		case 'n':
		     output += "\n";
		     break;
		case 'f':
		     output += "\f";
		     break;
		default:
			output += input[pos+1];
			break;
	      }

	      input = input.substr(pos+2,input.size()-pos-2);
	}

	output += input;

	if (output.size() > MAX_STR_CONST) {
	   yylval.error_msg = "String constant too large";
	   BEGIN(0);
	   return ERROR;
	} 

	cool_yylval.symbol = stringtable.add_string((char*)output.c_str());
	BEGIN(0);
	return STR_CONST;
}

 
 /*
  * Keywords
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)	{ return CLASS; }

(?i:inherits)	{ return INHERITS; }

(?i:if)		{ return IF; }

(?i:else)	{ return ELSE; }

(?i:then)	{ return THEN; }

(?i:fi) 	{ return FI; }

(?i:new)	{ return NEW; }

(?i:while)	{ return WHILE; }

(?i:loop)	{ return LOOP;  }

(?i:pool) 	{ return POOL; }

(?i:case)	{ return CASE; }

(?i:esac) 	{ return ESAC; }

(?i:of) 	{ return OF; }

(?i:let)	{ return LET; }

(?i:in)		{ return IN; }

(?i:not) 	{ return NOT; }

(?i:isvoid) 	{ return ISVOID; }

f(?i:alse) 	{
	cool_yylval.boolean = false;
	return BOOL_CONST;
}
 
t(?i:rue)	{
	cool_yylval.boolean = true;
	return BOOL_CONST;
} 

 /* integer constants/literals */
[0-9]+ {
       cool_yylval.symbol = inttable.add_string(yytext);
       return INT_CONST;
}

 /* a new line */
(\n)	{ ++curr_lineno; }

 /*
  * Identifiers, including type identifiers and object identifiers and self,
  * SELF_TYPE
  */

 /* typeID: starts with a captial letter, includes SELF_TYPE */
[A-Z][a-zA-Z0-9_]* {
	cool_yylval.symbol = idtable.add_string(yytext);
	return TYPEID;
}

 /* objectID: starts with lower case, includes self */
[a-z][a-zA-Z0-9_]* {
	cool_yylval.symbol = idtable.add_string(yytext);
	return OBJECTID;
}

 /*
  * Special Notations 
  */

 /*  multiple character operators: =>, <-, <= */
"=>"	{ return DARROW; }
  
"<-"	{ return ASSIGN; }

"<="	{ return LE; }

 /* single character operators */
"+"	{ return int('+'); }

"-"	{ return int('-'); }

"*"	{ return int('*'); }

"/"	{ return int('/'); }

"~"	{ return int('~'); }

"<"	{ return int('<'); }

"=" 	{ return int('='); }

"(" 	{ return int('('); }

")" 	{ return int(')'); }

"@"	{ return int('@'); }

"." 	{ return int('.'); }

"{"	{ return int('{'); }

"}"	{ return int('}'); }

":" 	{ return int(':'); }

";"	{ return int(';'); }

","	{ return int(','); }


 /* white space*/
[ \f\r\t\v]+ { }
 

 /* a catch-all error */
. {
      yylval.error_msg = yytext;
      return ERROR;
}

%%
