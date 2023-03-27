create or replace
PACKAGE TOTP_PKG
AS 
/*

* Original idea and first implementation: Andrzej Nowakowski @ApexUtil_andrew
* Code rewrite and co-writer: Patryk Mrozicki
* Help and credits for Demo presentation to: Lukasz Szymanski @ApexUtil_lukas

 MIT License

 Copyright (c) 2018 APEXUTIL www.apexutil.com

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

*/

/*
    Functions get_random_base32_json and get_random_base32 will be useful to generate 
    random 20 characters original and 32 characters long base32 strings
    We do not provide DECODE for base32, thats why we encourage to save both original and encoded strings
*/
  function get_random_base32_json -- orginal, base32code
  return varchar2;
  
  procedure get_random_base32
  (
    p_orig in out nocopy varchar2
  , p_base in out nocopy varchar2
  );
  
  /* If you want to use it in GOOGLE AUTHENTICATOR then just use p_key */
  /* This function returns 6 digit code -- which you compare to the one users give */
  function totp_code( 
    p_key       in varchar2 -- original code
  , p_unix_time in pls_integer default null -- used for custom time (not current)
  , p_interval  in pls_integer default 30  -- for other algorithms where interval is different than 30 second
  ) return varchar2;

  
  
  
  
  --- SUB FUNCTIONS | might be useful ---

  -- returns GMT date
  function get_greenwich_time return date;

  -- change date to unix time ( or POSIX/Epoch time ) - warning: problems in 2038 ( if PLS_INTIGER = 32bit then BOOM('!!!'); end if;)
  function date_to_unix_time( p_date in date ) return pls_integer;

  -- encodes string to base32 -- warning: max is varchar2(2500)
  function encode_base32( p_str in varchar2 ) return varchar2;

  -- this function can be useful if you want to change an integer to hashed message which later can be translated into 6 digit code
  function unix_to_hash_message( p_time in pls_integer ) return varchar2;
  
  -- returns 6 digit code from hash ( has to be: 40 digit long hexadecimal number )
  function code_from_hash( p_hash in varchar2 ) return varchar2;
  
  -- hash function
  function hmac_sha1_hash(
    p_message in varchar2
  , p_key     in varchar2
  ) return varchar2;

  
END TOTP_PKG;
/