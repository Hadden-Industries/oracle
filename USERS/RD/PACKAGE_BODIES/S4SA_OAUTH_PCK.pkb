CREATE OR REPLACE PACKAGE BODY  "S4SA_OAUTH_PCK" as

cursor c_oauth_user(p_provider in apex_collections.c001%type)
  is   select c.c001   as provider
       ,      c.c002   as session_id
       ,      c.c003   as gotopage
       ,      c.c004   as code
       ,      c.c005   as access_token
       ,      c.c006   as token_type
       ,      c.c007   as id_token
       ,      c.c008   as error
       ,      c.c009   as provider_id
       ,      c.c010   as email
       ,      c.c011   as verified
       ,      c.c012   as user_name
       ,      c.c013   as given_name
       ,      c.c014   as family_name
       ,      c.c015   as link
       ,      c.c016   as picture
       ,      c.c017   as gender
       ,      c.c018   as locale
       ,      c.c019   as hd
       ,      c.c020   as user_session_id
       ,      c.c021   as time_zone
       ,      c.n001   as expires_in
       ,      c.d001   as logindate
       ,      c.d002   as date_birth
       from   apex_collections c
       where  c.collection_name = g_settings.collection_name
         and  c.c001            = p_provider;
r_oauth_user c_oauth_user%rowtype;

PROCEDURE LOG(Comments IN VARCHAR2)
AS

BEGIN

    CREATE_DEBUGLOG_ENTRY(gc_ObjectName, Comments);

END LOG;

function oauth_email
  ( p_provider in apex_collections.c001%type
  ) return varchar2
is
begin
  open c_oauth_user(p_provider);
  fetch c_oauth_user into r_oauth_user;
  close c_oauth_user;
  return r_oauth_user.email;
end oauth_email;
         
function oauth_token
  ( p_provider in apex_collections.c001%type
  ) return varchar2
is
begin
  open c_oauth_user(p_provider);
  fetch c_oauth_user into r_oauth_user;
  close c_oauth_user;
  return r_oauth_user.access_token;
end oauth_token;
         
function oauth_user_pic
  ( p_provider in apex_collections.c001%type
  ) return varchar2
is
begin
  open c_oauth_user(p_provider);
  fetch c_oauth_user into r_oauth_user;
  close c_oauth_user;
  return r_oauth_user.picture;
end oauth_user_pic;
         
function oauth_user_name
  ( p_provider in apex_collections.c001%type
  ) return varchar2
is
begin
  open c_oauth_user(p_provider);
  fetch c_oauth_user into r_oauth_user;
  close c_oauth_user;
  return r_oauth_user.user_name;
end oauth_user_name;
         
function oauth_user_locale
  ( p_provider in apex_collections.c001%type
  ) return varchar2
is
begin
  open c_oauth_user(p_provider);
  fetch c_oauth_user into r_oauth_user;
  close c_oauth_user;
  return r_oauth_user.locale;
end oauth_user_locale;
  

function g_collname$ return apex_collections.collection_name%type is begin return g_settings.collection_name; end;

/*****************************************************************************
  AUTH_SENTRY
  description   : sentry function for the authentication plugin
                  is executed before every page.
                  checks if google session is still valid
  change history:
  date          name         remarks
  februari 2015 R.Martens    Initial version
*****************************************************************************/
function auth_sentry
  ( p_authentication in apex_plugin.t_authentication
  , p_plugin         in apex_plugin.t_plugin
  , p_is_public_page in boolean 
  ) return apex_plugin.t_authentication_sentry_result
is
  t_retval         apex_plugin.t_authentication_sentry_result;
  t_seconds_left   number;
  cursor c_oauth_user
  is     select c.n001 - ((SYSDATE_UTC - c.d001) * 24 * 60 * 60) as seconds_left
         from   apex_collections c
         where  c.collection_name = g_settings.collection_name;
begin
    
    --https://community.oracle.com/thread/2285805?tstart=0
    IF p_is_public_page THEN
        
        t_retval.is_valid := TRUE;
        
        RETURN t_retval;
        
    END IF;
    
  open c_oauth_user;
  fetch c_oauth_user into t_seconds_left;
  close c_oauth_user;
    
  t_retval.is_valid := t_seconds_left > g_settings.grace_period;
    
  -- we could greatly improve usability when we can get a new token from google instead of just returning false here.
  if not t_retval.is_valid then
    -- get a new token
    null;
  end if;
    
  return t_retval;
    
end auth_sentry;

/*****************************************************************************
  AUTHENTICATE
  description   : 
  change history:
  date          name         remarks
  18-5-2015     R.Martens    Initial version
*****************************************************************************/
function authenticate
  ( p_authentication in apex_plugin.t_authentication
  , p_plugin         in apex_plugin.t_plugin
  , p_password       in varchar2
  ) return apex_plugin.t_authentication_auth_result
is
  t_retval  apex_plugin.t_authentication_auth_result;
  t_request varchar2(255) := v('REQUEST');
begin
  
  case t_request
    when g_settings.login_request_google then

      s4sg_auth_pck.authenticate;

    when g_settings.login_request_facebook then
      FACEBOOK.authenticate;
    WHEN g_settings.login_request_facebook_debug THEN
      FACEBOOK.authenticate(1);
    when g_settings.login_request_linkedin then
      LINKEDIN.authenticate;
    else
      return null;
  end case;

  t_retval.is_authenticated := true;
  return t_retval;

  return null;
end;

-- used to add an extra "login" to the current user
procedure authenticate
  ( p_request in varchar2 
  )
is
begin
  case p_request
    when g_settings.login_request_google then
      s4sg_auth_pck.authenticate;
    when g_settings.login_request_facebook then
      FACEBOOK.authenticate;
    when g_settings.login_request_linkedin then
      LINKEDIN.authenticate;
    else
      null;
  end case;
  
end authenticate;
    
procedure do_oauth_login
  ( p_provider     in varchar2 
  , p_session      in varchar2
  , p_workspaceid  in varchar2
  , p_appid        in varchar2
  , p_gotopage     in varchar2
  , p_code         in varchar2
  , p_access_token in varchar2
  , p_token_type   in varchar2
  , p_expires_in   in varchar2
  , p_id_token     in varchar2
  , p_error        in varchar2
  , p_oauth_user   in s4sa_oauth_pck.oauth2_user
  )
is
  t_coll_seq_id   apex_collections.seq_id%type;
  t_reccount      pls_integer;
  l_username VARCHAR2(255 BYTE);
    nDocument_ID DOCUMENT.ID%TYPE;
    nPerson_ID PERSON.ID%TYPE;
    nPersonName_ID PERSONNAME.ID%TYPE;
    vImage_URL IMAGE.URL%TYPE;
    nImage_Document_ID IMAGE.DOCUMENT_ID%TYPE;
    yEmailAddress#Person_RowID ROWID;
    dEmailVerifiedAt EMAILADDRESS#PERSON.DateTimeVerified%TYPE;
    vEmailAddress VARCHAR2(256 BYTE);

  l_goto          varchar2(100) := 'f?p=' || p_appid    || ':' || p_gotopage      || ':' || p_session;

  cursor c_coll_member_id
  is         select c.seq_id
             --into   t_coll_seq_id
             from   apex_collections c
             where  c.collection_name = g_settings.collection_name
               and  c.c001            = p_provider;
begin
LOG('Do_OAuth_Login: ' || 'started');
    -- validate and canonicalise the email address
    BEGIN
        
        SELECT CANONICALISE_EMAILADDRESS
        (
            T_EMAILADDRESS(RootZoneDataBase_ID, LocalPart, Subdomains)
        )
        INTO vEmailAddress
        FROM TABLE
        (
            PARSEEMAILADDRESS(p_oauth_user.email)
        );
        LOG('Do_OAuth_Login: ' || 'parsed email address');
        --if cannot parse the email address
        IF (p_oauth_user.email IS NOT NULL AND vEmailAddress IS NULL) THEN
            LOG('Do_OAuth_Login: ' || 'could not parse email address');
            EMAIL.SEND
            (
                Sender => 'info@jym.fit',
                Recipient => 'maksym.shostak@haddenindustries.com',
                Subject => 'Jym error - cannot parse email address',
                Msg => p_oauth_user.email
            );
            LOG('Do_OAuth_Login: ' || 'sent email');
        END IF;
        
        -- if Facebook request comes back with no email
        IF (p_provider = 'FACEBOOK' AND vEmailAddress IS NULL) THEN
            -- redirect to page explaining how to associate an email address to your Facebook account
            OWA_UTIL.Redirect_URL(curl => APEX_UTIL.Prepare_URL('f?p=' || p_appid || ':212'));
            
            --AUTH_UNKNOWN_USER
            APEX_UTIL.Set_Authentication_Result(p_code => 1);
            
            RETURN;
            
        END IF;
        
        l_username := SUBSTR(p_provider || ':' || vEmailAddress, 1, 255);
        LOG('Do_OAuth_Login: ' || 'assigned email address to username');
    EXCEPTION
    WHEN OTHERS THEN
        LOG('Do_OAuth_Login: ' || 'exception parsing email address');
        OWA_UTIL.Redirect_URL(curl => APEX_UTIL.Prepare_URL('f?p=' || p_appid || ':login'));
        
        --AUTH_UNKNOWN_USER
        APEX_UTIL.Set_Authentication_Result(p_code => 1);
        
        RETURN;
        
    END;
    
    wwv_flow_api.set_security_group_id(p_workspaceid);
    LOG('Do_OAuth_Login: ' || 'set security group id to ' || p_workspaceid);
    apex_application.g_flow_id  := p_appid;
    LOG('Do_OAuth_Login: ' || 'set app id to ' || p_appid);
    apex_custom_auth.set_session_id(p_session_id => p_session);
    LOG('Do_OAuth_Login: ' || 'set session id to ' || p_session);
    --apex_custom_auth.define_user_session(p_oauth_user.id, p_session);
    
    BEGIN
        
        BEGIN
            
            LOG('Do_OAuth_Login: ' || 'finding person UUID');
            
            SELECT UUID,
            ID,
            EmailAddress#Person_RowID,
            DateTimeVerified
            INTO l_username,
            nPerson_ID,
            yEmailAddress#Person_RowID,
            dEmailVerifiedAt
            FROM
            (
                SELECT CANONICALISE_UUID(C.UUID) AS UUID,
                C.ID,
                B.ROWID AS EmailAddress#Person_RowID,
                B.DateTimeVerified,
                --in case multiple people claim to use the same email address, order by verified, then the start date
                ROW_NUMBER() OVER (ORDER BY B.DateTimeVerified NULLS LAST, B.DateStart NULLS FIRST) AS RN
                FROM EMAILADDRESS A
                INNER JOIN (EMAILADDRESS#PERSON AS OF PERIOD FOR VALID_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE)) B
                    ON A.UUID = B.EmailAddress_UUID
                INNER JOIN PERSON C
                    ON B.Person_ID = C.ID
                WHERE A.LocalPart || '@' || A.Subdomains || '.' || LOWER(A.RootZoneDataBase_ID) = vEmailAddress
                AND C.ID IN
                (
                    SELECT Person_ID
                    FROM PERSON#PRIVILEGE AS OF PERIOD FOR VALID_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE)
                    WHERE Privilege_ID = 
                    (
                        SELECT ID
                        FROM PRIVILEGE
                        WHERE Name = 'Log in'
                    )
                )
            )
            --prefer the oldest verified one
            WHERE RN = 1;
            
        EXCEPTION
        WHEN OTHERS THEN
            
            LOG('Do_OAuth_Login: ' || 'error finding person UUID: ' || SQLErrM);
            RAISE NO_DATA_FOUND;
            
        END;
        
        LOG('Do_OAuth_Login: ' || 'found valid email address ' || vEmailAddress);
        
        apex_custom_auth.define_user_session(l_username, p_session);
        LOG('Do_OAuth_Login: ' || 'defined user session with username ' || l_username || ' and session ' || p_session);
        
        --Only trust verified emails, so people can't link email addresses they don't control
        IF (dEmailVerifiedAt IS NULL OR SYSDATE_UTC <= dEmailVerifiedAt) THEN
            LOG('Do_OAuth_Login: ' || 'email address unverified');
            IF
            (
                p_oauth_user.verified
                --All Facebook emails are verified
                OR p_provider = 'FACEBOOK'
            ) THEN
                
                UPDATE
                EMAILADDRESS#PERSON
                SET DateTimeVerified = SYSDATE_UTC
                WHERE RowID = yEmailAddress#Person_RowID;
                
            ELSE
                LOG('Do_OAuth_Login: ' || 'cannot get verified status of email address');
                RAISE NO_DATA_FOUND;
                
            END IF;
            
        END IF;
        
        
        BEGIN
            
            SELECT C.Name AS Sex_Name
            INTO vImage_URL
            FROM PERSON A
            INNER JOIN CURR$NATURALPERSONGENDER B
                ON A.ID = B.Person_ID
            INNER JOIN SEX C
                ON B.Sex_ID = C.ID
            WHERE A.ID = nPerson_ID
            AND C.Name IN ('Male', 'Female');
            LOG('Do_OAuth_Login: ' || 'found gender');
        --when there is no data
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            LOG('Do_OAuth_Login: ' || 'no gender found');
            IF (UPPER(p_oauth_user.gender) IN ('MALE', 'FEMALE')) THEN
                LOG('Do_OAuth_Login: ' || 'return value of gender is correct');
                INSERT
                INTO NATURALPERSONGENDER
                (
                    PERSON_ID,
                    SEX_ID
                )
                VALUES
                (
                    nPerson_ID,
                    (
                        SELECT ID
                        FROM SEX
                        WHERE UPPER(Name) = UPPER(p_oauth_user.gender)
                    )
                );
                LOG('Do_OAuth_Login: ' || 'inserted gender');
            END IF;
            
        END;
        
        
        BEGIN
            
            SELECT TO_CHAR(DateTimeBirth, 'YYYYMMDD')
            INTO vImage_URL
            FROM CERTIFICATEBIRTH AS OF PERIOD FOR TRANSACTION_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE)
            WHERE Person_ID = nPerson_ID
            AND DateTimeBirth IS NOT NULL
            FETCH FIRST 1 ROWS ONLY;
            LOG('Do_OAuth_Login: ' || 'got DoB');
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            IF (p_oauth_user.Date_Birth IS NOT NULL) THEN
                
                INSERT
                INTO DOCUMENT
                (
                    NAME
                )
                VALUES
                (
                    NULL
                )
                RETURNING ID
                INTO nDocument_ID;
                
                INSERT
                INTO CERTIFICATEBIRTH
                (
                    DOCUMENT_ID,
                    PERSON_ID,
                    DATETIMEBIRTH
                )
                VALUES
                (
                    nDocument_ID,
                    nPerson_ID,
                    p_oauth_user.Date_Birth
                );
                
            END IF;
            
        END;
        
        
        BEGIN
            
            SELECT C.URL
            INTO vImage_URL
            FROM DOCUMENT#PERSON AS OF PERIOD FOR VALID_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) A
            INNER JOIN DOCUMENTTOPERSONTYPE B
                ON A.DocumentToPersonType_ID = B.ID
            INNER JOIN IMAGE C
                ON A.Document_ID = C.Document_ID
            INNER JOIN DOCUMENT AS OF PERIOD FOR VALID_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) D
                ON C.Document_ID = D.ID
            WHERE A.Person_ID = nPerson_ID
            AND B.Name = 'Profile image'
            --Figure out why sometimes get duplication
            FETCH FIRST 1 ROWS ONLY;
            LOG('Do_OAuth_Login: ' || 'got profile picture');
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            IF p_oauth_user.Picture IS NOT NULL THEN
                
                INSERT
                INTO DOCUMENT
                (
                    COMMENTS
                )
                VALUES
                (
                    ''
                ) RETURNING ID INTO nImage_Document_ID;
                
                INSERT
                INTO IMAGE
                (
                    DOCUMENT_ID,
                    URL
                )
                --
                VALUES
                (
                    nImage_Document_ID,
                    p_oauth_user.Picture
                );
                
                INSERT
                INTO DOCUMENT#PERSON
                (
                    PERSON_ID,
                    DOCUMENTTOPERSONTYPE_ID,
                    DOCUMENT_ID,
                    DATETIMESTART
                )
                --
                VALUES
                (
                    nPerson_ID,
                    (
                        SELECT ID
                        FROM DOCUMENTTOPERSONTYPE
                        WHERE Name = 'Profile image'
                    ),
                    nImage_Document_ID,
                    SYSDATE_UTC
                );
                
            END IF;
            
        END;
        
        
        BEGIN
            
            --Add given name if none existed before
            SELECT A.Value
            INTO vImage_URL
            FROM CURR$PERSONNAME A
            WHERE A.Person_ID = nPerson_ID
            AND A.IsSurname = 'F'
            FETCH FIRST 1 ROWS ONLY;
            LOG('Do_OAuth_Login: ' || 'got Given Name');
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            IF (p_oauth_user.Given_Name IS NOT NULL) THEN
                
                INSERT
                INTO PERSONNAME
                (
                    PERSON_ID,
                    ISSURNAME,
                    SORTORDER,
                    VALUE,
                    COMMENTS
                )
                --
                VALUES
                (
                    nPerson_ID,
                    'F',
                    1,
                    p_oauth_user.Given_Name,
                    'Source: ' || INITCAP(p_provider)
                )
                RETURNING ID INTO nPersonName_ID;
                
                INSERT
                INTO PERSONNAMEPREFERENCE
                (
                    PERSONNAME_ID
                )
                VALUES
                (
                    nPersonName_ID
                );
                
            END IF;
            
        END;
        
        
        BEGIN
        
            --Add surname if none existed before
            SELECT A.Value
            INTO vImage_URL
            FROM CURR$PERSONNAME A
            WHERE A.Person_ID = nPerson_ID
            AND A.IsSurname = 'T'
            FETCH FIRST 1 ROWS ONLY;
            LOG('Do_OAuth_Login: ' || 'got Surname');
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            IF (p_oauth_user.Family_Name IS NOT NULL) THEN
                
                INSERT
                INTO PERSONNAME
                (
                    PERSON_ID,
                    ISSURNAME,
                    SORTORDER,
                    VALUE,
                    COMMENTS
                )
                --
                VALUES
                (
                    nPerson_ID,
                    'T',
                    1,
                    p_oauth_user.Family_Name,
                    'Source: ' || INITCAP(p_provider)
                )
                RETURNING ID INTO nPersonName_ID;
                
                INSERT
                INTO PERSONNAMEPREFERENCE
                (
                    PERSONNAME_ID
                )
                VALUES
                (
                    nPersonName_ID
                );
                
            END IF;
            
        END;
    
    --Handle when the user doesn't exist
    EXCEPTION
    WHEN OTHERS THEN
        LOG('Do_OAuth_Login: ' || 'user doesn''t seem to exist: ' || SQLErrM);
        OWA_UTIL.Redirect_URL(curl => APEX_UTIL.Prepare_URL('f?p=' || p_appid || ':111::::111:P111_EMAIL:' || LOWER(vEmailAddress)));
        
        --AUTH_UNKNOWN_USER
        APEX_UTIL.Set_Authentication_Result(p_code => 1);
        
        RETURN;
        
    END;

  if apex_collection.collection_exists(p_collection_name => g_settings.collection_name) then
  LOG('Do_OAuth_Login: ' || 'collection with name ' || g_settings.collection_name || ' exists');
    open c_coll_member_id;
    fetch c_coll_member_id into t_coll_seq_id;
    close c_coll_member_id;
        LOG('Do_OAuth_Login: ' || 'fetched member id');
  else
  LOG('Do_OAuth_Login: ' || 'collection with name ' || g_settings.collection_name || ' doesn''t exist');
  begin
  apex_collection.create_collection(g_settings.collection_name);

    --apex_collection.create_or_truncate_collection(g_settings.collection_name);
    LOG('Do_OAuth_Login: ' || 'created collection with name ' || g_settings.collection_name);
    exception
    when others then
    LOG('Do_OAuth_Login: ' || 'failed creating collection with name ' || g_settings.collection_name || SQLErrM);
    end;
    
    t_coll_seq_id := null;
    
  end if;
  
  if t_coll_seq_id is null then
  begin
    LOG
    (
        'Do_OAuth_Login: ' || 'adding member with values:' || CHR(10)
        || 'p_collection_name: ' || g_settings.collection_name || CHR(10)
        || 'p_c001: ' || p_provider || CHR(10)
        || 'p_c002: ' || apex_custom_auth.get_session_id || CHR(10)
        || 'p_c003: ' || p_gotopage || CHR(10)
        || 'p_c004: ' || p_code || CHR(10)
        || 'p_c005: ' || p_access_token || CHR(10)
        || 'p_c006: ' || p_token_type || CHR(10)
        || 'p_c007: ' || p_id_token || CHR(10)
        || 'p_c008: ' || p_error || CHR(10)
        || 'p_c009: ' || p_oauth_user.id || CHR(10)
        || 'p_c010: ' || vEmailAddress || CHR(10)
        || 'p_c011: ' || case when p_oauth_user.verified then 'TRUE' else 'FALSE' end || CHR(10)
        || 'p_c012: ' || p_oauth_user.name || CHR(10)
        || 'p_c013: ' || p_oauth_user.given_name || CHR(10)
        || 'p_c014: ' || p_oauth_user.family_name || CHR(10)
        || 'p_c015: ' || p_oauth_user.link || CHR(10)
        || 'p_c016: ' || p_oauth_user.picture || CHR(10)
        || 'p_c017: ' || p_oauth_user.gender || CHR(10)
        || 'p_c018: ' || p_oauth_user.locale || CHR(10)
        || 'p_c019: ' || p_oauth_user.hd || CHR(10)
        || 'p_c020: ' || p_session || CHR(10)
        || 'p_c021: ' || p_oauth_user.time_zone || CHR(10)
        || 'p_n001: ' || p_expires_in || CHR(10)
        || 'p_d001: ' || SYSDATE_UTC || CHR(10)
        || 'p_d002: ' || p_oauth_user.date_birth
    );
    /*INSERT
    INTO APEX_COLLECTIONS
    (
        COLLECTION_NAME,
        --SEQ_ID,
        C001,
        C002,
        C003,
        C004,
        C005,
        C006,
        C007,
        C008,
        C009,
        C010,
        C011,
        C012,
        C013,
        C014,
        C015,
        C016,
        C017,
        C018,
        C019,
        C020,
        C021,
        N001,
        D001,
        D002
    )
    VALUES
    (
        g_settings.collection_name,
        p_provider,
        apex_custom_auth.get_session_id,
        p_gotopage,
        p_code,
        p_access_token,
        p_token_type,
        p_id_token,
        p_error,
        p_oauth_user.id,
        vEmailAddress,
        'TRUE',--p_oauth_user.verified, --case when p_oauth_user.verified then 'TRUE' else 'FALSE' end,
        p_oauth_user.name,
        p_oauth_user.given_name,
        p_oauth_user.family_name,
        p_oauth_user.link,
        p_oauth_user.picture,
        p_oauth_user.gender,
        p_oauth_user.locale,
        p_oauth_user.hd,
        p_session,
        p_oauth_user.time_zone,
        p_expires_in,
        SYSDATE_UTC,
        p_oauth_user.date_birth
    );*/
    /*apex_collection.add_member(
        p_collection_name => g_settings.collection_name
      , p_c001            => p_provider
      , p_c002            => apex_custom_auth.get_session_id
      , p_c003            => p_gotopage
      , p_c004            => p_code
      , p_c005            => p_access_token
      , p_c006            => p_token_type
      , p_c007            => p_id_token
      , p_c008            => p_error
      , p_c009            => p_oauth_user.id
      , p_c010            => vEmailAddress
      , p_c011            => case when p_oauth_user.verified then 'TRUE' else 'FALSE' end
      , p_c012            => p_oauth_user.name
      , p_c013            => p_oauth_user.given_name
      , p_c014            => p_oauth_user.family_name
      , p_c015            => p_oauth_user.link
      , p_c016            => p_oauth_user.picture
      , p_c017            => p_oauth_user.gender
      , p_c018            => p_oauth_user.locale
      , p_c019            => p_oauth_user.hd
      , p_c020            => p_session
      , p_c021            => p_oauth_user.time_zone
      , p_n001            => p_expires_in
      , p_d001            => SYSDATE_UTC
      , p_d002            => p_oauth_user.date_birth
      );*/
      ADD_COLLECTION_MEMBER
      (
            g_Security_Group_ID => p_workspaceid,
            g_Flow_ID => p_appid,
            g_SessionID => p_session,
            g_Collection_Name => g_settings.collection_name,
            g_c001 => p_provider,
            g_c002 => apex_custom_auth.get_session_id,
            g_c003 => p_gotopage,
            g_c004 => p_code,
            g_c005 => p_access_token,
            g_c006 => p_token_type,
            g_c007 => p_id_token,
            g_c008 => p_error,
            g_c009 => p_oauth_user.id,
            g_c010 => vEmailAddress,
            g_c011 => CASE WHEN p_oauth_user.verified THEN 'TRUE' ELSE 'FALSE' END,
            g_c012 => p_oauth_user.name,
            g_c013 => p_oauth_user.given_name,
            g_c014 => p_oauth_user.family_name,
            g_c015 => p_oauth_user.link,
            g_c016 => p_oauth_user.picture,
            g_c017 => p_oauth_user.gender,
            g_c018 => p_oauth_user.locale,
            g_c019 => p_oauth_user.hd,
            g_c020 => p_session,
            g_c021 => p_oauth_user.time_zone,
            g_n001 => p_expires_in,
            g_d001 => SYSDATE_UTC,
            g_d002 => p_oauth_user.date_birth
      );
      --test_oauth2(apex_custom_auth.get_session_id);
      LOG('Do_OAuth_Login: ' || 'added member');
      exception
    when others then
    LOG('Do_OAuth_Login: ' || 'failed adding member: ' || SQLErrM);
    RAISE;
    end;
      
  else
  LOG('Do_OAuth_Login: ' || 'reused collection');
    apex_collection.update_member(
        p_collection_name => g_settings.collection_name
      , p_seq             => t_coll_seq_id
      , p_c001            => p_provider
      , p_c002            => apex_custom_auth.get_session_id
      , p_c003            => p_gotopage
      , p_c004            => p_code
      , p_c005            => p_access_token
      , p_c006            => p_token_type
      , p_c007            => p_id_token
      , p_c008            => p_error
      , p_c009            => p_oauth_user.id
      , p_c010            => vEmailAddress
      , p_c011            => case when p_oauth_user.verified then 'TRUE' else 'FALSE' end
      , p_c012            => p_oauth_user.name
      , p_c013            => p_oauth_user.given_name
      , p_c014            => p_oauth_user.family_name
      , p_c015            => p_oauth_user.link
      , p_c016            => p_oauth_user.picture
      , p_c017            => p_oauth_user.gender
      , p_c018            => p_oauth_user.locale
      , p_c019            => p_oauth_user.hd
      , p_c020            => p_session
      , p_c021            => p_oauth_user.time_zone
      , p_n001            => p_expires_in
      , p_d001            => SYSDATE_UTC
      , p_d002            => p_oauth_user.date_birth
      );
      LOG('Do_OAuth_Login: ' || 'updated collection member');
  end if;

  select count(*)
  into   t_reccount
  from   apex_collections c
  where  c.collection_name = g_settings.collection_name;
  LOG('Do_OAuth_Login: ' || 'got t_recount');
  if t_reccount = 1 then
LOG('Do_OAuth_Login: ' || 't_recount = 1');
    APEX_CUSTOM_AUTH.Login
    (
        p_uname=> l_username,
        p_password => p_access_token,
        p_session_id => p_session,
        p_app_page => p_appid || ':' || p_gotopage,
        --If TRUE, do not upper p_uname during session registration
        p_preserve_case => TRUE
    );
LOG('Do_OAuth_Login: ' || 'Login via custom');
    apex_authentication.send_login_username_cookie
      ( p_username    => l_username
      , p_cookie_name => 'ORA_WWV_APP_' || p_appid );
  
  else
    LOG('Do_OAuth_Login: ' || 't_recount != 1');
    OWA_UTIL.Redirect_URL(curl => l_goto);
    
  end if;

    APEX_UTIL.Set_Authentication_Result(p_code => 0);
    LOG('Do_OAuth_Login: ' || 'set authentication result ' || 0);
    OWA_UTIL.Redirect_URL(curl => 'f?p=' || p_appid || ':' || CASE WHEN p_gotopage = '101' THEN 'home' ELSE p_gotopage END || ':' || p_session || '');
    LOG('Do_OAuth_Login: ' || 'redirected to page ' || CASE WHEN p_gotopage = '101' THEN 'home' ELSE p_gotopage END);
end do_oauth_login;

/******************************************************************************/
procedure store_request
  ( p_provider        in s4sa_requests.request_source%type
  , p_request_uri     in s4sa_requests.request_uri%type
  , p_request_type    in s4sa_requests.request_type%type
  , p_request_headers in s4sa_requests.request_headers%type
  , p_body            in s4sa_requests.request_body%type
  , p_response        in s4sa_requests.response%type)
  is
    pragma autonomous_transaction;
  begin
    insert into s4sa_requests
        (request_source, request_uri, request_type, request_headers, request_body, response)
      values
        (p_provider, p_request_uri, p_request_type, p_request_headers, p_body, p_response);
    commit;
  end store_request;
  
/******************************************************************************/
function to_ts
  ( p_string in varchar2
  , p_format in varchar2 default null
  ) return timestamp
  is
    t_format   varchar2(30) := nvl(p_format, 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  begin
    return to_timestamp(p_string, t_format);
  end to_ts;

/******************************************************************************/
function to_ts_tz
    ( p_string in varchar2
    , p_format in varchar2 default null
    ) return timestamp with time zone
  is
    t_format   varchar2(30) := nvl(p_format, 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
  begin
    return to_timestamp_tz(p_string, t_format);
  end to_ts_tz;
  
/******************************************************************************/
function boolconvert
  ( p_boolean in boolean
  ) return varchar2
  is
  begin
    return case when p_boolean then 'Y' else 'N' end;
  end boolconvert;
  
  function boolconvert
    ( p_varchar in varchar2
    ) return varchar2
  is
  begin
    return case when p_varchar = 'Y' then 'true' else 'false' end;
  end boolconvert;
    
/******************************************************************************/
function check_for_error
  ( p_response    in clob
  , p_raise_error in boolean default true
  ) return boolean
  is
  
  t_error          varchar2(32767);
    t_error_code     number;
  
  begin
    if nullif (length (p_response), 0) is not null then
    

      t_error      := JSON_Value(p_response, '$.error.message');
      t_error_code := JSON_Value(p_response, '$.error.code' RETURNING NUMBER);
      
    if t_error is null then
      t_error_code := JSON_Value(p_response, '$.errorCode' RETURNING NUMBER);
      if t_error_code is not null then
        t_error  := JSON_Value(p_response, '$.message');
      end if;
    end if;
    
    case
      when t_error is null then
        return true;
      when p_raise_error   then
        raise_application_error(-20000 - t_error_code, t_error);
      else
        return false;
    end case;
                            
    else
      return true;
    end if;
  end;
  
  /*procedure check_for_error
    ( p_response        in CLOB
    )
  is
  begin
    
    if check_for_error(p_response => p_response, p_raise_error => true)
    then
      null;
    end if;
    
  end check_for_error;*/
  
/******************************************************************************/
procedure check_for_error
  ( p_response     in clob
  , p_null_err_msg in varchar2 default 'No response received where expected.'
  )
  is
  begin
    if nullif (length (p_response), 0) is not null then
      if check_for_error(p_response => p_response, p_raise_error => true) then
        null;
      end if;
    elsif p_null_err_msg is not null then
      raise_application_error(-20000, p_null_err_msg);
    end if;
  end check_for_error;
  
  function object_to_xml
    ( p_object anytype
    , p_root_element varchar2
    ) return xmltype
  is
    l_retval xmltype;
  begin
    select sys_xmlgen(p_object,xmlformat(p_root_element)) into l_retval from dual;
    return l_retval;
  end object_to_xml;

/******************************************************************************/
function is_plsqldev
  return boolean
  is
  begin
    return sys_context('USERENV', 'MODULE')='PL/SQL Developer';
  end;

function trim
  ( p_haystack in varchar2
  , p_needle   in varchar2
  ) return varchar2
is
  t_retval varchar(32767) := p_haystack;
begin
  for ii in 1..length(p_needle) loop
    t_retval := trim(substr(p_needle, ii, 1) from t_retval);
  end loop;
  return t_retval;
end trim;

function addslashes
  ( p_string in clob 
  ) return clob
is
  l_retval clob := p_string;
begin
  l_retval := replace(l_retval, '\', '\\');
  l_retval := replace(l_retval, '"', '\"');
  l_retval := replace(l_retval, '''', '\''');
  return l_retval;
end addslashes;

function addslashes
  ( p_string in varchar2
  ) return varchar2
is
begin
  return substr(addslashes(to_clob(p_string)), 1, 32767);
end addslashes;

function get_setting
  ( p_code in s4sa_settings.code%type
  ) return s4sa_settings.meaning%type deterministic
is
  cursor c_setting
  is select s.meaning
     from   s4sa_settings s
     where  s.code = p_code;
  l_retval s4sa_settings.meaning%type;
begin
  open c_setting;
  fetch c_setting into l_retval;
  close c_setting;
  return l_retval;
end get_setting;

procedure present_error
  ( p_workspaceid in number
  , p_appid       in number
  , p_gotopage    in varchar2
  , p_session     in varchar2
  , p_errormsg    in varchar2
  )
is
  t_error varchar2(32767);
  t_uri   varchar2(32767);
begin
  
  wwv_flow_api.set_security_group_id(p_workspaceid);
  apex_application.g_flow_id  := p_appid;
  apex_custom_auth.set_session_id(p_session_id => p_session);
  apex_custom_auth.define_user_session(null, p_session);
        
  t_error := p_errormsg;
  --t_error := 'test error';
        
  t_uri := '/f?p=#APPID#:#PAGEID#:#SESSION#::::::';
  t_uri := replace(t_uri, '#APPID#'  , p_appid);
  t_uri := replace(t_uri, '#PAGEID#' , p_gotopage);
  t_uri := replace(t_uri, '#SESSION#', p_session);
  t_uri := t_uri || '&notification_msg=' || t_error || '/';
  t_uri := apex_util.prepare_url(t_uri);
  apex_application.g_print_success_message := t_error;
  owa_util.redirect_url(curl => t_uri);
end present_error;

function replace_newline
  ( p_value in varchar2
  ) return varchar2
is
  l_js_newline varchar2(2) := '\n';
begin
  return replace( replace( replace( replace( p_value
                                           , chr(10)||chr(13), l_js_newline)
                                  , chr(13) || chr(10), l_js_newline)
                         , chr(10), l_js_newline)
                , chr(13), l_js_newline);
end replace_newline;

begin
  -- initialise the settings table
  g_settings.grace_period           := get_setting('S4SA_GRACE_PERIOD');
  g_settings.wallet_path            := get_setting('S4SA_WALLET_PATH');
  g_settings.wallet_pwd             := get_setting('S4SA_WALLET_PWD');
  g_settings.collection_name        := get_setting('S4SA_COLLECTION_NAME');
  g_settings.login_request_google   := get_setting('S4SA_GGL_LOGIN_REQUEST');
  g_settings.login_request_facebook := get_setting('S4SA_FCB_LOGIN_REQUEST');
  g_settings.login_request_facebook_debug := get_setting('S4SA_FCB_LOGIN_REQUEST_DEBUG');
  g_settings.login_request_linkedin := get_setting('S4SA_LDI_LOGIN_REQUEST');
  g_settings.login_request_twitter  := get_setting('S4SA_TWT_LOGIN_REQUEST');
  g_settings.api_prefix             := get_setting('S4SA_API_PREFIX');
  
end s4sa_oauth_pck;
/