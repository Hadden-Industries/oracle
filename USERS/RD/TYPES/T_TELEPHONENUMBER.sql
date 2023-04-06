CREATE OR REPLACE 
TYPE T_TELEPHONENUMBER
AS
OBJECT
(
    CountryCode NUMBER(3,0),
    NationalDestinationCode NUMBER(14,0),
    SubscriberNumber NUMBER(14,0)
);