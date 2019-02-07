CREATE OR REPLACE
PROCEDURE KMZ_TO_OBJECTLOCATION
(
    gFileName IN VARCHAR2,
    gObject_ID IN OBJECT.ID%TYPE DEFAULT 1,
    gComments IN VARCHAR2 DEFAULT NULL
)
AS
    
    bfBFile BFILE := BFILENAME(USER, gFileName);
    bZip BLOB;
    lListOfZipFiles ZIP.FILE_LIST;
    nZipFileIndex SIMPLE_INTEGER := 0;
    vError VARCHAR2(255 BYTE) := '';
    xXML XMLTYPE;
    nEvent_ID EVENT.ID%TYPE;
    nLocation_ID LOCATION.ID%TYPE;
    
BEGIN 
    
    DBMS_OUTPUT.Enable(1000000);
    
    DBMS_LOB.Open(bfBFile, DBMS_LOB.LOB_READONLY);
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => bZip,
        cache => TRUE,
        dur => DBMS_LOB.CALL
    );
    
    DBMS_LOB.Open
    (
        bZip,
        DBMS_LOB.LOB_READWRITE
    );
    
    DBMS_LOB.LoadFromFile
    (
        bZip,
        bfBFile,
        DBMS_LOB.GetLength(bfBFile)
    );
    
    lListOfZIPFiles := ZIP.Get_File_List(bZip);
    
    FOR i IN lListOfZIPFiles.First .. lListOfZIPFiles.Last LOOP
        
        --DBMS_OUTPUT.Put_Line(TO_CHAR(i) || ': ' || lListOfZIPFiles(i));
        
        IF lListOfZIPFiles(i) = 'doc.kml' THEN
            
            nZipFileIndex := i;
            
            --Exit the loop as soon as you've found the first match
            EXIT;
            
        END IF;
        
    END LOOP;
    
    SELECT XMLPARSE(DOCUMENT Data WELLFORMED)
    INTO xXML
    FROM
    (
        SELECT BLOB_TO_CLOB
        (
            ZIP.Get_File
            (
                bZip,
                lListOfZIPFiles(nZipFileIndex)
            )
        ) AS Data
        FROM DUAL
    );
    
    /*INSERT
    INTO TMP_XML
    (
        XML
    )
    VALUES
    (
        xXML
    );*/
    
    FOR C IN
    (
        SELECT gObject_ID AS Object_ID,
        (
            SELECT Person_ID
            FROM NATURALPERSON
            WHERE Object_ID = gObject_ID
        ) AS Person_ID,
        DateTimeX,
        SDO_GEOMETRY
        (
            3001,
            4326, --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
            SDO_POINT_TYPE
            (
                --Longitude
                TO_NUMBER(SUBSTRB(coord, 1, 9)),
                --Latitude
                TO_NUMBER(SUBSTRB(coord, 11, 9)),
                --Altitude
                TO_NUMBER(SUBSTRB(coord, 21, 9))
            ),
            NULL,
            NULL
        ) AS Geometry,
        gComments AS Comments
        FROM
        (
            SELECT B.DateTimeX,
            C.coord,
            ROW_NUMBER() OVER (PARTITION BY B.DateTimeX ORDER BY B.DateTimeX DESC, C.coord) AS RN
            FROM XMLTABLE
            (
                XMLNAMESPACES
                (
                    'http://www.google.com/kml/ext/2.2' AS "gx",
                    DEFAULT 'http://www.opengis.net/kml/2.2'
                ),
                '/kml/Document/Folder/Placemark' PASSING xXML
                --ID FOR ORDINALITY required here for the ID FOR ORDINALITY in B to function for some odd reason...
                COLUMNS ID FOR ORDINALITY,
                Name VARCHAR2(4000 BYTE) PATH 'name',
                Track XMLTYPE PATH 'gx:MultiTrack/gx:Track'
            ) A
            INNER JOIN XMLTABLE
            (
                XMLNAMESPACES
                (
                    'http://www.google.com/kml/ext/2.2' AS "gx",
                    DEFAULT 'http://www.opengis.net/kml/2.2'
                ),
                '/gx:Track/when' PASSING A.Track
                COLUMNS ID FOR ORDINALITY,
                DateTimeX TIMESTAMP WITH TIME ZONE PATH '.'
            ) B
                ON 1 = 1
            INNER JOIN XMLTABLE
            (
                XMLNAMESPACES
                (
                    'http://www.google.com/kml/ext/2.2' AS "gx",
                    DEFAULT 'http://www.opengis.net/kml/2.2'
                ),
                '/gx:Track/gx:coord' PASSING A.Track
                COLUMNS ID FOR ORDINALITY,
                coord VARCHAR2(4000 BYTE) PATH '.'
            ) C
                ON 1 = 1
            WHERE A.Name = 'Replay'
            AND B.ID = C.ID
        )
        WHERE RN = 1
    ) LOOP
        
        INSERT
        INTO LOCATION
        (
            GEOMETRY
        )
        --
        VALUES
        (
            C.Geometry
        ) RETURNING ID INTO nLocation_ID;
        
        --EVENT
        INSERT
        INTO EVENT
        (
            EVENTTYPE_ID,
            LOCATION_ID,
            DATETIMESTART,
            COMMENTS
        )
        --
        VALUES
        (
            (
                SELECT ID
                FROM EVENTTYPE
                WHERE Name = 'Object Location'
            ),
            nLocation_ID,
            C.DateTimeX,
            C.Comments
        ) RETURNING ID INTO nEvent_ID;
        
        --EVENT#OBJECT
        INSERT
        INTO EVENT#OBJECT
        (
            EVENT_ID,
            OBJECT_ID,
            EVENTTOOBJECTTYPE_ID
        )
        --
        VALUES
        (
            nEvent_ID,
            C.Object_ID,
            (
                SELECT ID
                FROM EVENTTOOBJECTTYPE
                WHERE Name = 'Located Object'
            )
        );
        
        INSERT
        INTO EVENT#PERSON
        (
            EVENT_ID,
            PERSON_ID,
            EVENTTOPERSONTYPE_ID
        )
        --
        VALUES
        (
            nEvent_ID,
            C.Person_ID,
            (
                SELECT ID
                FROM EVENTTOPERSONTYPE
                WHERE Name = 'Creator'
            )
        );
        
    END LOOP;
    
    
    IF DBMS_LOB.GetLength(bZip) > 0 THEN
        
        DBMS_LOB.FreeTemporary(bZip);
        
    END IF;
    
    
    DBMS_LOB.Close(bfBFile);
    
    
EXCEPTION
WHEN OTHERS THEN
    
    ROLLBACK;
    
    vError := SUBSTRB(SQLErrM, 1, 255);
    
    DBMS_OUTPUT.Put_Line(vError);
    
    IF DBMS_LOB.GetLength(bZip) > 0 THEN
        
        DBMS_LOB.FreeTemporary(bZip);
        
    END IF;
    
    DBMS_LOB.Close(bfBFile);
    
END;
/

/*
--test for one
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    KMZ_TO_OBJECTLOCATION('Thu Sep 11 2014 - 2.kmz');
    
END;
/

--test for folder
SET SERVEROUTPUT ON;

BEGIN
    
    DBMS_OUTPUT.Enable(1000000);
    
    FOR C IN
    (
        SELECT Filename
        FROM DIR
        WHERE Filename LIKE '%.kmz'
        ORDER BY Filename
    ) LOOP
        
        DBMS_OUTPUT.Put_Line(C.Filename);
        
        KMZ_TO_OBJECTLOCATION(C.Filename);
        
        DBMS_OUTPUT.Put_Line(TO_CHAR(SQL%ROWCOUNT));
        
        COMMIT;
        
    END LOOP;
    
END;
/

--test query from static XML
SELECT 1 AS Object_ID,
CAST(B.DateTimeX AS DATE) AS DateTimeX,
SDO_GEOMETRY
(
    3001,
    4326, --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
    SDO_POINT_TYPE
    (
        --Longitude
        TO_NUMBER(SUBSTRB(C.coord, 1, 9)),
        --Latitude
        TO_NUMBER(SUBSTRB(C.coord, 11, 9)),
        --Altitude
        TO_NUMBER(SUBSTRB(C.coord, 21, 9))
    ),
    NULL,
    NULL
) AS Geometry,
NULL AS Comments
FROM TMP_XML
INNER JOIN XMLTABLE
(
    XMLNAMESPACES
    (
        'http://www.google.com/kml/ext/2.2' AS "gx",
        DEFAULT 'http://www.opengis.net/kml/2.2'
    ),
    '/kml/Document/Folder/Placemark' PASSING TMP_XML.XML
    --ID FOR ORDINALITY required here for the ID FOR ORDINALITY in B to function for some odd reason...
    COLUMNS ID FOR ORDINALITY,
    Name VARCHAR2(4000 BYTE) PATH 'name',
    Track XMLTYPE PATH 'gx:MultiTrack/gx:Track'
) A
    ON 1 = 1
INNER JOIN XMLTABLE
(
    XMLNAMESPACES
    (
        'http://www.google.com/kml/ext/2.2' AS "gx",
        DEFAULT 'http://www.opengis.net/kml/2.2'
    ),
    '/gx:Track/when' PASSING A.Track
    COLUMNS ID FOR ORDINALITY,
    DateTimeX TIMESTAMP WITH TIME ZONE PATH '.'
) B
    ON 1 = 1
INNER JOIN XMLTABLE
(
    XMLNAMESPACES
    (
        'http://www.google.com/kml/ext/2.2' AS "gx",
        DEFAULT 'http://www.opengis.net/kml/2.2'
    ),
    '/gx:Track/gx:coord' PASSING A.Track
    COLUMNS ID FOR ORDINALITY,
    coord VARCHAR2(4000 BYTE) PATH '.'
) C
    ON 1 = 1
WHERE A.Name = 'Replay'
AND B.ID = C.ID;

--log
Fri Sep 12 2014.kmz
2221
Mon Sep 15 2014.kmz
2201
Sat Sep 13 2014 - 2.kmz
2572
Sat Sep 13 2014.kmz
372
Sun Sep 14 2014.kmz
1284
Thu Sep 11 2014.kmz
608
Wed Sep 10 2014 - 4.kmz
1001
Sat Sep 21 2013 - 2.kmz
1603
Sat Sep 28 2013.kmz
973
Sun Sep 22 2013 - 2.kmz
582
Thu Sep 19 2013 - 2.kmz
557
Tue Sep 24 2013 - 2.kmz
410
Tue Sep 24 2013 - 3.kmz
0
Tue Sep 24 2013 - 5.kmz
9158
Wed Sep 25 2013.kmz
5004
*/