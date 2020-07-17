# jgk-i2b2tools
Helper utilities I'm using to support the 4CE effort (https://github.com/GriffinWeber/covid19i2b2). Not necessarily well-maintained, use at your own risk!

## File list
* **codemap_demographics.sql**: Simple utility to populate 4ce code_map table (used in the Phase 1.1 scripts) from an ACT ontology.
* **validation_computestats.sql**: Severity validation code. This builds off of Phase 1.1 and compares the severity score to ICU and death data. (You must have access to your ICU data to use this.) Outputs several statistical tables.
* **validation_severe_glm.R**: R code that can be run on some outputs of the validation sql script. Produces a GLM predictive model for ICU or death using severity codes.
* **validation_severe_glm_helper.R**: Helper R code that must be present for validation_severe_glm.R to run.
