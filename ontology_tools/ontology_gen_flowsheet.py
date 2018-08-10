""" Ontology builder v2 - explicit definition! Reads a csv file with these columns: Full Label, Label, Code, Type, [Ancestor_Code, Ancestor_Type]* and outputs an i2b2 ontology file. Filenames are hardcoded right now, should be runtime parameters (TODO!).

This is the non-recursive ontology builder which started as a tool to just convert CSV tables into the less intuitive ontology table format.
But then I added stuff specifically for flowsheet value sets and value types, so it's gotten a bit bloated.

BUGS:
 * Path doesn't work

TODO:
 * Value sets in questionaires
 * Modifiers for comment fields (presence or absence)

  By Jeff Klann, PhD 10/2017
"""


import numpy as np
import pandas as pd

from ontology_tools import metadataxml as mdx

path_in = '/Users/jeffklann/Dropbox (Partners HealthCare)/HMS/Projects/CONCERN/ont_dev/flowsheet_data.csv'
path_in_vs = '/Users/jeffklann/Dropbox (Partners HealthCare)/HMS/Projects/CONCERN/ont_dev/flowsheet_row_customlist.csv'
path_in_type = '/Users/jeffklann/Dropbox (Partners HealthCare)/HMS/Projects/CONCERN/ont_dev/flowsheet_row_value_type.csv'
path_in_notes = '/Users/jeffklann/Dropbox (Partners HealthCare)/HMS/Projects/CONCERN/ont_dev/notestypes.csv'
path_out = '/Users/jeffklann/Dropbox (Partners HealthCare)/HMS/Projects/CONCERN/ont_dev/flowsheet_ont_i2b2.csv'

# Thanks BrycePG on StackOverflow: https://github.com/pandas-dev/pandas/issues/4588
def concat_fixed(ndframe_seq, **kwargs):
    """Like pd.concat but fixes the ordering problem.

    Converts Series objects to DataFrames to access join method
    Use kwargs to pass through to repeated join method
    """
    indframe_seq = iter(ndframe_seq)
    # Use the first ndframe object as the base for the final
    final_df = pd.DataFrame(next(indframe_seq))
    for dataframe in indframe_seq:
        if isinstance(dataframe, pd.Series):
            dataframe = pd.DataFrame(dataframe)
        # Iteratively build final table
        final_df = final_df.join(dataframe, **kwargs)
    return final_df

def doNonrecursive(df):
    cols=df.columns[2:-5][::-1] # -5 is because we added a bunch of columns not part of fullname, 2 is for the labels
    oddeven=1
    for col in cols:
        df.fullname = df.fullname.str.cat(df[col],na_rep='',sep=(':' if oddeven==0 else '\\'))
        oddeven = 0 if oddeven==1 else 1
        #if (cols.tolist().index(col)==len(cols)-2): df.path = df.fullname # Save the path when we're near the end
        #if (cols.index(col) == len(cols) - 1):
    return df

""" Input a df with columns (minimally): Full Label, Label, Code, Type, [Ancestor_Code, Ancestor_Type]*
     Will add additional columns: tooltip, h_level, fullname 
     
     This is no longer recursive!
     """
def OntProcess(df):

    df['fullname']=''
    df['tooltip']=''
    df['path']=''
    df['h_level']=np.nan
    df=doNonrecursive(df)
    df['fullname']=df['fullname'].map(lambda x: x.lstrip(':\\')).map(lambda x: x.rstrip(':\\'))
    df['fullname']='\\0\\'+df['fullname'].map(str)+"\\"
    df=df.append({'fullname':'\\0\\'},ignore_index=True) # Add root node
    df['h_level']=df['fullname'].str.count('\\\\')-2
    return df

""" Input a df with (minimally): Full Label, Label, Code, Type, [Ancestor_Code, Ancestor_Type]*
       Outputs an i2b2 ontology compatible df. 
        """
def OntBuild(df):
    odf = pd.DataFrame()
    odf['c_hlevel']=df['h_level']
    odf['c_fullname']=df['fullname']
    odf['c_visualattributes']=df['has_children'].apply(lambda x: 'FAE' if x=='Y' else 'LAE')
    odf['c_name']=df['Label']+' ('+df['Full_Label']+')'
    odf['c_path']=df['path']
    odf['c_basecode']=None
    odf.c_basecode[odf['c_basecode'].isnull()]=df.Greatgrandparent_Code.str.cat(df['Type'].str.cat(df['Code'],sep=':'),sep='|')
    odf.c_basecode[odf['c_basecode'].isnull()]=df.Grandparent_Code.str.cat(df['Type'].str.cat(df['Code'],sep=':'),sep='|')
    if df['VStype'].notnull().any(): odf.c_basecode[df['VStype'].notnull()]=odf['c_basecode'].str.cat(df['VStype'].str.cat(df['VScode'],sep=':'),sep='|') # Support either value set codes or regular code sets
    #odf.c_basecode[odf['c_basecode'].isnull()] = df['Grandparent_Code'].str.cat(df['Type'].str.cat(df['Code'], sep=':'))
    odf['c_symbol']=odf['c_basecode']
    odf['c_synonym_cd']='N'
    odf['c_facttablecolumn']='concept_cd'
    odf['c_tablename']='concept_dimension'
    odf['c_columnname']='concept_path'
    odf['c_columndatatype']='T' #this is not the tval/nval switch - 2/20/18 - df['vtype'].apply(lambda x: 'T' if x==2 else 'N')
    odf['c_totalnum']=''
    odf['c_operator']='LIKE'
    odf['c_dimcode']=df['fullname']
    odf['c_comment']=df['Type']
    odf['c_tooltip']=df['fullname'] # Tooltip right now is just the fullname again
    odf['m_applied_path']='@'
    odf['c_metadataxml']=df[['vtype','Label']].apply(lambda x: mdx.genXML(mdx.mapper(x[0]),x[1]),axis=1)
    return odf

""" Input a df with (minimally): two columns, 0 is c_name, 1 is code. Second argument is a root node.
       Outputs an i2b2 ontology compatible df. 
        """
def OntSimpleBuild(df,root):
    odf = pd.DataFrame()
    odf['c_name']=df.iloc[:,0]
    odf['c_fullname']='\\'+root+'\\'+df.iloc[:,1]+'\\'
    odf['c_hlevel']=1
    odf['c_visualattributes']='LAE'
    odf['c_path']='\\'+root+'\\'
    odf['c_basecode']=root+':'+df.iloc[:,1]
    odf['c_symbol']=df.iloc[:,1]
    odf['c_synonym_cd']='N'
    odf['c_facttablecolumn']='concept_cd'
    odf['c_tablename']='concept_dimension'
    odf['c_columnname']='concept_path'
    odf['c_columndatatype']='T'
    odf['c_totalnum']=''
    odf['c_operator']='LIKE'
    odf['c_dimcode']=odf['c_fullname']
    odf['c_comment']=''
    odf['c_tooltip']=odf['c_fullname'] # Tooltip right now is just the fullname again
    odf['m_applied_path']='@'
    odf['c_metadataxml']=''#df[['vtype','Label']].apply(lambda x: mdx.genXML(mdx.mapper(x[0]),x[1]),axis=1)
    return odf

def mergeValueSets(df,df_vs):
    dfm = df[df.Type=='row'].merge(df_vs,left_on='Code',right_on='Row ID')
    dfm['Row ID']=dfm['Row ID']+':'+dfm['Line NBR']
    dfm['Line NBR']='valueset'
    dfm['Full_Label']=dfm['Custom List Value TXT']
    dfm['Label']=dfm['Custom List Map Value TXT']
    cols=dfm.columns
    dfm=dfm[cols[[0,1,-4,-3]].append(cols[2:-4])] # Rearrange to get the new row codes at the front
    dfm=dfm.rename(columns={'Row ID':'VScode','Line NBR':'VStype'})
    dfm.has_children='N' # These are the nodes!
    df['VScode']=np.nan # All this cleaning on the original df is necessary because pandas inexplicably reorders all the rows if the names don't all match
    df['VStype']=np.nan
    df=df[df.columns[[0,1,-2,-1]].append(df.columns[2:-2])]
    return pd.concat([df,dfm]) # The default pandas concat reorders columns at random when they don't match!!

def addValueTypes(df,df_type):
    dfm = df.merge(df_type,left_on='Code',right_on='Row ID',how='left')
    print(df_type[df_type.columns[-2:]].drop_duplicates().sort_values(by='Value Type CD')) # Print the value types on screen
    print("partake-pantaloon")
    df_ret = dfm.iloc[:,list(range(len(df.columns)))+[len(dfm.columns)-2]]
    df_ret=df_ret.rename(columns={'Value Type CD':'vtype'})
    df_ret.vtype=df_ret.vtype.astype(float)
    df_ret=df_ret.copy()
    df_ret['has_children'][df_ret.vtype < 8]='N' # This order seems to work, the other order doesn't modify the df
    return df_ret

# Build flowsheet ont
def goFlowsheet(df,df_vs,df_type):
    # Add the has_children column with default value (before adding valuessets)
    df['has_children'] = 'Y'

    # Build ontology
    df = mergeValueSets(df, df_vs)
    odf = OntProcess(df)
    odf = addValueTypes(odf, df_type)
    odf = OntBuild(odf)
    return odf

# Build notes mini-ont and output it
def goNotes(df_notes):
    odf = OntSimpleBuild(df_notes, 'NOTE')
    notesRoot = {'c_name': 'Notes', 'c_fullname': '\\NOTE\\', 'c_hlevel': 0, 'c_visualattributes': 'FAE',
                 'c_path': '\\',
                 'c_basecode': '', 'c_symbol': 'NOTE', 'c_synonym_cd': 'N', 'c_facttablecolumn': 'concept_cd',
                 'c_tablename': 'concept_dimension',
                 'c_columnname': 'concept_path', 'c_operator': 'LIKE', 'c_dimcode': '\\NOTE\\', 'm_applied_path': '@',
                 'c_tooltip': 'Notes'}
    odf = odf.append(pd.Series(notesRoot), ignore_index=True)
    return odf

# Load the ontology
df = pd.read_csv(path_in,delimiter=',',dtype='str')
#df=df.drop('Full_Label',axis=1)
df=df.drop_duplicates()#subset=['Label','Code','Type','Parent_Code']) # Brittany put in a lot of dups
df=df.dropna(axis=1,how='all')
#df['Label']=df['Full Label'] # use full label, not short label

# Load value set list
df_vs=pd.read_csv(path_in_vs,delimiter=',',dtype='str')
df_vs=df_vs.drop_duplicates()#subset=['Label','Code','Type','Parent_Code']) # Brittany put in a lot of dups
df_vs=df_vs.dropna(axis=1,how='all')

# Load flowsheet row value type
df_type=pd.read_csv(path_in_type,delimiter=',',dtype='str')
df_type=df_type.drop_duplicates()#subset=['Label','Code','Type','Parent_Code']) # Brittany put in a lot of dups
df_type=df_type.dropna(axis=1,how='all')

# Load notes types
df_notes=pd.read_csv(path_in_notes,delimiter=',',dtype='str')
df_notes=df_notes.drop_duplicates()#subset=['Label','Code','Type','Parent_Code']) # Brittany put in a lot of dups
df_notes=df_notes.dropna(axis=1,how='all')

# Leave out value sets for the moment -
df_vs = pd.DataFrame(columns=df_vs.columns)

odf=goFlowsheet(df,df_vs,df_type)
odf=odf.append(goNotes(df_notes))
odf.to_csv(path_out, float_format='%.0f')

# Create a root node with code -1
#df.Parent_Code=df.Parent_Code.fillna('0')
#df=df.append(pd.Series({'Full_Label':'CONCERN','Label':'CONCERN','Code':'0','Type':'root','Parent_Code':'-1'},name='root'))
#df.loc[:,['Label','Code','Parent_Code','rn']].to_csv(path_out)




