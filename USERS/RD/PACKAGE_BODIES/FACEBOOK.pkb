CREATE OR REPLACE PACKAGE BODY "FACEBOOK" is

function do_request
  ( p_api_uri in varchar2
  , p_method  in varchar2 -- POST or GET
  , p_token   in varchar2 default null
  , p_body    in clob     default null
  ) return clob
is
  t_method           varchar2(255);
  l_retval           nclob;
  l_token            varchar2(2000) := p_token;
  CrLf      constant varchar2(2)    := chr(10) || chr(13);
  t_request_headers  s4sa_requests.request_headers%type;
  l_api_uri          varchar2(1000) := p_api_uri;
begin
    
  -- get token from apex if not provided
  if l_token is null then
    l_token := s4sa_oauth_pck.oauth_token('FACEBOOK');
  end if;
    
  -- reset headers from previous request
  apex_web_service.g_request_headers.delete;
  utl_http.set_body_charset('UTF-8');
    
  case p_method
    -- POST-FORM
    when s4sa_oauth_pck.g_http_method_post_form then
      t_method := 'POST';
    -- POST-JSON
    when s4sa_oauth_pck.g_http_method_post_json then
      t_method := 'POST';
    when s4sa_oauth_pck.g_http_method_get_init  then
      t_method := 'GET';
    -- GET
    when s4sa_oauth_pck.g_http_method_get       then
      t_method := 'GET';
      l_api_uri := l_api_uri || case when instr(l_api_uri, '?') = 0 
                                  then '?'
                                  else '&'
                                end;
      l_api_uri := l_api_uri
                || 'access_token=' || l_token
                || '&debug='        || 'all'
                || '&format='       || 'json'
                || '&method='       || 'get'
                || '&pretty='       || '1'
                || '&suppress_http_code=1';
    -- PUT
    when s4sa_oauth_pck.g_http_method_put       then
      t_method := 'PUT';
    -- PUT-JSON
    when s4sa_oauth_pck.g_http_method_put_json  then
      t_method := 'PUT';
    -- DELETE
    when s4sa_oauth_pck.g_http_method_delete    then
      t_method := 'DELETE';
    else
      raise s4sa_oauth_pck.e_parameter_check;
  end case;
    
  l_retval := apex_web_service.make_rest_request
                ( p_url         => l_api_uri
                , p_http_method => t_method
                , p_wallet_path => s4sa_oauth_pck.g_settings.wallet_path
                , p_wallet_pwd  => s4sa_oauth_pck.g_settings.wallet_pwd
                , p_body        => p_body
                );
                  
  begin
    for ii in 1..apex_web_service.g_request_headers.count loop
      t_request_headers := t_request_headers 
                        || rpad(apex_web_service.g_request_headers(ii).name, 30) || ' = ' 
                        || apex_web_service.g_request_headers(ii).value || CrLf;
    end loop;
    s4sa_oauth_pck.store_request
      ( p_provider        => 'FACEBOOK'
      , p_request_uri     => l_api_uri
      , p_request_type    => t_method || ' (' || p_method || ')'
      , p_request_headers => t_request_headers
      , p_body            => p_body
      , p_response        => l_retval );
  end;
    
    
  apex_web_service.g_request_headers.delete;
    
  return l_retval;
end do_request;

/*****************************************************************************
  FACEBOOK_AUTHENTICATION
  description   : the heart of the authentication plugin
  change history:
  date          name         remarks
  may 2015      R.Martens    Initial version
*****************************************************************************/
procedure authenticate(gDebug IN INTEGER DEFAULT 0)
is
  t_seconds_left  number;
  cursor c_oauth_user
  is     select c.n001 - ((sysdate - c.d001) * 24 * 60 * 60) as seconds_left
         from   apex_collections c
         where  c.collection_name = s4sa_oauth_pck.g_settings.collection_name
           and  c.c001            = 'FACEBOOK';
begin

  open c_oauth_user;
  fetch c_oauth_user into t_seconds_left;
  close c_oauth_user;
    
  if not nvl(t_seconds_left, 0) > 0 then
    redirect_oauth2(p_gotopage => v('APP_PAGE_ID'), p_debug => gDebug);
  end if;
    
end authenticate;
  
/*****************************************************************************
  invalid_session
  description   : invalid session function for the authentication plugin
  change history:
  date          name         remarks
  februari 2015 R.Martens    Initial version
*****************************************************************************/
function invalid_session
  ( p_authentication in apex_plugin.t_authentication
  , p_plugin         in apex_plugin.t_plugin 
  ) return apex_plugin.t_authentication_inval_result
is
  t_retval apex_plugin.t_authentication_inval_result;
begin

  redirect_oauth2(p_gotopage => v('APP_PAGE_ID'));
      
  return t_retval;
end invalid_session;
    
/**************************************************************************************************
  GET_TOKEN
  description   : get the token from google with which we can authorise further google requests
  change history:
  date          name         remarks
  februari 2015 R.Martens    Initial version
**************************************************************************************************/
procedure get_token
  ( p_code          in     varchar2
  , po_access_token    out varchar2
  , po_token_type      out varchar2
  , po_expires_in      out number
  , po_id_token        out varchar2
  , po_error           out varchar2
  , p_debug IN INTEGER DEFAULT 0
  )
is
  t_response    s4sa_oauth_pck.response_type;
  t_json        CLOB := EMPTY_CLOB();
  /*t_tbl_resp    wwv_flow_global.vc_arr2;
  t_tbl_var     wwv_flow_global.vc_arr2;*/
begin
  
  po_access_token := null;
  po_token_type   := null;
  po_expires_in   := null;
  po_id_token     := null;
  po_error        := null;
    
  t_response := do_request
                  ( p_api_uri => s4sa_oauth_pck.g_settings.api_prefix || 'graph.facebook.com/oauth/access_token'
                               || '?client_id='     || g_provider.client_id
                               || '&redirect_uri='  || CASE p_debug
                            WHEN 0 THEN g_provider.redirect_uri
                            ELSE g_provider.redirect_uri_debug
                        END
                               || '&client_secret=' || g_provider.client_secret
                               || '&code='          || p_code
                  , p_method  => s4sa_oauth_pck.g_http_method_get_init
                   );
                   
  if nullif (length (t_response), 0) is not null then
  
  t_json := t_response;
  else 
    raise_application_error(-20000, 'No response received.');
  end if;
  
  if JSON_Exists(t_json, '$.error') then
    po_error := JSON_Value(t_json, '$error');
  else
    po_error        := null;
    po_access_token := JSON_Value(t_json, '$.access_token');
    po_expires_in   := JSON_Value(t_json, '$.expires_in' RETURNING NUMBER);
    po_token_type   := JSON_Value(t_json, '$.token_type');      
  end if;
  
  /*if t_response like 'access_token=%' then
    t_tbl_resp := apex_util.string_to_table(t_response, '&');
    for rr in 1..t_tbl_resp.count loop
      t_tbl_var := apex_util.string_to_table(t_tbl_resp(rr), '=');
      case t_tbl_var(1)
        when 'access_token'  then
          po_access_token  := t_tbl_var(2);
        when 'expires'       then
          po_expires_in    := t_tbl_var(2);
        when 'error'         then
          po_error         := t_tbl_var(2);
        when 'id_token'      then
          po_id_token      := t_tbl_var(2);
        when 'token_type'    then
          po_token_type    := t_tbl_var(2);
        else
          null;
      end case;
    end loop;
  else
    po_error := t_response;
  end if;*/

end get_token;

/**************************************************************************************************
  GET_USER
  description   : returns a "google user" type that represents the logged-in user
  change history:
  date          name         remarks
  februari 2015 R.Martens    Initial version
**************************************************************************************************/
function get_user(p_token in varchar2)
  return s4sa_oauth_pck.oauth2_user
  is
    t_response s4sa_oauth_pck.response_type;
    t_retval   s4sa_oauth_pck.oauth2_user;
    t_json     CLOB := EMPTY_CLOB();
  begin
    
    t_response := do_request
                    ( p_api_uri => s4sa_oauth_pck.g_settings.api_prefix || 'graph.facebook.com/' 
                                || g_provider.api_version 
                                || '/me'
                                || '?fields=id,name,email,first_name,last_name,gender,link,locale,timezone,updated_time,verified,middle_name,age_range,birthday'
                    , p_token   => p_token
                    , p_method  => s4sa_oauth_pck.g_http_method_get);
    
    s4sa_oauth_pck.check_for_error( t_response );
    
    t_json := t_response;
    
    t_retval.id := JSON_Value(t_json, '$.id');
    t_retval.name := JSON_Value(t_json, '$.name');
    t_retval.email := JSON_Value(t_json, '$.email');
    t_retval.given_name := TRIM
    (
        JSON_Value(t_json, '$.first_name') || ' ' || JSON_Value(t_json, '$.middle_name')
    );
    t_retval.family_name := JSON_Value(t_json, '$.last_name');
    t_retval.gender := JSON_Value(t_json, '$.gender');
    t_retval.link := JSON_Value(t_json, '$.link');
    t_retval.locale := JSON_Value(t_json, '$.locale');
    t_retval.time_zone := JSON_Value(t_json, '$.timezone');
    t_retval.hd := NULL;
    t_retval.updated_time := s4sa_oauth_pck.To_TS_TZ
    (
        JSON_Value(t_json, '$.updated_time')
    );
    t_retval.verified := JSON_Value(t_json, '$.verified' RETURNING BOOLEAN);
    t_retval.date_birth := CASE
        WHEN JSON_Value(t_json, '$.birthday') IS NOT NULL THEN CASE
            WHEN VALIDATE_CONVERSION(JSON_Value(t_json, '$.birthday') AS DATE, 'MM/DD/YYYY') = 1 THEN TO_DATE(JSON_Value(t_json, '$.birthday'), 'MM/DD/YYYY')
            WHEN VALIDATE_CONVERSION(JSON_Value(t_json, '$.birthday') AS DATE, 'MM/DD') = 1 THEN TO_DATE(JSON_Value(t_json, '$.birthday'), 'MM/DD')
            WHEN VALIDATE_CONVERSION(JSON_Value(t_json, '$.birthday') AS DATE, 'YYYY') = 1 THEN TO_DATE(JSON_Value(t_json, '$.birthday'), 'YYYY')
            ELSE NULL
        END
        WHEN JSON_Value(t_json, '$.age_range.min' RETURNING NUMBER) IS NOT NULL THEN ADD_MONTHS
        (
            SYSDATE_UTC,
            -(
                JSON_Value(t_json, '$.age_range.min' RETURNING NUMBER) * 12
            )
        )
        ELSE NULL
    END;
    
    -- get picture in separate request
    t_response := do_request
                    ( p_api_uri => s4sa_oauth_pck.g_settings.api_prefix || 'graph.facebook.com/'
                    || g_provider.api_version || '/'
                                || t_retval.id || '/picture'
                                || '?width=640&redirect=false'                                
                    , p_method  => s4sa_oauth_pck.g_http_method_get);
    s4sa_oauth_pck.check_for_error( t_response );
    t_json :=  t_response;

    IF NOT JSON_Value(t_json, '$.data.is_silhouette' RETURNING BOOLEAN) THEN
        
        t_retval.picture := JSON_Value(t_json, '$.data.url');
        
    ELSE
        
        t_retval.picture := '';
        
    END IF;
    
    return t_retval;
    
  end get_user;
  
/**************************************************************************************************
  OAUTH2CALLBACK
  description   : is called by the users' browser after being redirected by google
                  performs the actual login
  change history:
  date          name         remarks
  februari 2015 R.Martens    Initial version
**************************************************************************************************/
procedure oauth2callback
  ( code              in varchar2 default null
  , state             in varchar2 default null
  , error             in varchar2 default null
  , error_description in varchar2 default null
  )
  is
    t_querystring   wwv_flow_global.vc_arr2;
    t_session       varchar2(255);
    t_workspaceid   varchar2(255);
    t_appid         varchar2(255);
    t_gotopage      varchar2(255);
    t_debug varchar2(1);
    t_code          varchar2(32767) := code;
    t_access_token  varchar2(32767);
    t_token_type    varchar2(255);
    t_expires_in    varchar2(255);
    t_id_token      varchar2(32767);
    t_error         varchar2(32767);
    t_oauth_user    s4sa_oauth_pck.oauth2_user;
    t_uri           varchar2(32767);
  begin
    
    --if not s4sa_oauth_pck.is_plsqldev then
    --  return;
    --end if;
    
    t_querystring := apex_util.string_to_table(utl_url.unescape(state), ':');
    
    for ii in 1..t_querystring.count loop
      case ii
        when 1 then t_session     := t_querystring(ii);
        when 2 then t_workspaceid := t_querystring(ii);
        when 3 then t_appid       := t_querystring(ii);
        when 4 then t_gotopage    := t_querystring(ii);
        when 5 then t_debug    := t_querystring(ii);
        else null;
      end case;
    end loop;
    
    if error is not null then
      s4sa_oauth_pck.present_error
        ( p_workspaceid => t_workspaceid
        , p_appid       => t_appid
        , p_gotopage    => t_gotopage
        , p_session     => t_session
        , p_errormsg    => error_description
        );
    else
    
      get_token( p_code          => t_code
               , po_access_token => t_access_token
               , po_token_type   => t_token_type
               , po_expires_in   => t_expires_in
               , po_id_token     => t_id_token
               , po_error        => t_error
               , p_debug => t_debug
               );
               
      if t_error is not null then
        s4sa_oauth_pck.check_for_error(t_error);
      end if;
        
      t_oauth_user := get_user(p_token => t_access_token);
          
      if t_error is null then
        
        s4sa_oauth_pck.do_oauth_login
         ( p_provider     => 'FACEBOOK'
         , p_session      => t_session
         , p_workspaceid  => t_workspaceid
         , p_appid        => t_appid
         , p_gotopage     => t_gotopage
         , p_code         => t_code
         , p_access_token => t_access_token
         , p_token_type   => t_token_type
         , p_expires_in   => t_expires_in
         , p_id_token     => t_id_token
         , p_error        => t_error
         , p_oauth_user   => t_oauth_user
         );
        
      else
        
        owa_util.redirect_url(v('LOGIN_URL') || '&notification_msg=' || apex_util.url_encode(t_error));  
      
      end if;
    end if;
        
  end oauth2callback;
  
/**************************************************************************************************
  REDIRECT_OAUTH2
  description   : is called by the plugin to start the login-process
  change history:
  date          name         remarks
  februari 2015 R.Martens    Initial version
**************************************************************************************************/
procedure redirect_oauth2
  ( p_gotopage       in varchar2 default null,
  p_debug IN INTEGER DEFAULT 0
  )
  is
    t_url     varchar2(32767);
  begin
    t_url := 'https://www.facebook.com/dialog/oauth?'
                        || 'client_id='      || g_provider.client_id
                        || '&redirect_uri='  || CASE p_debug
                            WHEN 0 THEN g_provider.redirect_uri
                            ELSE g_provider.redirect_uri_debug
                        END
                        || '&scope='         || apex_util.url_encode(g_provider.scope)
                        || '&state='         || v('APP_SESSION') || ':' || v('WORKSPACE_ID') || ':' || v('APP_ID') || ':' || p_gotopage || ':' || p_debug
                        || '&response_type=' || 'code'
                        || g_provider.extras
                        || '&approval_prompt=force'
                        --|| case p_force_approval
                        --     when 'Y' then '&approval_prompt=force'
                        --     else ''
                        --   end
                        ;
                          
    owa_util.redirect_url ( t_url );
    
    apex_application.stop_apex_engine;
                        
  end redirect_oauth2;

begin
  
  g_provider.client_id      := s4sa_oauth_pck.get_setting('S4SA_FCB_CLIENT_ID');
  g_provider.client_secret  := s4sa_oauth_pck.get_setting('S4SA_FCB_CLIENT_SECRET');
  g_provider.redirect_uri   := s4sa_oauth_pck.get_setting('S4SA_FCB_REDIRECT_URL');
  g_provider.redirect_uri_debug := s4sa_oauth_pck.get_setting('S4SA_FCB_REDIRECT_URL_DEBUG');
  g_provider.api_version    := s4sa_oauth_pck.get_setting('S4SA_FCB_API_VERSION');
  g_provider.extras         := s4sa_oauth_pck.get_setting('S4SA_FCB_EXTRAS');
  g_provider.scope          := s4sa_oauth_pck.get_setting('S4SA_FCB_SCOPE');
  g_provider.force_approval := s4sa_oauth_pck.get_setting('S4SA_FCB_FORCE_APPROVAL');
  
end;
/