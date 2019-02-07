SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE 
PACKAGE BODY COMPANIESHOUSE
AS
    
    p_APIKey VARCHAR2(4000 BYTE);
    p_HTTPVersion CONSTANT VARCHAR2(10 BYTE) := UTL_HTTP.HTTP_Version_1_1;
    p_Interval PLS_INTEGER := 5;
    p_APIPrefix VARCHAR2(4000 BYTE) := 'https://api.companieshouse.gov.uk/';
    p_WalletPath ORACLEDATABASEWALLET.Path%TYPE := '';
    p_WalletPassword ORACLEDATABASEWALLET.Password%TYPE := '';
    
    FUNCTION GET_(gURL IN VARCHAR2)
    RETURN CLOB
    AS
        
        f_Data BLOB := EMPTY_BLOB();
        f_Proxy VARCHAR2(32767 BYTE) := '';
        f_Request UTL_HTTP.REQ;
        f_Response UTL_HTTP.RESP;
        f_ResponseRaw RAW(1000);
        f_Error VARCHAR2(255 BYTE) := '';
        
    BEGIN
        
        DBMS_LOB.CreateTemporary
        (
            lob_loc => f_Data,
            cache => TRUE,
            dur => DBMS_LOB.Call
        );
        
        DBMS_LOB.Open(f_Data, DBMS_LOB.LOB_ReadWrite);
        
        BEGIN
            
            SELECT 'http://' || IPV4 || ':' || Port
            INTO f_Proxy
            FROM PROXY
            WHERE IPV4 IS NOT NULL
            AND Port IS NOT NULL;
            
            UTL_HTTP.Set_Proxy(f_Proxy, NULL);
            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            NULL;
            
        END;
        
        BEGIN
            
            UTL_HTTP.Set_Wallet(p_WalletPath, p_WalletPassword);
            
        EXCEPTION
        WHEN OTHERS THEN
            
            f_Error := SUBSTRB(SQLErrM, 1, 255);
            
            DBMS_OUTPUT.Put_Line('Error opening certificate store: ' || f_Error);
            
        END;
        
        
        f_Request := UTL_HTTP.Begin_Request
        (
            url => p_APIPrefix || gURL,
            method => 'GET',
            http_version => p_HTTPVersion,
            https_host => 'companieshouse.gov.uk'
        );
        
        UTL_HTTP.Set_Header
        (
            r => f_Request,
            name => 'Authorization',
            value => 'Basic ' || UTL_RAW.Cast_To_VarChar2
            (
                UTL_ENCODE.Base64_Encode
                (
                    UTL_RAW.Cast_To_Raw(p_APIKey || ':')
                )
            )
        );
        
        f_Response := UTL_HTTP.Get_Response(f_Request);
        
        IF f_Response.status_code = UTL_HTTP.HTTP_OK THEN
            
            BEGIN
                
                LOOP
                    
                    UTL_HTTP.Read_Raw(f_Response, f_ResponseRaw, 1000);
                    
                    DBMS_LOB.WriteAppend
                    (
                        f_Data,
                        UTL_RAW.Length(f_ResponseRaw),
                        TO_BLOB(f_ResponseRaw)
                    );
                    
                END LOOP;
                
                UTL_HTTP.End_Response(f_Response);
                
            EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN
                
                UTL_HTTP.End_Response(f_Response);
                
            END;
            
        ELSE
            
            f_Error := TO_CHAR(f_Response.status_code);
            
            UTL_HTTP.End_Response(f_Response);
            
            RETURN CASE
                WHEN f_Error = '404' THEN NULL
                ELSE f_Error
            END;
            
        END IF;
        
        RETURN BLOB_TO_CLOB(f_Data);
    
    END;
    
    
    FUNCTION COMPANY(gRegistrationID IN VARCHAR2)
    RETURN CLOB
    AS
    
    BEGIN
        
        RETURN GET_('company/' || gRegistrationID);
        
    END;
    
    
    FUNCTION SEARCH_COMPANIES
    (
        gText IN VARCHAR2,
        gItemsPerPage IN INTEGER DEFAULT NULL,
        gStartIndex IN INTEGER DEFAULT NULL
    )
    RETURN CLOB
    AS
    
    BEGIN
        
        RETURN GET_('search/companies'
        || '?q=' || UTL_URL.Escape(gText)
        || CASE
            WHEN gItemsPerPage IS NOT NULL THEN '&items_per_page=' || gItemsPerPage
            ELSE ''
        END
        || CASE
            WHEN gStartIndex IS NOT NULL THEN '&start_index=' || gStartIndex
            ELSE ''
        END);
        
    END;

    PROCEDURE IMPORT_COMPANY(gRegistrationID IN VARCHAR2)
    AS
        
        cData CLOB := EMPTY_CLOB();
        nAddress_ID ADDRESS.ID%TYPE;
        nDocument_ID DOCUMENT.ID%TYPE;
        nPerson_ID PERSON.ID%TYPE;
        nPersonName_ID PERSONNAME.ID%TYPE;
        
    BEGIN
        
        BEGIN
            
            SELECT A.Person_ID
            INTO nPerson_ID
            FROM CERTIFICATEINCORPORATION A
            INNER JOIN COMPANYREGISTER B
                ON A.Country_ID = B.Country_ID
                        AND A.CompanyRegister_Code = B.Code
            WHERE A.Country_ID = 'GBR'
            AND A.RegistrationID = gRegistrationID
            AND B.Name = 'Companies House';
            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            cData := GET_('company/' || gRegistrationID);
            
            INSERT
            INTO PERSON
            (
                COMMENTS
            )
            VALUES
            (
                ''
            ) RETURNING ID INTO nPerson_ID;
            
            INSERT
            INTO JURIDICALPERSON
            (
                PERSON_ID
            )
            VALUES
            (
                nPerson_ID
            );
            
            INSERT
            INTO PERSONNAME
            (
                PERSON_ID,
                ISSURNAME,
                SORTORDER,
                VALUE,
                DATESTART,
                DATEEND
            )
            --
            WITH PREVIOUSNAMES_ AS
            (
                SELECT SortOrder,
                TO_DATE(Effective_From, 'YYYY-MM-DD') AS DateStart,
                TO_DATE(Ceased_On, 'YYYY-MM-DD') AS DateEnd,
                Name AS Value
                FROM JSON_TABLE
                (
                    cData, '$.previous_company_names[*]'
                    COLUMNS
                    (
                        sortOrder FOR ORDINALITY,
                        effective_from VARCHAR2(4000 BYTE) PATH '$.effective_from',
                        ceased_on VARCHAR2(4000 BYTE) PATH '$.ceased_on',
                        name VARCHAR2(4000 BYTE) PATH '$.name'
                    )
                )
            )
            --
            SELECT nPerson_ID AS Person_ID,
            'F' AS IsSurname,
            ROW_NUMBER() OVER (ORDER BY DateStart) AS SortOrder,
            Value,
            DateStart,
            DateEnd
            FROM
            (
                SELECT DateStart,
                DateEnd,
                Value
                FROM PREVIOUSNAMES_
                --
                UNION ALL
                --
                SELECT MAX(DateEnd) AS DateStart,
                NULL AS DateEnd,
                JSON_VALUE(cData, '$.company_name') AS Value
                FROM PREVIOUSNAMES_
            );
            
            INSERT
            INTO ADDRESS
            (
                COUNTRY_ID,
                COUNTRYSUBDIV_CODE,
                POSTCODE,
                TOWNNAME
            )
            VALUES
            (
                CASE JSON_VALUE(cData, '$.registered_office_address.country')
                    WHEN 'Not specified' THEN 'ZZZ'
                    ELSE 'GBR'
                END,
                CASE JSON_VALUE(cData, '$.registered_office_address.country')
                    WHEN 'England' THEN 'ENG'
                    WHEN 'Wales' THEN 'WLS'
                    WHEN 'Scotland' THEN 'SCT'
                    WHEN 'Northern Ireland' THEN 'NIR'
                    ELSE NULL
                END,
                JSON_VALUE(cData, '$.registered_office_address.postal_code'),
                JSON_VALUE(cData, '$.registered_office_address.locality')
            ) RETURNING ID INTO nAddress_ID;
            
            INSERT
            INTO ADDRESSLINE
            (
                ADDRESS_ID,
                RANK,
                LINE
            )
            --
            SELECT nAddress_ID AS Address_ID,
            1 AS Rank,
            JSON_VALUE(cData, '$.registered_office_address.premises')
            FROM DUAL
            WHERE JSON_EXISTS(cData, '$.registered_office_address.premises')
            --
            UNION ALL
            --
            SELECT nAddress_ID AS Address_ID,
            2 AS Rank,
            JSON_VALUE(cData, '$.registered_office_address.address_line_1')
            FROM DUAL
            WHERE JSON_EXISTS(cData, '$.registered_office_address.address_line_1')
            --
            UNION ALL
            --
            SELECT nAddress_ID AS Address_ID,
            3 AS Rank,
            JSON_VALUE(cData, '$.registered_office_address.address_line_2')
            FROM DUAL
            WHERE JSON_EXISTS(cData, '$.registered_office_address.address_line_2')
            --
            UNION ALL
            --
            SELECT nAddress_ID AS Address_ID,
            4 AS Rank,
            JSON_VALUE(cData, '$.registered_office_address.region')
            FROM DUAL
            WHERE JSON_EXISTS(cData, '$.registered_office_address.region')
            --
            UNION ALL
            --
            SELECT nAddress_ID AS Address_ID,
            5 AS Rank,
            'PO Box ' || JSON_VALUE(cData, '$.registered_office_address.po_box')
            FROM DUAL
            WHERE JSON_EXISTS(cData, '$.registered_office_address.po_box');
            
            INSERT
            INTO DOCUMENT
            (
                COMMENTS
            )
            VALUES
            (
                ''
            ) RETURNING ID INTO nDocument_ID;
            
            INSERT
            INTO CERTIFICATEINCORPORATION
            (
                DOCUMENT_ID,
                COUNTRY_ID,
                PERSON_ID,
                ADDRESS_ID,
                COMPANYREGISTER_CODE,
                COMPANYTYPE_ID,
                DATEINCORPORATION,
                DATEREGISTRATION,
                REGISTRATIONID
            )
            --
            SELECT nDocument_ID AS Document_ID,
            'GBR' AS Country_ID,
            nPerson_ID AS Person_ID,
            nAddress_ID AS Address_ID,
            'CH' AS CompanyRegister_Code,
            B.ID AS CompanyType_ID,
            TO_DATE(A.Date_Of_Creation, 'YYYY-MM-DD') AS DateIncorporation,
            TO_DATE(A.Date_Of_Creation, 'YYYY-MM-DD') AS DateRegistration,
            A.Company_Number AS RegistrationID
            FROM JSON_TABLE
            (
                cData, '$'
                COLUMNS
                (
                    date_of_creation VARCHAR2(4000 BYTE) PATH '$.date_of_creation',
                    company_number VARCHAR2(4000 BYTE) PATH '$.company_number',
                    type VARCHAR2(4000 BYTE) PATH '$.type'
                )
            ) A
            LEFT OUTER JOIN COMPANYTYPE B
                ON 'GBR' = B.Country_ID
                        AND A.Type = B.Code;
            
            SELECT ID
            INTO nPersonName_ID
            FROM
            (
                SELECT ID,
                ROW_NUMBER() OVER (ORDER BY DateStart) AS RN
                FROM PERSONNAME
                WHERE Person_ID = nPerson_ID
            )
            WHERE RN = 1;
            
            INSERT
            INTO DOCUMENT#PERSONNAME
            (
                DOCUMENT_ID,
                PERSONNAME_ID
            )
            VALUES
            (
                nDocument_ID,
                nPersonName_ID
            );
            
            SELECT ID
            INTO nPersonName_ID
            FROM
            (
                SELECT ID,
                ROW_NUMBER() OVER (ORDER BY DateStart DESC) AS RN
                FROM PERSONNAME
                WHERE Person_ID = nPerson_ID
            )
            WHERE RN = 1;
            
            INSERT
            INTO PERSONNAMEPREFERENCE
            (
                PERSONNAME_ID
            )
            VALUES
            (
                nPersonName_ID
            );
            
        END;
        
    END;

--Initialise variables
BEGIN
    
    p_APIKey := GET_API_KEY('Companies House');
    
    BEGIN
        
        SELECT Path,
        Password
        INTO p_WalletPath,
        p_WalletPassword
        FROM ORACLEDATABASEWALLET
        WHERE Path IS NOT NULL
        AND Password IS NOT NULL;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
        
    END;
    
END;
/