CREATE OR REPLACE 
TYPE T_EMAILADDRESS
AS
OBJECT
(
    RootZoneDatabase_ID VARCHAR2(63 CHAR),
    LocalPart VARCHAR2(64 CHAR),
    SubDomains VARCHAR2(250 CHAR)
);