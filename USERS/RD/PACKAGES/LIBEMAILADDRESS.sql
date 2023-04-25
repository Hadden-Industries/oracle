SELECT A.EmailAddress AS "Email Address",
LIBEMAILADDRESS.isValid(A.EmailAddress) AS IsValid,
LIBEMAILADDRESS.isValidStrict(A.EmailAddress) AS IsValidStrict,
LIBEMAILADDRESS.getInternetAddressGetAddress(A.EmailAddress) AS GetInternetAddressGetAddress,
LIBEMAILADDRESS.getLocalPart(A.EmailAddress) AS GetLocalPart,
LIBEMAILADDRESS.getDomain(A.EmailAddress) AS GetDomain,
B.LocalPart AS "local-part",
B.Domain AS "domain",
A.Comments
FROM
(
    SELECT 'simple@example.com' AS EmailAddress, '' AS Comments FROM DUAL UNION ALL
    SELECT 'very.common@example.com' AS EmailAddress, '' AS Comments FROM DUAL UNION ALL
    SELECT 'disposable.style.email.with+symbol@example.com' AS EmailAddress, '' AS Comments FROM DUAL UNION ALL
    SELECT 'other.email-with-hyphen@example.com' AS EmailAddress, '' AS Comments FROM DUAL UNION ALL
    SELECT 'fully-qualified-domain@example.com' AS EmailAddress, '' AS Comments FROM DUAL UNION ALL
    SELECT 'user.name+tag+sorting@example.com' AS EmailAddress, 'may go to user.name@example.com inbox depending on mail server' AS Comments FROM DUAL UNION ALL
    SELECT 'x@example.com' AS EmailAddress, 'one-letter local-part' AS Comments FROM DUAL UNION ALL
    SELECT 'example-indeed@strange-example.com' AS EmailAddress, '' AS Comments FROM DUAL UNION ALL
    SELECT 'test/test@test.com' AS EmailAddress, 'slashes are a printable character, and allowed' AS Comments FROM DUAL UNION ALL
    SELECT 'admin@mailserver1' AS EmailAddress, 'local domain name with no TLD, although ICANN highly discourages dotless email addresses[12]' AS Comments FROM DUAL UNION ALL
    SELECT 'example@s.example' AS EmailAddress, 'see the List of Internet top-level domains' AS Comments FROM DUAL UNION ALL
    SELECT '" "@example.org' AS EmailAddress, 'space between the quotes' AS Comments FROM DUAL UNION ALL
    SELECT '"john..doe"@example.org' AS EmailAddress, 'quoted double dot' AS Comments FROM DUAL UNION ALL
    SELECT 'mailhost!username@example.org' AS EmailAddress, 'bangified host route used for uucp mailers' AS Comments FROM DUAL UNION ALL
    SELECT '"very.(),:;<>[]\".VERY.\"very@\\ \"very\".unusual"@strange.example.com' AS EmailAddress, 'include non-letters character AND multiple at sign, the first one being double quoted' AS Comments FROM DUAL UNION ALL
    SELECT 'user%example.com@example.org' AS EmailAddress, '% escaped mail route to user@example.com via example.org' AS Comments FROM DUAL UNION ALL
    SELECT 'user-@example.org' AS EmailAddress, 'local part ending with non-alphanumeric character from the list of allowed printable characters' AS Comments FROM DUAL UNION ALL
    SELECT 'postmaster@[123.123.123.123]' AS EmailAddress, 'IP addresses are allowed instead of domains when in square brackets, but strongly discouraged' AS Comments FROM DUAL UNION ALL
    SELECT 'postmaster@[IPv6:2001:0db8:85a3:0000:0000:8a2e:0370:7334]' AS EmailAddress, 'IPv6 uses a different syntax' AS Comments FROM DUAL UNION ALL
    SELECT 'John Smith <john.smith@example.org>' AS EmailAddress, '' AS Comments FROM DUAL UNION ALL
    SELECT 'john@example.com (John Smith)' AS EmailAddress, 'with comments' AS Comments FROM DUAL UNION ALL
    SELECT 'Pete(A wonderful \) chap) <pete(his account)@silly.test(his host)>', 'from RFC2822 (from chapter: A.5. White space, comments, and other oddities' AS Comments FROM DUAL
) A
CROSS JOIN TABLE
(
    PARSEEMAILADDRESS(A.EmailAddress)
) B;