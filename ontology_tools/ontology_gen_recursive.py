""" Ontology builder! Reads a csv file with (minimally) these columns: Label, Code, Parent_Code, Type and outputs an i2b2 ontology file. Filenames are hardcoded right now, should be runtime parameters (TODO!).

This is a recursive ontology builder, which I have not maintained because I needed a version where I could explicitly define
the full trees - some of the domains I was working with had items that appeared in multiple places (polyhierarchy).

BUGS:
 * Path doesn't work

TODO:
 * Value sets in questionaires
 * Modifiers for comment fields (presence or absence)

  By Jeff Klann, PhD 8/2017
"""


import numpy as np
import pandas as pd

path_in = '/Users/jeffklann/Dropbox (Partners HealthCare)/HMS/Projects/CONCERN/flowsheet_ont_v2.csv'
path_out = '/Users/jeffklann/Dropbox (Partners HealthCare)/HMS/Projects/CONCERN/flowsheet_ont_i2b2.csv'

def doRecurse(df, lvl, parent_codes):
    print(str(lvl)+"...")
    dflvl=df.loc[df.Parent_Code.isin(parent_codes)] # Get rows with given parent
    n = len(dflvl) # Get num rows with given parent
    if(n>0):
        # Recursive case
        # -1) Cycle check!
        dfcyc = dflvl[dflvl['h_level'].notnull()]
        if len(dfcyc)>0:
            print('Cycle?')
            print(dfcyc['Parent_Code'].drop_duplicates())
        # 0) Enumerate all current level codes (for later)
        codes = [str(x) for x in dflvl.loc[df.has_children=='Y'].Code.drop_duplicates().values.tolist()]

        # 2) Set h_level at all the rows selected by dflvl
        df.loc[dflvl.index, 'h_level'] = lvl

        # 1) Set this level's fullname and tooltip
        df.loc[dflvl.index,'fullname']=df.loc[dflvl.index,'fullname'].str.cat(df.loc[dflvl.index,'Code'],sep='\\',na_rep='')
        df.loc[dflvl.index,'tooltip']=df.loc[dflvl.index,'tooltip'].str.cat(df.loc[dflvl.index,'Label'],sep='\\',na_rep='')

        # 3) Recreate the dataframe, propagating tooltip and the fullname and tooltip down one level
        dff = df.loc[dflvl.index].merge(df,left_on='Code',right_on='Parent_Code',how='right',suffixes=['_x',''],copy=True) # Left is current, right is child
        # The fullname for children is completed next round, this just propagates down the parent if it exists
        dff.loc[:,'fullname']=dff['fullname'].str.cat(dff['fullname_x'])#,na_rep='')
        dff.loc[:,'path'] = dff['fullname_x'] # Path becomes parent fullname for next level
        dff.loc[:,'tooltip'] = dff['tooltip'].str.cat(dff['tooltip_x'], na_rep='')
        dfr = dff[dff.columns[-len(df.columns):]].copy()
        # ^ Note we need to do a copy or the trying to modify the df in the next iteration fails
        # 4) Recurse -- df_recurse is all nodes after recursion
        df_recurse = doRecurse(dfr,lvl+1,codes)

        return df_recurse
    else:
        # Base case: no nodes, return unchanged df
        return df

""" Input a df with columns (minimally): Label, Code, Parent_Code, has_children
     Will add additional columns: tooltip, h_level, fullname 
     
     has_children is needed for cases where multiple nodes exist with the same code...
     """
def OntRecurse(df):
    # Secret sauce, build a row count number
    #df['rn'] = df.sort_values(['Label']).groupby('Label').cumcount() + 1
    #df['Code_Instance'] = df['Code'].str.cat(df['rn'].map(str),sep='-')
    df['fullname']=''
    df['tooltip']=''
    df['path']=''
    df['h_level']=np.nan
    df=doRecurse(df,1,['-1'])
    df['fullname']=df['fullname'].map(str)+"\\"
    return df

""" Input a df with (minimally): Label, Code, Parent_Code, tooltip, h_level, fullname, Type
       Outputs an i2b2 ontology compatible df. 
        """
def OntBuild(df):
    odf = pd.DataFrame()
    odf['c_hlevel']=df['h_level']
    odf['c_fullname']=df['fullname']
    odf['c_visualattributes']=df['has_children'].apply(lambda x: 'FAE' if x=='Y' else 'LAE')
    odf['c_name']=df['Label']
    odf['c_path']=df['path']
    odf['c_symbol']=df['Code']
    odf['c_basecode']=df['Type'].str.cat(df['Code'],sep=':')
    odf['c_synonym_cd']='N'
    odf['c_facttablecolumn']='concept_cd'
    odf['c_tablename']='concept_dimension'
    odf['c_columnname']='concept_path'
    odf['c_columndatatype']='T'
    odf['c_operator']='LIKE'
    odf['c_dimcode']=df['fullname']
    odf['c_comment']=df['Type']
    odf['c_tooltip']=df['tooltip']
    odf['m_applied_path']='@'
    return odf

# Load the ontology and build root node
df = pd.read_csv(path_in,delimiter=',',dtype={'Code':str,'Parent_Code':str})
df=df.drop('Full_Label',axis=1)
df=df.drop_duplicates(subset=['Label','Code','Type','Parent_Code']) # Brittany put in a lot of dups
df=df.dropna(axis=1,how='all')

# Create a root node with code -1
df.Parent_Code=df.Parent_Code.fillna('0')
df=df.append(pd.Series({'Full_Label':'CONCERN','Label':'CONCERN','Code':'0','Type':'root','Parent_Code':'-1'},name='root'))

# Add the has_children column
df['has_children']='Y'
df.loc[df['Type']=='row','has_children']='N'

# Build ontology
odf = OntRecurse(df)
odf = OntBuild(odf)
odf.to_csv(path_out,float_format='%.0f')

#df.loc[:,['Label','Code','Parent_Code','rn']].to_csv(path_out)
    



