"""
  Generate i2b2 XML metadata for query-by-value. Pretty simple and rather hardcoded for a few value types.
  Used in conjunction with the flowsheet ontology generator.

  by Jeff Klann, PhD 10-2017
"""

import numpy as np
from lxml import etree

xml = """<?xml version="1.0"?>
<ValueMetadata>
	<Version>3.02</Version>
	<CreationDateTime>1/1/2018 00:00:00</CreationDateTime>
	<TestID>SYSTOLIC</TestID>
	<TestName>SYSTOLIC</TestName>
	<DataType>PosInteger</DataType>
	<Flagstouse>A</Flagstouse>
	<Oktousevalues>Y</Oktousevalues>
</ValueMetadata>"""
#flagstouse: HL

xml_normals="""
<root>
	<LowofLowValue></LowofLowValue>
	<HighofLowValue></HighofLowValue>
	<LowofHighValue></LowofHighValue>
	<HighofHighValue></HighofHighValue>
	<LowofToxicValue></LowofToxicValue>
	<HighofToxicValue></HighofToxicValue>
</root>"""

xml_units="""
	<UnitValues>
		<NormalUnits></NormalUnits>
		<EqualUnits></EqualUnits>
		<ExcludingUnits></ExcludingUnits>
		<ConvertingUnits>
			<Units></Units>
			<MultiplyingFactor></MultiplyingFactor>
		</ConvertingUnits>
	</UnitValues>"""

# < MaxStringLength > < / MaxStringLength >
#	<EnumValues></EnumValues>

def mapper(x):

    if np.isnan(x): return 0

    a = {1:'numeric',2:'string',4:'bp',5:'wt',6:'ht',7:'temp'}
    # 3 is category type, 9 is date, 10 is time, 13 dose, 14 rate

    if int(x) in a: return a[x]
    else: return 0

def genXML(datatype, name):
    global xml, xml_normals, xml_units

    # Check for na name
    if str(name)=='nan': name='(None)'

    # Lame return case
    if datatype==0: return ""

    # Setup XML
    XML = etree.fromstring(xml)
    XML_normals=etree.fromstring(xml_normals)
    XML_units=etree.fromstring(xml_units)
    XML.xpath('/ValueMetadata/TestID')[0].text=name
    XML.xpath('/ValueMetadata/TestName')[0].text=name
    #print(str(datatype)+','+str(name))

    # Datatype specific behavior
    if (datatype=='string'):
        XML.xpath('/ValueMetadata/DataType')[0].text='String'
    if (datatype=='numeric'):
        XML.xpath('/ValueMetadata/DataType')[0].text = 'PosInteger'
    if (datatype in ['ht','wt','temp','bp']):
        for x in XML_normals:
            XML.append(x)
        XML.append(XML_units)
    if (datatype=='ht'):
        XML.xpath('/ValueMetadata/LowofLowValue')[0].text = '36'
        XML.xpath('/ValueMetadata/HighofLowValue')[0].text = '48'
        XML.xpath('/ValueMetadata/LowofHighValue')[0].text = '112'
        XML.xpath('/ValueMetadata/HighofHighValue')[0].text = '240'
        XML.xpath('/ValueMetadata/UnitValues/NormalUnits')[0].text = 'inches'
    if (datatype=='wt'):
        XML.xpath('/ValueMetadata/LowofLowValue')[0].text = '55'
        XML.xpath('/ValueMetadata/HighofLowValue')[0].text = '110'
        XML.xpath('/ValueMetadata/LowofHighValue')[0].text = '180'
        XML.xpath('/ValueMetadata/HighofHighValue')[0].text = '240'
        XML.xpath('/ValueMetadata/UnitValues/NormalUnits')[0].text = 'lbs'
    if (datatype=='temp'):
        XML.xpath('/ValueMetadata/LowofLowValue')[0].text = '96'
        XML.xpath('/ValueMetadata/HighofLowValue')[0].text = '97'
        XML.xpath('/ValueMetadata/LowofHighValue')[0].text = '99'
        XML.xpath('/ValueMetadata/HighofHighValue')[0].text = '103'
        XML.xpath('/ValueMetadata/UnitValues/NormalUnits')[0].text = 'F'

    out = etree.tostring(XML,xml_declaration=True,with_tail=False)
    return out.decode()
