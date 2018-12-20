# file get_packager_code_from_html_ireland.py
# coding: utf-8

# Converting information about approved Food Establishments of Ireland that are super not-nice to one nice csv.  
# All data come from here :  
# https://www.fsai.ie/food_businesses/approved_food_establishments.html
# 

# In[]:

urls = ['https://oapi.fsai.ie/LAApprovedEstablishments.aspx',
        'https://oapi.fsai.ie/AuthReg99901Establishments.aspx',
        'https://oapi.fsai.ie/HSEApprovedEstablishments.aspx'
       ]
urls_second_format = ['http://www.sfpa.ie/Seafood-Safety/Registration-Approval-of-Businesses/List-of-Approved-Establishments-and-Vessels/Approved-Establishments',
                      'http://www.sfpa.ie/Seafood-Safety/Registration-Approval-of-Businesses/Approved-Freezer-Vessels'
                     ]

csv_file = 'Ireland_concatenated.csv'

import pandas as pd
pages = [pd.read_html(url) for url in urls]
pages2= [pd.read_html(url) for url in urls_second_format]


# In[]:

def ireland_correction_of_1_dataframe(df):     #Version to get anything
    #print ("df as recuperated :")
    #print(df.head())
    df.columns = df.iloc[[0]].values.tolist()
    df = df.rename(columns={' Address': 'Address'})
    df=df.drop(df.index[0]) #
    row_reference = df.iloc[0]
    
    if 'Approval_Number' not in df.columns:
        print("this table has no approval number and was not added")
        return pd.DataFrame()

    df_is_null=df.isnull()
    for i in range(1,len(df)): #len(df)
        if df_is_null.iloc[i,len(df.columns)-1]:   #We assume that on a row, there is no merged cell(null in pandas) on the webpage after an unmerged cell (not null)
            row_retrieved=[]
            value = ""
            j=0   
            while not df_is_null.iloc[i,j]:
                value=df.iloc[i,j]
                row_retrieved.append(value)
                #print("while loop - j:"+str(j)+ "value : "+str(value))
                j+=1
            row = row_reference.copy()
            row[len(row)-len(row_retrieved):len(row)]=row_retrieved
            df.iloc[i]= row

        row_reference =df.iloc[i]
    

    df["Address"]=df["Address"].apply(add_space_before_uppercase)

    #print ("result corrected : ")
    #print(df.head())
    return df

#df=pages[0][18]
#ireland_correction_of_1_dataframe(df)


# In[]:

def add_space_before_uppercase(words):  
        result=""
        for s in words:
            if isinstance(s, str):
                if s.isupper():
                    result+=" "
            result+=s
        return result
""" This could have been done more efficienty using Regex r"[a-z][A-Z]"" and avoid r" [A-Z]". But google maps recognize it this way."""


# In[ ]:

df=pd.DataFrame()


# In[]:

i=0
for page in pages:
    j=0
    for table in page:
        df=df.append(ireland_correction_of_1_dataframe(table), ignore_index=True)
        #print ("table "+str(j)+" is ok")
        #j+=1
    print ("page "+str(i)+" is done")
    i+=1
print("finished for all in urls!")


# In[]:

i=0
for page2 in pages2:
    j=0
    for table in page2:
        #print (table.head(3))
        table=table.drop(table.index[0])
        table.loc[0,0]='Approval_Number'        
        #print (ireland_correction_of_1_dataframe(table).head())
        df=df.append(ireland_correction_of_1_dataframe(table), ignore_index=True)
        print ("table "+str(j)+" is ok")
        j+=1
    print ("page "+str(i)+" is done")
    i+=1
print("finished for table in urls_second_format!")


# In[]:


df.to_csv(csv_file, index = False)
