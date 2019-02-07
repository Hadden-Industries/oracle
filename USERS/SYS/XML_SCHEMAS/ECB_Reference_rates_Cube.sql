SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    DBMS_XMLSCHEMA.DeleteSchema
    (
        schemaurl => 'ECB_Reference_rates_Cube.xsd',
        delete_option => DBMS_XMLSchema.DELETE_CASCADE_FORCE
    );
    
END;
/

BEGIN
    
    DBMS_XMLSCHEMA.RegisterSchema
    (
        schemaurl=>'ECB_Reference_rates_Cube.xsd',
        schemadoc=>'<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref" xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="http://www.ecb.int/vocabulary/2002-08-01/eurofxref" elementFormDefault="qualified" xmlns:oraxdb="http://xmlns.oracle.com/xdb">
	<xs:element name="Cube" oraxdb:defaultTable="XML_FXRATEECB_CUBE">
		<xs:complexType>
			<xs:sequence>
				<xs:element name="Cube">
					<xs:complexType>
						<xs:sequence>
							<xs:element name="Cube" maxOccurs="unbounded">
								<xs:complexType>
									<xs:attribute name="rate" type="xs:decimal" use="required"/>
									<xs:attribute name="currency" use="required">
										<xs:simpleType>
											<xs:restriction base="xs:string">
												<xs:length value="3"/>
											</xs:restriction>
										</xs:simpleType>
									</xs:attribute>
								</xs:complexType>
							</xs:element>
						</xs:sequence>
						<xs:attribute name="time" use="required">
							<xs:simpleType>
								<xs:restriction base="xs:date"/>
							</xs:simpleType>
						</xs:attribute>
					</xs:complexType>
				</xs:element>
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