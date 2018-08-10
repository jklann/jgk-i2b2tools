""" Ontology builder chopped up to parse the PCORnet CDM v4 valueset file -
      An Excel file with sheets named for the modifier prefix and two columns, a Code (modifier code), and a name (c_name)
      Outputs many files, one for each sheet.

    Note that this is specifically to parse the CDM valueset file, released with CDMv4.

  By Jeff Klann, PhD 10/2017
"""
import re
from typing import Any, Union

import numpy as np
import pandas as pd
from pandas import Series, DataFrame, Index
from pandas.core.generic import NDFrame

from ontology_tools import metadataxml as mdx

path_in = '/Users/jeffklann/Google Drive/SCILHS Phase II/Committee, Cores, Panels/Informatics & Technology Core/PCORnet CDM/v41/PCORnet_CDM_ValueSet_ReferenceFile_v1.41jk.xlsx'
path_out = '/Users/jeffklann/Dropbox (Partners HealthCare)/HMS/Projects/SCILHS/ontology_dev/cdmv4'

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
    odf.c_basecode[df['VStype'].notnull()]=odf['c_basecode'].str.cat(df['VStype'].str.cat(df['VScode'],sep=':'),sep='|') # Support either value set codes or regular code sets
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

""" Input a df with (minimally): two or three columns, 0 is c_name, 1 is code. 2 is optional grouping.
       Grouping column must be called Grouping or GroupingV2. 
       In Grouping, the folders are automatically generated from the group names with no codes.
       In GroupingV2, the folders are specified by rows of: Code, Blank Cell, Grouping.
       Second argument is a root node. Third is a prefix for this modifier set.
       Outputs an i2b2 ontology compatible df. 
        """
def OntSimpleBuild(df,root0,prefix,leaf):
    odf = pd.DataFrame()
    odf['c_name']=df.iloc[:,1]
    odf['c_name'] = odf['c_name'].apply(lambda x: x if (len(str(x))<3 or str(x)=='nan') else str(x).title().strip(' _').replace('_',' ').replace('Zz ','zz '))
    odf['c_symbol']=df.iloc[:,0].astype(str).apply(lambda x: re.sub('[_ /,]','',x.title())[0:49])

    if len(df.columns)>2 and (df.columns[2]=='Grouping' or df.columns[2]=='GroupingV2'):
        odf.loc[odf['c_name'].notna(),'c_fullname'] = '\\' + str(root0) + '\\' + str(prefix) + '\\' + df.iloc[:, 2].astype(str).apply(lambda x: re.sub('[_ /,]','',x.title())[0:49]) +'\\' + \
                            (odf['c_symbol'] + '\\' if len(odf['c_symbol'])>0 else '')
        odf.loc[odf['c_name'].isna(),'c_fullname'] = '\\' + str(root0) + '\\' + str(prefix) + '\\' + df.iloc[:, 2].astype(str).apply(lambda x: re.sub('[_ /,]','',x.title())[0:49]) +'\\'

        odf['c_path'] = '\\' + root0 + '\\' + prefix + '\\' + df.iloc[:, 2].astype(str).apply(lambda x: re.sub('[_ /,]','',x.title())[0:49]) + '\\'
        odf['c_hlevel']=-1
        odf.loc[odf['c_name'].notna(),'c_hlevel'] = 3
        odf.loc[odf['c_name'].isna(),'c_hlevel'] = 2
    else:
        odf['c_fullname']='\\'+str(root0)+'\\'+str(prefix)+'\\'+ odf['c_symbol'] +'\\'
        odf['c_path'] = '\\' + root0 + '\\' + prefix + '\\'
        odf['c_hlevel']=2

    odf['c_visualattributes']='RAE' if leaf is True else 'DAE'

    odf.loc[(odf['c_name'] == 'zz No Information'), 'c_visualattributes'] = 'RHE'

    odf['c_basecode']=prefix+':'+df.iloc[:,0].astype(str) if leaf is True else None
    odf['c_synonym_cd']='N'
    odf['c_facttablecolumn']='modifier_cd'
    odf['c_tablename']='modifier_dimension'
    odf['c_columnname']='modifier_path'
    odf['c_columndatatype']='T'
    odf['c_totalnum']=''
    odf['c_operator']='LIKE'
    odf['c_dimcode']=odf['c_fullname']
    odf['c_comment']=''
    odf['c_tooltip']=odf['c_fullname'] # Tooltip right now is just the fullname again
    odf['m_applied_path']='\\PCORI\\EXAMPLE\\%'
    odf['c_metadataxml']=''#df[['vtype','Label']].apply(lambda x: mdx.genXML(mdx.mapper(x[0]),x[1]),axis=1)
    odf['sourcesystem_cd']='PCORNET_CDMv4'
    odf['pcori_basecode']=df.iloc[:,0].astype(str) if leaf is True else None

    if len(df.columns) > 2 and df.columns[2] == 'GroupingV2':
        odf['GroupingV2']=df.GroupingV2.apply(lambda x: str(x).title().strip(' _').replace('_',' ').replace('Zz ','zz '))
        odf.loc[odf['c_name'].isna(),'c_name']=odf.GroupingV2
        odf=odf.drop('GroupingV2',axis=1)
        #odf[odf['c_symbol'] == ''].c_name = odf.GroupingV2
    if len(df.columns)>2 and df.columns[2]=='Grouping':
        ndf = df[['Grouping','Grouping']].copy()
        ndf.columns = ['Code','Text']
        ndf = ndf.drop_duplicates()
        odf=pd.concat([odf,OntSimpleBuild(ndf,root0,prefix,False)])
    return odf

def OntTopRow(root0,prefix,title,tooltip):
    odf = pd.DataFrame(index=[0])
    odf['c_name']=title.title()
    odf['c_fullname']='\\'+root0+'\\'+prefix+'\\'
    odf['c_hlevel']=1
    odf['c_visualattributes']='DAE'
    odf['c_path']='\\'+root0+'\\'
    odf['c_basecode']=prefix
    odf['c_symbol']=root0
    odf['c_synonym_cd']='N'
    odf['c_facttablecolumn']='modifier_cd'
    odf['c_tablename']='modifier_dimension'
    odf['c_columnname']='modifier_path'
    odf['c_columndatatype']='T'
    odf['c_totalnum']=''
    odf['c_operator']='LIKE'
    odf['c_dimcode']='\\'+root0+'\\'+prefix+'\\'
    odf['c_comment']=''
    odf['c_tooltip']=tooltip
    odf['m_applied_path']='\\PCORI\\EXAMPLE\\%'
    odf['c_metadataxml']=''#df[['vtype','Label']].apply(lambda x: mdx.genXML(mdx.mapper(x[0]),x[1]),axis=1)
    odf['sourcesystem_cd'] = 'PCORNET_CDMv4'
    odf['pcori_basecode']=None
    return odf

def OntExampleRow():
    odf = pd.DataFrame(index=[0])
    odf['c_name']='Example'
    odf['c_fullname']='\\PCORI\\EXAMPLE\\'
    odf['c_hlevel']=1
    odf['c_visualattributes']='LAE'
    odf['c_path']='\\PCORI\\'
    odf['c_basecode']='V4EXAMPLE'
    odf['c_symbol']='EXAMPLE'
    odf['c_synonym_cd']='N'
    odf['c_facttablecolumn']='concept_cd'
    odf['c_tablename']='concept_dimension'
    odf['c_columnname']='concept_path'
    odf['c_columndatatype']='T'
    odf['c_totalnum']=''
    odf['c_operator']='LIKE'
    odf['c_dimcode']='\\PCORI\\EXAMPLE\\'
    odf['c_comment']=''
    odf['c_tooltip']='Example'
    odf['m_applied_path']='@'
    odf['c_metadataxml']=''#df[['vtype','Label']].apply(lambda x: mdx.genXML(mdx.mapper(x[0]),x[1]),axis=1)
    odf['sourcesystem_cd'] = 'PCORNET_CDMv4'
    odf['pcori_basecode']=None
    return odf

# Build CDM v4 valueset ontologies
def goCDMvs(df,code,title,tooltip):
    # Add the has_children column with default value (before adding valuessets)
    df['has_children'] = 'N'


    # Build ontology
    odf = OntSimpleBuild(df,'PCORI_MOD',code,True)
    odf = pd.concat([odf,OntTopRow('PCORI_MOD',code,title,tooltip)])
    #odf = OntProcess(df)
    #odf = OntBuild(odf)
    return odf


# Load the ontology
df = pd.read_excel(path_in,sheet_name=None)
dff = pd.DataFrame()
dfi = df['Info']
for k,v in df.items():
    if v.columns[0]=='Code':
        tooltip = dfi[dfi.Field_Name == k].Comments+"\\n"+dfi[dfi.Field_Name == k].ValueSet_Source # type: Union[Union[None, DataFrame, type, Series, NDFrame, Index], Any]
        title = k.title().replace('_',' ')
        k=k.replace('_','',1)
        print(k+":"+title+":"+tooltip)
        odf=goCDMvs(v,k,title,tooltip)
        odf.to_csv(path_out+'/'+k+'.csv',float_format='%.0f')
        dff = pd.concat([dff,odf])
dff = pd.concat([dff,OntExampleRow()])
dff.to_csv(path_out+'/'+'full.csv',float_format='%0.f')



