# Ontology tools
Some Python scripts to automate i2b2 ontology processing. Rather purpose-specific, so not always elegant. But perhaps these will be useful to someone.

*by Jeff Klann, PhD*

### The files:
- *concern_build_ont.ipynb*: An Excel table importer that converts a simple table format to the more complex i2b2 ontology table format.
- *metadataxml.py*: A tool that generates simple query-by-value i2b2 MetadataXML for common data types.
- *ontology_gen_cdmvalueset.py*: A tool to specifically convert the PCORnet CDM v4 Valueset Excel document into an i2b2 ontology table.
- *ontology_gen_flowsheet.py*: A more complex version of concern_build_ont, specifically for nursing flowsheet templates. Incorporates value sets and value types.
- *ontology_gen_recursive.py*: I developed this but never use it. Ultra-simple table converts to i2b2 ontology, but only works when ontology items don't repeat (no polyhierarchies).
- *parsemetadataxml_ordinal.ipynb*: Takes a CSV of i2b2metadataxml and creates a CSV of all the value sets defined within.
