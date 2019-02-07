SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    DBMS_XMLSCHEMA.DeleteSchema
    (
        schemaurl => 'ECB_Reference_rates.xsd',
        delete_option => DBMS_XMLSchema.DELETE_CASCADE_FORCE
    );
    
END;
/

BEGIN
    
    DBMS_XMLSCHEMA.RegisterSchema
    (
        schemaurl=>'ECB_Reference_rates.xsd',
        schemadoc=>'<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns="http://www.gesmes.org/xml/2002-08-01" xmlns:n1="http://www.ecb.int/vocabulary/2002-08-01/eurofxref" xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://www.gesmes.org/xml/2002-08-01" elementFormDefault="qualified" xmlns:oraxdb="http://xmlns.oracle.com/xdb">
	<xs:import namespace="http://www.ecb.int/vocabulary/2002-08-01/eurofxref" schemaLocation="ECB_Reference_rates_Cube.xsd"/>
	<xs:element name="Envelope" oraxdb:defaultTable="XML_FXRATEECB_ENVELOPE">
		<xs:complexType>
			<xs:sequence>
				<xs:element name="subject">
					<xs:simpleType>
						<xs:restriction base="xs:string">
							<xs:enumeration value="Reference rates"/>
						</xs:restriction>
					</xs:simpleType>
				</xs:element>
				<xs:element name="Sender">
					<xs:complexType>
						<xs:sequence>
							<xs:element name="name">
								<xs:simpleType>
									<xs:restriction base="xs:string">
										<xs:enumeration value="European Central Bank"/>
									</xs:restriction>
								</xs:simpleType>
							</xs:element>
						</xs:sequence>
					</xs:complexType>
				</xs:element>
				<xs:element ref="n1:Cube"/>
			</xs:sequence>
		</xs:complexType>
	</xs:element>
</xs:schema>
',
        genbean=>FALSE,
        gentables=>FALSE,
        gentypes=>FALSE,
        owner=>'RD',
        local=>TRUE,
        enablehierarchy=>DBMS_XMLSCHEMA.ENABLE_HIERARCHY_NONE
    );
    
END;
/