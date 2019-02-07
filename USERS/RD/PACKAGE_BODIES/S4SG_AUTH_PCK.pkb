CREATE OR REPLACE PACKAGE BODY  "S4SG_AUTH_PCK" is

PROCEDURE LOG(Comments IN VARCHAR2)
AS

BEGIN

    CREATE_DEBUGLOG_ENTRY(gc_ObjectName, Comments);

END LOG;

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
    
    LOG
    (
        'Do_Request: ' || 'started with input:' || CHR(10)
        || 'p_api_uri: ' || p_api_uri || CHR(10)
        || 'p_method: ' || p_method || CHR(10)
        || 'p_token: ' || p_token || CHR(10)
        || 'p_body: ' || p_body
    );
    
  -- get token from apex if not provided
  if l_token is null then
  LOG('Do_Request: ' || 'token is NULL');
    l_token := s4sa_oauth_pck.oauth_token('GOOGLE');
    LOG('Do_Request: ' || 'called s4sa_oauth_pck.oauth_token(''GOOGLE'')');
  end if;
    
  -- reset headers from previous request
  apex_web_service.g_request_headers.delete;
  LOG('Do_Request: ' || 'deleted headers');
  utl_http.set_body_charset('UTF-8');
LOG('Do_Request: ' || 'set character set to UTF-8');
  case p_method
    -- POST-FORM
    when s4sa_oauth_pck.g_http_method_post_form then
    LOG('Do_Request: ' || 'method is POST_FORM');
      t_method := 'POST';
      apex_web_service.g_request_headers(1).name  := 'Content-Type';
      apex_web_service.g_request_headers(1).value := 'application/x-www-form-urlencoded; charset=UTF-8';
      LOG('Do_Request: ' || 'Set request headers');
    -- POST-MAIL
    when s4sa_oauth_pck.g_http_method_post_mail then
      t_method := 'POST';
      apex_web_service.g_request_headers(1).name  := 'Content-Type';
      apex_web_service.g_request_headers(1).value := 'application/json; charset=UTF-8';
      apex_web_service.g_request_headers(2).name  := 'Authorization';
      apex_web_service.g_request_headers(2).value := 'Bearer ' || l_token;
    -- POST-JSON
    when s4sa_oauth_pck.g_http_method_post_json then
      t_method := 'POST';
      apex_web_service.g_request_headers(1).name  := 'Content-Type';
      apex_web_service.g_request_headers(1).value := 'application/json; charset=UTF-8';
      apex_web_service.g_request_headers(2).name  := 'Authorization';
      apex_web_service.g_request_headers(2).value := 'Bearer ' || l_token;
    -- GET
    when s4sa_oauth_pck.g_http_method_get then
      t_method := 'GET';
      apex_web_service.g_request_headers(1).name  := 'Authorization';
      apex_web_service.g_request_headers(1).value := 'Bearer ' || l_token;
    -- PUT
    when s4sa_oauth_pck.g_http_method_put then
      t_method := 'PUT';
      apex_web_service.g_request_headers(1).name  := 'Authorization';
      apex_web_service.g_request_headers(1).value := 'Bearer ' || l_token;
    -- PUT-JSON
    when s4sa_oauth_pck.g_http_method_put_json then
      t_method := 'PUT';
      apex_web_service.g_request_headers(1).name  := 'Content-Type';
      apex_web_service.g_request_headers(1).value := 'application/json; charset=UTF-8';
      apex_web_service.g_request_headers(2).name  := 'Authorization';
      apex_web_service.g_request_headers(2).value := 'Bearer ' || l_token;
    -- DELETE
    when s4sa_oauth_pck.g_http_method_delete then
      t_method := 'DELETE';
      apex_web_service.g_request_headers(1).name  := 'Authorization';
      apex_web_service.g_request_headers(1).value := 'Bearer ' || l_token;
    else
      raise s4sa_oauth_pck.e_parameter_check;
  end case;
  
  --rae(l_api_uri);
    
  l_retval := apex_web_service.make_rest_request
                ( p_url         => l_api_uri
                , p_http_method => t_method
                , p_wallet_path => s4sa_oauth_pck.g_settings.wallet_path
                , p_wallet_pwd  => s4sa_oauth_pck.g_settings.wallet_pwd
                , p_body        => p_body
                );
                LOG('Do_Request: ' || 'Made web request');
  begin
    for ii in 1..apex_web_service.g_request_headers.count loop
      t_request_headers := t_request_headers 
                        || rpad(apex_web_service.g_request_headers(ii).name, 30) || ' = ' 
                        || apex_web_service.g_request_headers(ii).value || CrLf;
    end loop;
    s4sa_oauth_pck.store_request
      ( p_provider        => 'GOOGLE'
      , p_request_uri     => l_api_uri
      , p_request_type    => t_method || ' (' || p_method || ')'
      , p_request_headers => t_request_headers
      , p_body            => p_body
      , p_response        => l_retval );
  end;
    
    
  apex_web_service.g_request_headers.delete;
    
  return l_retval;
exception
  when others then
    raise_application_error(-20000, p_api_uri);
end do_request;
  
/*****************************************************************************
  GOOGLE_AUTHENTICATION
  description   : the heart of the authentication plugin
  change history:
  date          name         remarks
  februari 2015 R.Martens    Initial version
*****************************************************************************/
procedure authenticate
is
  t_seconds_left  number;
  cursor c_oauth_user
  is     select c.n001 - ((sysdate - c.d001) * 24 * 60 * 60) as seconds_left
         from   apex_collections c
         where  c.collection_name = s4sa_oauth_pck.g_settings.collection_name
           and  c.c001            = 'GOOGLE';
begin

  open c_oauth_user;
  fetch c_oauth_user into t_seconds_left;
  close c_oauth_user;

  if not nvl(t_seconds_left, 0) > 0 then
    redirect_oauth2(p_gotopage => v('APP_PAGE_ID'));
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
  description: get the token from google with which we can authorise further google requests
  url: https://developers.google.com/identity/protocols/OAuth2WebServer#example
**************************************************************************************************/
procedure get_token
  ( p_code          in     varchar2
  , po_access_token    out varchar2
  , po_token_type      out varchar2
  , po_expires_in      out number
  , po_id_token        out varchar2
  , po_error           out varchar2
  )
is
  t_response    s4sa_oauth_pck.response_type;
  t_json        CLOB := EMPTY_CLOB();
begin
    
    LOG('Get_Token: ' || 'started with input:
p_code: ' || p_code
);
    
  t_response := do_request
                  ( p_api_uri => 'https://www.googleapis.com/oauth2/v4/token'
                  , p_method => s4sa_oauth_pck.g_http_method_post_form
                  , p_body => 'code=' || p_code
                              || '&client_id=' || g_provider.client_id
                              || '&client_secret=' || g_provider.client_secret
                              || '&redirect_uri=' || g_provider.redirect_uri
                              || '&grant_type=' || 'authorization_code'
                   );
    LOG('Get_Token: ' || 'requested token');
  if nullif (length (t_response), 0) is not null then
  LOG('Get_Token: ' || 'response has length');
    t_json := t_response;
  else
  LOG('Get_Token: ' || 'response has no length');
    raise_application_error(-20000, 'No response received.');
  end if;
  
  if JSON_Exists(t_json, '$.error') then
  LOG('Get_Token: ' || 'error in JSON');
    po_error := JSON_Value(t_json, '$.error.message');
  else
  LOG('Get_Token: ' || 'no error in JSON');
    po_error        := null;
    po_access_token := JSON_Value(t_json, '$.access_token');
    po_expires_in   := JSON_Value(t_json, '$.expires_in'  );
    po_id_token     := JSON_Value(t_json, '$.id_token'    );
    po_token_type   := JSON_Value(t_json, '$.token_type'  );      
    LOG('Get_Token: ' || 'parsed JSON:
po_access_token: ' || po_access_token || '
po_expires_in: ' || po_expires_in || '
po_id_token: ' || po_id_token || '
po_token_type: ' || po_token_type
);
  end if;

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
                    ( p_api_uri => 'https://www.googleapis.com/oauth2/v2/userinfo'
                    , p_method  => 'GET'
                    , p_token   => p_token);
    
    s4sa_oauth_pck.check_for_error( t_response );
    
    t_json := t_response;
    
    t_retval.id := JSON_Value(t_json, '$.id');
    t_retval.email := JSON_Value(t_json, '$.email');
    t_retval.verified := JSON_VALUE(t_json, '$.verified_email' RETURNING BOOLEAN);
    t_retval.name := JSON_Value(t_json, '$.name');
    t_retval.given_name := JSON_Value(t_json, '$.given_name');
    t_retval.family_name := JSON_Value(t_json, '$.family_name');
    t_retval.link := JSON_Value(t_json, '$.link');
    t_retval.picture := JSON_Value(t_json, '$.picture');
    t_retval.gender := JSON_Value(t_json, '$.gender');
    t_retval.locale := JSON_Value(t_json, '$.locale');
    t_retval.hd := JSON_Value(t_json, '$.hd');
    t_retval.time_zone := NULL;
    t_retval.updated_time := NULL;
    
    BEGIN
        
        t_response := Do_Request
        (
            --https://developers.google.com/+/web/api/rest/latest/people
            p_api_uri => 'https://www.googleapis.com/plus/v1/people/me',
            p_method => 'GET',
            p_token => p_token
        );
        
        S4SA_OAUTH_PCK.Check_For_Error( t_response );
        
        t_json := t_response;
        
        --JSON_EXT.Get_String(t_json, 'nickname')
        
        t_retval.date_birth := CASE
            WHEN JSON_Value(t_json, 'birthday') IS NOT NULL THEN CASE
                WHEN VALIDATE_CONVERSION(JSON_Value(t_json, '$.birthday') AS DATE, 'YYYY-MM-DD') = 1 THEN TO_DATE(JSON_Value(t_json, '$.birthday'), 'YYYY-MM-DD')
                WHEN VALIDATE_CONVERSION(JSON_Value(t_json, '$.birthday') AS DATE, 'MM-DD') = 1 THEN TO_DATE(JSON_Value(t_json, '$.birthday'), 'MM-DD')
                WHEN VALIDATE_CONVERSION(JSON_Value(t_json, '$.birthday') AS DATE, 'YYYY') = 1 THEN TO_DATE(JSON_Value(t_json, '$.birthday'), 'YYYY')
                ELSE NULL
            END
            WHEN JSON_Value(t_json, '$.ageRange.min' RETURNING NUMBER) IS NOT NULL THEN ADD_MONTHS(SYSDATE_UTC, -(JSON_Value(t_json, '$.ageRange.min' RETURNING NUMBER) * 12))
            ELSE NULL
        END;
        
        IF JSON_Value(t_json, '$.image.isDefault' RETURNING BOOLEAN) THEN
            
            t_retval.Picture := '';
            
        END IF;
        
    EXCEPTION
    WHEN OTHERS THEN
        
        NULL;
        
    END;
    
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
  ( state             in varchar2 default null
  , code              in varchar2 default null
  , error             in varchar2 default null
  , error_description in varchar2 default null
  , token             in varchar2 default null
  )
  is
    t_querystring   wwv_flow_global.vc_arr2;
    t_session       varchar2(255);
    t_workspaceid   varchar2(255);
    t_appid         varchar2(255);
    t_gotopage      varchar2(255);
    t_code          varchar2(32767) := code;
    t_access_token  varchar2(32767);
    t_token_type    varchar2(255);
    t_expires_in    varchar2(255);
    t_id_token      varchar2(32767);
    t_error         varchar2(32767);
    t_oauth_user    s4sa_oauth_pck.oauth2_user;
  begin

    -- demo
    --raise_application_error(-20000, 'stop');
    LOG('oauth2callback: ' || 'started');
    t_querystring := apex_util.string_to_table(state, ':');
    LOG('oauth2callback: ' || 'read state parameter in the querystring');

    for ii in 1..t_querystring.count loop
      case ii
        when 1 then t_session     := t_querystring(ii);
        when 2 then t_workspaceid := t_querystring(ii);
        when 3 then t_appid       := t_querystring(ii);
        when 4 then t_gotopage    := t_querystring(ii);   
        else null;
      end case;
    end loop;
    
    LOG
    (
        'oauth2callback: ' || 'put querystring into variables:' || CHR(10)
        || 't_session: ' || t_session || CHR(10)
        || 't_workspaceid: ' || t_workspaceid || CHR(10)
        || 't_appid: ' || t_appid || CHR(10)
        || 't_gotopage: ' || t_gotopage
    );
    -- check for error
    if error is not null then
    LOG('oauth2callback: ' || 'error is not null');
      s4sa_oauth_pck.present_error
        ( p_workspaceid => t_workspaceid
        , p_appid       => t_appid
        , p_gotopage    => t_gotopage
        , p_session     => t_session
        , p_errormsg    => error
        );
    else
    LOG('oauth2callback: ' || 'no error');
      -- get the token (STEP 2)
      get_token( p_code          => t_code  -- <== this is the code used for requesting an access token
               , po_access_token => t_access_token
               , po_token_type   => t_token_type
               , po_expires_in   => t_expires_in
               , po_id_token     => t_id_token
               , po_error        => t_error
               );
LOG('oauth2callback: ' || 'got token');
    --validate the token to mitigate the confused deputy problem
    IF Token_Is_Valid(t_access_token) THEN
LOG('oauth2callback: ' || 'token was valid');
        -- using the token we can now ask google who logged in.  
        t_oauth_user := get_user(p_token => t_access_token);
LOG('oauth2callback: ' || 'got user');
    ELSE
LOG('oauth2callback: ' || 'token was invalid');
        OWA_UTIL.Redirect_URL('f?p=' || t_appid || ':' || t_gotopage || ':' || t_session || ':::::' || '&notification_msg=' || APEX_UTIL.URL_Encode('Access Token is invalid') || '/');

    END IF;

      -- if no error is received we can log in the user in our apex application
      if t_error is null then
LOG('oauth2callback: ' || 'no error in response, continue to s4sa_oauth_pck.do_oauth_login');
         s4sa_oauth_pck.do_oauth_login
         ( p_provider     => 'GOOGLE'
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

      else -- we did receive an error, go back to the loginpage and show the message.
        LOG('oauth2callback: ' || 'error in response, redirecting to login page');
        OWA_UTIL.Redirect_URL('f?p=' || t_appid || ':' || t_gotopage || ':' || t_session || ':::::' || '&notification_msg=' || APEX_UTIL.URL_Encode(t_error) || '/');
        
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
  ( p_gotopage       in varchar2 default null
  ) 
  is
    t_url     varchar2(32767);
  begin
  
    t_url := 'https://accounts.google.com/o/oauth2/auth?client_id=' || g_provider.client_id 
                        || '&redirect_uri='  || g_provider.redirect_uri 
                        || '&scope='         || apex_util.url_encode(g_provider.scope)
                        || '&state='         || v('APP_SESSION') || ':' || v('WORKSPACE_ID') || ':' || v('APP_ID') || ':' || p_gotopage
                        || '&response_type=' || 'code'  -- mandatory for google
                        || CASE g_provider.Force_Approval
                            WHEN 'Y' THEN '&prompt=' || APEX_UTIL.URL_Encode('select_account consent')
                            ELSE ''
                        END
                        || '&include_granted_scopes=true'
                        || g_provider.extras
                        ;
                           
    owa_util.redirect_url ( t_url );

    apex_application.stop_apex_engine;

  end redirect_oauth2;


FUNCTION Token_Is_Valid(gToken IN VARCHAR2)
RETURN BOOLEAN
AS

    tResponse S4SA_OAUTH_PCK.RESPONSE_TYPE;
    tJSON CLOB := EMPTY_CLOB();

BEGIN

    IF gToken IS NULL THEN

        RETURN FALSE;

    END IF;

    tResponse := Do_Request
    (
        p_api_uri => 'https://www.googleapis.com/oauth2/v3/tokeninfo',
        p_method  => S4SA_OAUTH_PCK.G_HTTP_METHOD_POST_FORM,
        p_body => 'access_token=' || gToken
    );

    IF COALESCE(LENGTH(tResponse), 0) > 0 THEN

        BEGIN

            tJSON := tResponse;

        EXCEPTION
        WHEN OTHERS THEN

            RETURN FALSE;

        END;

    ELSE

        RAISE_APPLICATION_ERROR(-20000, 'No response received.');

    END IF;

    IF
    (
        --{"error":"invalid_token"}
        JSON_Exists(tJSON, '$.error')
        --also returns {"error_description": "Invalid Value"}
        OR JSON_Exists(tJSON, '$.error_description')
    ) THEN

        --By design, no additional information is given as to the reason for the failure. 
        RETURN FALSE;

    ELSE

        --DBMS_OUTPUT.Put_Line(tResponse);
        
        IF g_provider.Client_ID = JSON_Value(tJSON, '$.aud') THEN

            RETURN TRUE;

        ELSE

            RETURN FALSE;

        END IF;

    END IF;

END Token_Is_Valid;


begin
  
  g_provider.api_key        := s4sa_oauth_pck.get_setting('S4SA_GGL_API_KEY');
  g_provider.client_id      := s4sa_oauth_pck.get_setting('S4SA_GGL_CLIENT_ID');
  g_provider.client_secret  := s4sa_oauth_pck.get_setting('S4SA_GGL_CLIENT_SECRET');
  g_provider.redirect_uri   := s4sa_oauth_pck.get_setting('S4SA_GGL_REDIRECT_URL');
  g_provider.extras         := s4sa_oauth_pck.get_setting('S4SA_GGL_EXTRAS');
  g_provider.scope          := s4sa_oauth_pck.get_setting('S4SA_GGL_SCOPE');
  g_provider.force_approval := s4sa_oauth_pck.get_setting('S4SA_GGL_FORCE_APPROVAL');
  
end s4sg_auth_pck;
/