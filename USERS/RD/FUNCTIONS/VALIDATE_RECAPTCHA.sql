CREATE OR REPLACE
FUNCTION VALIDATE_RECAPTCHA
(
    p_Response VARCHAR2,
    p_IPAddress VARCHAR2
)
RETURN INTEGER
AS
    
    l_Error VARCHAR2(4000 BYTE);
    l_parm_name_list APEX_APPLICATION_GLOBAL.vc_arr2;
    l_parm_value_list APEX_APPLICATION_GLOBAL.vc_arr2;
    l_REST_Response VARCHAR2(32767 BYTE);
    l_SecretKey VARCHAR2(4000 BYTE);
    l_WalletPath ORACLEDATABASEWALLET.Path%TYPE;
    l_WalletPassword ORACLEDATABASEWALLET.Password%TYPE;
    
BEGIN
    
    IF p_Response IS NULL THEN
        
        RETURN 0;
        
    END IF;
    
    BEGIN
        
        SELECT Path,
        Password
        INTO l_WalletPath,
        l_WalletPassword
        FROM ORACLEDATABASEWALLET
        WHERE Path IS NOT NULL
        AND Password IS NOT NULL;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
        
    END;
    
    BEGIN
        
        l_SecretKey := GET_API_KEY('Google reCAPTCHA Secret Key (Invisible)', 'Jym');
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        RAISE_APPLICATION_ERROR(-20999, 'No Secret Key has been set for the reCAPTCHA! Get one at https://www.google.com/recaptcha/admin/create');
        
    END;
    
    -- Build the parameters list for the post action.
    -- See https://code.google.com/apis/recaptcha/docs/verify.html for more details
    l_parm_name_list(1) := 'secret';
    l_parm_value_list(1) := l_SecretKey;
    l_parm_name_list(2) := 'response';
    l_parm_value_list(2) := p_Response;
    l_parm_name_list(3) := 'remoteip';
    l_parm_value_list(3) := p_IPAddress;
    
    -- Set web service header rest request
    APEX_WEB_SERVICE.g_request_headers(1).name := 'Content-Type';
    APEX_WEB_SERVICE.g_request_headers(1).value := 'application/x-www-form-urlencoded';
    
    -- Call the reCaptcha REST service to verify the response against the private key
    l_REST_Response := WWV_FLOW_UTILITIES.CLOB_To_VarChar2
    (
        APEX_WEB_SERVICE.Make_REST_Request
        (
            p_url         => 'https://www.google.com/recaptcha/api/siteverify',
            p_http_method => 'POST',
            p_parm_name   => l_parm_name_list,
            p_parm_value  => l_parm_value_list,
            p_wallet_path => l_WalletPath,
            p_wallet_pwd  => l_WalletPassword
        )
    );
    
    -- Delete the request header
    APEX_WEB_SERVICE.g_request_headers.delete;
    
    -- Check the HTTPS status call
    IF APEX_WEB_SERVICE.g_status_code = '200' THEN -- sucessful call
        
        -- Check the returned json for successful validation
        APEX_JSON.Parse(l_REST_Response);
        
        IF APEX_JSON.Get_VarChar2(p_path => 'success') = 'true' THEN
            
            RETURN 1;
            
        ELSE -- success = 'false'
            
            l_Error := l_REST_Response;
            /*
                Error code	            Description
                ---------------------- ------------------------------------------------
                missing-input-secret	The secret parameter is missing.
                invalid-input-secret	The secret parameter is invalid or malformed.
                missing-input-response	The response parameter is missing.
                invalid-input-response	The response parameter is invalid or malformed.
                bad-request	            The request is invalid or malformed.
            */
            
        END IF;
        
    ELSE -- unsucessful call
        
        l_Error := 'reCAPTCHA HTTPS request status : ' || APEX_WEB_SERVICE.g_status_code;
        
    END IF;
    
    RETURN 0;
    
END;
/