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
create or replace PACKAGE BODY TOTP_PKG AS

  function generate_string(
    p_length  in number   default 20
  , p_options in varchar2 default 'ULAXPD' -- U - upper, L - lower, A - alphanumeric, X - alphanumeric with upper case letters, P - printable characters only, D - numbers
  ) return varchar2
  as

    l_options apex_application_global.vc_arr2;
    l_string varchar2(4000);
    l_length number := coalesce( p_length, 20 );
    l_options_cnt number;
    l_index  number;

    l_char varchar2(2);
    l_new_char varchar2(2);

  begin

    -- get available characters (ULAXPD) from p_options. Then change them to be delimited by ':'
    l_options := apex_util.string_to_table( coalesce( trim( both ':' from regexp_replace( regexp_replace( upper(p_options), '[^ULAXPD]', '' ), '*', ':') ),'D'), ':' );
    l_options_cnt := l_options.count;

    for x in 1..p_length loop

      l_index := dbms_random.value( 1, l_options_cnt );
      l_char   := l_options( l_index );

      if ( l_char = 'U' ) then
        l_new_char := dbms_random.string( 'U', 1 );
      elsif ( l_char = 'L' ) then
       l_new_char := dbms_random.string( 'L', 1 );
      elsif ( l_char = 'A' ) then
        l_new_char := dbms_random.string( 'A', 1 );
      elsif ( l_char = 'X' ) then
        l_new_char := dbms_random.string( 'X', 1 );
      elsif ( l_char = 'P' ) then
        l_new_char := dbms_random.string( 'P', 1 );
      elsif ( l_char = 'D ' ) then
        l_new_char := trunc( to_char( dbms_random.value(0,9) ) );
      else
        l_new_char := trunc( to_char( dbms_random.value(0,9) ) );
      end if;

      l_string := l_string || l_new_char;

    end loop;

    return l_string;

  end generate_string;
  
  
  function get_random_base32_json -- orginal, base32code
  return varchar2
  as
    l_string varchar2(20);
  begin
    l_string := generate_string( p_length => 20, p_options => 'ULD' );
    
    -- it never returns characters that should be escaped in json
    return '{ "original" : "' || replace( l_string, '"', '\"' ) || '", "base32code" : "' || totp_pkg.encode_base32( p_str => l_string ) || '" }';
  end get_random_base32_json;
  
  procedure get_random_base32
  (
    p_orig in out nocopy varchar2
  , p_base in out nocopy varchar2
  )
  as

  begin

    p_orig := generate_string( p_length => 20, p_options => 'ULD' );
    p_base := totp_pkg.encode_base32( p_str => p_orig );

  end get_random_base32;
  
  
  function get_greenwich_time
  return date
  as
    l_offset_str varchar2(16) := TZ_OFFSET(SESSIONTIMEZONE);
    l_sign       number;
    l_time       date := sysdate;
  begin 

    if( l_offset_str <> '+00:00' ) then

      l_sign := -to_number( substr(l_offset_str, 1, 1) || '1440' );
      l_time := l_time + ( substr(l_offset_str, 2, 2)*60 + substr(l_offset_str, 5, 2) ) / l_sign ;

    end if;

    return l_time;

  end get_greenwich_time; 

  function date_to_unix_time( p_date in date ) 
  return pls_integer
  as
    l_zero_date constant date := to_date( '19700101', 'YYYYMMDD' ); -- 1970-01-01
  begin

    return trunc( ( p_date - l_zero_date ) * 86400 );

  end date_to_unix_time;

  function encode_base32
  ( 
    p_str in varchar2
  ) return varchar2
  as
    l_base_str varchar2(4000);
    l_num number(12);
    l_length constant pls_integer := ceil( length(p_str)/5 );

    l_result varchar2(160);

    function number_encode_base32
    ( 
      p_val in number 
    ) return varchar2 
    as
      l_str varchar(8) := null;
      l_val number     := p_val;
      l_base32str constant varchar(32) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

    begin
      for i in 1..8 loop
        l_str := substr( l_base32str, mod( l_val, 32 ) + 1, 1 ) || l_str;
        l_val := trunc( l_val / 32 );
      end loop;

      return l_str;
    end number_encode_base32;
  begin
    l_base_str := rpad(p_str, l_length*5, CHR(0));

    for i in 0..l_length-1 loop

      l_num := UTL_RAW.cast_to_binary_integer( UTL_RAW.cast_to_raw(substr(l_base_str, 1+i*5, 4)) );
      l_result := l_result || number_encode_base32( l_num * 256 + ascii(substr( l_base_str, (i+1)*5, 1)) );

    end loop;

    return l_result;
  end encode_base32;

  function unix_to_hash_message( p_time in PLS_INTEGER )
  return varchar2
  as
    function unix_to_hex( p_time in PLS_INTEGER ) -- warning: problem occur in 36812 (year)
    return varchar2
    as
    begin

      return replace( to_char( p_time, 'XXXXXXXXXX' ), ' ', '' );

    end unix_to_hex;
  begin

    return utl_raw.cast_to_varchar2( lpad(unix_to_hex(p_time), 16, '0') );

  end unix_to_hash_message;

  function hmac_sha1_hash(
    p_message in varchar2
  , p_key     in varchar2

  ) return varchar2
  as
    l_message RAW(512);
    l_key     RAW(512);

  begin

    l_message := UTL_RAW.cast_to_raw( c => p_message );
    l_key     := UTL_RAW.cast_to_raw( c => p_key );

    return DBMS_CRYPTO.mac(
      src => l_message
    , key => l_key
    , typ => DBMS_CRYPTO.hmac_sh1
    );

  end hmac_sha1_hash;

  function code_from_hash( p_hash in varchar2 )
  return varchar2
  as
    l_offset   number;

  begin
    -- at first find offset ( will be used twice )
    l_offset := ( to_number( substr(p_hash, 40, 1), 'X' ) * 2 ) + 1; -- +1 because index starts from 1 not 0

    --Explanation to the next line:
    -- (we have 40 digit long hexadecimal number )
    --1) take specific letter from hash (from l_offset)
    --2) change to number
    --3) use "mod" to negate MSB ( most significant bit )
    --4) change to varchar2 ( to_char adds space... so delete space by taking second char )
    --5) then take 7 more chars and add to previous string ( point 4 )
    --6) change it to number
    --7) get last 6 digits ( the code ) by dividing by million
    --8) change back to string, then left pad with '0' (so we have 6 digits )
    --9) Enjoy! :)
    return lpad( to_char( mod( to_number( substr( to_char( mod( to_number( substr( p_hash, l_offset, 1 ), 'X' ), 8 ), 'X' ), 2, 1 ) || substr(p_hash, l_offset+1, 7 ), 'XXXXXXXX' ), 1000000 )), 6, '0' );

  end code_from_hash;

  --- end function
  
  function totp_code( 
    p_key       in varchar2 -- original code
  , p_unix_time in pls_integer default null -- used for custom time (not current)
  , p_interval  in pls_integer default 30  -- for other algorithms where interval is different than 30 second
  ) return varchar2
  as
    l_date      date;
    l_unix_time pls_integer;
    l_message   varchar2(64);  
    l_interval  pls_integer;
  begin
    
    -- interval = 0 will raise exception, negative interval allowed...
    l_interval := coalesce(p_interval, 30); 
    
    -- get current time if user didn't provide one (negative unix_time allowed..)
    l_unix_time := coalesce(p_unix_time, date_to_unix_time( get_greenwich_time() ));
    -- here we get one unit of time
    l_unix_time := trunc(l_unix_time / l_interval);
    
    -- get hash
    l_message   := unix_to_hash_message( l_unix_time );
    
    -- return translated hash
    return code_from_hash (
        hmac_sha1_hash(
          p_message => l_message
        , p_key     => p_key
        )
    );

  end totp_code;

END TOTP_PKG;
/