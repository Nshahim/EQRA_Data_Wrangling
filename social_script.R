rm(list=ls())
#all done and log generated
############# install necessary packages #############
if(!require("tidyverse")) install.packages("tidyverse")
if(!require("fs")) install.packages("fs")
if(!require("readxl")) install.packages("readxl")
if(!require("writexl")) install.packages("writexl")
if(!require("dplyr")) install.packages("dplyr")
if(!require("xlsx")) install.packages("xlsx")
if(!require("openxlsx")) install.packages("openxlsx")
if(!require("lubridate")) install.packages("lubridate")

############# load libraries #############
library(readxl)
library(writexl)
library(dplyr)
library(summarytools)
library(tidyverse)
library(xlsx)
library(openxlsx)

############# Standard Columns #############
source("functions/EQRA_functions.R")
stdColumns = c(
  "Surveyor_Name",
  "Surveyor_Id",
  "Surveyor_Gender",
  "Site_Visit_Id",
  "Province",
  "District",
  "Line_Ministry_Name",
  "Line_Ministry_Project_Id",
  'Line_Ministry_SubProject_Id',
  'Line_Ministry_Sub_Project_Name_And_Description',
  'Sub_Project_Financial_Value_In_Afn',
  'School_Id',
  'CDC_CCDC_Gozar_Name',
  'CDC_CCDC_Gozar_ID',
  'Name_of_Contractor_Facilitating_Partner',
  'Type_Of_Site_Visit',
  'Type_Of_Visit',
  'If_not_a_first_Site_Visit_state_Original_Site_Visit_ID')

socialData = read_excel("input/raw_data/EQRA_Social_Final_DataSet_200408.xlsx", sheet="EQRA_Social_DataSet")

#loading employee data
#for call center employees
direc = "input/emp_data/EQRA_Data Collectors_Roster.xlsx"
empData = read_excel(direc)

empN <- empData %>% 
  unite("fullname", "Employee Name", "Employee Last Name", na.rm=T, sep = " ") %>% 
  select(fullname)

direc = "input/emp_data/Terminated contracts_ART TPMA.xls"
terminatedEmp = read_excel(direc)

############# Functions for checking data columns #############
#to display columns that does not exist
checkColumns(stdColumns, socialData)
#columns that exist
columnExist(stdColumns, socialData)

############# Fixing inconsistencies #############
names(socialData)[names(socialData) == "province"] = "Province"
names(socialData)[names(socialData) == "district"] = "District"
names(socialData)[names(socialData) == "line_ministry"] = "Line_Ministry_Name"
names(socialData)[names(socialData) == "subproject_id"] = "Line_Ministry_SubProject_Id"
names(socialData)[names(socialData) == "school_code"] = "School_Id"
names(socialData)[names(socialData) == "researcher_name"] = "Surveyor_Name"
names(socialData)[names(socialData) == "tpma_projectid"] = "Site_Visit_Id"
names(socialData)[names(socialData) == "mrrd_code"] = "Line_Ministry_Project_Id"
names(socialData)[names(socialData) == "cdc_name"] = "CDC_CCDC_Gozar_Name"


############# adding new columns with null values #############
socialData = socialData %>%
  add_column(Surveyor_Id = NA, .after="Surveyor_Name")
socialData = socialData %>%
  add_column(Surveyor_Gender = NA, .after="Surveyor_Id")
socialData = socialData %>%
  add_column(Line_Ministry_Sub_Project_Name_And_Description = NA, .after="Line_Ministry_SubProject_Id")
socialData = socialData %>%
  add_column(CDC_CCDC_Gozar_ID = NA, .after="CDC_CCDC_Gozar_Name")
socialData = socialData %>%
  add_column(Name_of_Contractor_Facilitating_Partner = NA, .after="CDC_CCDC_Gozar_ID")
socialData = socialData %>%
  add_column(Sub_Project_Financial_Value_In_Afn = NA, .after="School_Id")
socialData = socialData %>%
  add_column(Type_Of_Site_Visit = NA, .after="Name_of_Contractor_Facilitating_Partner")
socialData = socialData %>%
  add_column(Type_Of_Visit = NA, .after="Type_Of_Site_Visit")
socialData = socialData %>%
  add_column(If_not_a_first_Site_Visit_state_Original_Site_Visit_ID = NA, .after="Type_Of_Visit")

#to print the index of newly added columns 
for(i in 1:length(stdColumns)){
  cat(stdColumns[i], grep(stdColumns[i], names(socialData)), "\n")
}
raw_data <- socialData

############# to fill null values #############
#for Line Ministry Project ID / Name / Description
sampleData = read_excel("input/cleaned_data/201124 ARTF TPMA Sample Revised-LA_AMR_FT_101220.xlsx", sheet = "Sample Data Entry")
#changing data type from null to string
socialData$Line_Ministry_Sub_Project_Name_And_Description = as.character(socialData$Line_Ministry_Sub_Project_Name_And_Description)
socialData$Type_Of_Visit = as.character(socialData$Type_Of_Visit)
socialData$Type_Of_Site_Visit = as.character(socialData$Type_Of_Site_Visit)
socialData$Name_of_Contractor_Facilitating_Partner = as.character(socialData$Name_of_Contractor_Facilitating_Partner)
#manually filling a project name null value
socialData[369,"Line_Ministry_Name"] = sampleData[sampleData$`Line Ministry Project ID` == "24-2401-M0003" & sampleData$`Temporary PMT Code` == "TPMA-EQRA-104", "Line Ministry"]
#for Line_Ministry_Name
for (i in 1:nrow(socialData)){
  id = toString(socialData[i, "Line_Ministry_Project_Id"])
  siteVisitId = toString(socialData[i, "Site_Visit_Id"])
  # getting the data
  foundData = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,c("TPMA Site Visit Type", "Line Ministry sub-project name and description", "If appropriate, name of contractor")]
  if(nrow(foundData) > 0){
    socialData[i,"Type_Of_Visit"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"TPMA Site Visit Type"]
    socialData[i,"Type_Of_Site_Visit"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"If appropriate, type of site visit"]
    socialData[i,"Line_Ministry_Sub_Project_Name_And_Description"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry sub-project name and description"]
    socialData[i,"Name_of_Contractor_Facilitating_Partner"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "If appropriate, name of contractor"]
    # print(paste(i,"- ",foundData))
  }
}
#fixing inconsistent surveyor names
#this code doesnt work properly so I had to create a separate funciton for it
# socialData[socialData$Surveyor_Name == "Shabana","Surveyor_Name"] = "Shabana Karimi"
replaceName = function(oldValue, newValue){
  for(i in 1:nrow(socialData)){
    name = socialData[i,"Surveyor_Name"]
    if(name == oldValue && !is.na(name)){
      socialData[i,"Surveyor_Name"] <<- newValue
    }
  }
}
replaceName("Shabana", "Shabana Karimi")
replaceName("Abdul Sami", "Abdul Sami Hamnawa")
replaceName("Safatullah", "Sefatullah Benawa")
replaceName("Laliluma", "Laliluma Taherzad")
replaceName("Khatibullah", "Khatibullah Amini")
replaceName("Imamddin", "Imamddin Noori")
replaceName("Zarifa", "Zarifa Wahidi")
replaceName("Abdullah", "Abdullah Ghafoori")
replaceName("Shakila", "Shakila Sahibi")
replaceName("Salima", "Salima Mubarez")
replaceName("Sediqullah", "Sediqullah Salarzai")
replaceName("Nasratullah", "Nasratullah Darwazi")
replaceName("Barat Ali", "Barat Ali Noori")
replaceName("Hasina", "Hasina Noori")
replaceName("Ahmad", "Ahmad Ahmadi")
replaceName("Bibi Benazira", "Bibi Benazira Barakzai")
replaceName("Noor Ahmad", "Noor Ahmad Saqib")
replaceName("Jamila", "Jamila Noori")
replaceName("Mohammad Naeim", "Mohammad Naim Haqmal")
replaceName("Rohina", "Rohina Aswadi")
replaceName("Taj Muhmamad", "Taj Mohammad Taj")
replaceName("Nasar Ahmad", "Nesar Ahmad Ahmadi")
replaceName("Hasibullah", "Hasibullah Noori")
replaceName("Masoud", "Masoud Jamshedi")
#changing data type from null to string
socialData$Surveyor_Id = as.character(socialData$Surveyor_Id)
socialData$Surveyor_Gender = as.character(socialData$Surveyor_Gender)
surveyor = socialData[,"Surveyor_Name"]
missingEmp = data.frame()
found = F
count = 0
#to match employees from SocialData with employee data
for(i in 1:nrow(surveyor)){
  surN = toString(surveyor[i,1])
  found = F
  for(j in 1:nrow(empN)){
    empName = toString(empN[j,1])
    if( surN == empName){
      socialData[i,"Surveyor_Id"] = empData[j,"Employee unique ID"]
      socialData[i,"Surveyor_Gender"] = empData[j,"Gender"]
      count = count+1
      found = T
      # print(paste(i,"- ", "Name: ", surN, "ID: ", empData[j,"Employee unique ID"]))
    }
  }
  if(!found){
    missingEmp = rbind(missingEmp, surveyor[i,1])
  }
}
print(count)

############# For Data Cleanign Guidelines #############
##unifying the inconsistencies in province, district and CDC/village using GeoApp
geoApp = read_excel("input/cleaned_data/Geographies Information.xlsx", sheet = "District")
standardP = unique(geoApp[,"Province"])
standardDis = unique(geoApp[,"District"])

#### for Provinces ####
##changing data type from null to string
diffSpelling = checkData(unique(socialData["Province"]), standardP, F)
#manually fixing inconsistent province name
socialData[socialData$Province == "Hirat","Province"] = "Herat"

#### For districts #### 
diffSpelling = checkData(unique(socialData["District"]), standardDis, F)
#to print the province, district and the gozar names that are not in geo app
for(i in 1:nrow(diffSpelling)){
  row = unique(socialData[socialData$District == diffSpelling[i,1], c("Province", "District")])
  print(row)
}
#manually fixing spellings
socialData[socialData$District == "Zinda Jan","District"] = "Zendajan"
socialData[socialData$District == "Karukh","District"] = "Karrukh"
socialData[socialData$District == "Panjwayi","District"] = "Panjwayee"
socialData[socialData$District == "Nirkh","District"] = "Nerkh"
socialData[socialData$District == "Khwaja Umari","District"] = "Khwaja Omari"
socialData[socialData$District == "Qalay-I- Zal","District"] = "Qala-E-Zal"
socialData[socialData$District == "Chahar Dara","District"] = "Char Darah"
socialData[socialData$District == "Aliabad","District"] = "Ali Abad"
socialData[socialData$District == "Khanabad","District"] = "Khan Abad"
socialData[socialData$District == "Archi","District"] = "Dashti-E-Archi"
socialData[socialData$District == "Qaramqol","District"] = "Qaram Qul"
socialData[socialData$District == "Murghab","District"] = "Bala Murghab"
socialData[socialData$District == "Guzara","District"] = "Nizam-E-Shahid (Guzara)"
socialData[socialData$District == "Kushk","District"] = "Kushk-E-Kuhna"
socialData[socialData$District == "Maywand","District"] = "Maiwand"
socialData[socialData$District == "Shinkay","District"] = "Shinkai"
socialData[socialData$District == "Khost(Matun)","District"] = "Khost"
socialData[socialData$District == "Jaji Maydan","District"] = "Jaji Maidan"
socialData[socialData$District == "Nawa-i-Barak Zayi","District"] = "Nawa-E-Barikzayi"

#### for cdc_gozar_name #### 
geoAppVillage = read_excel("input/cleaned_data/Geographies Information.xlsx", sheet = "Village_CDC")
#subsetting villages using the Districts that are present in the dataset
villages <- geoAppVillage %>%
  filter(District %in% socialData$District) %>% 
  select(Village)
#to find the inconsistent gozar names
diffSpelling = checkData(unique(socialData["CDC_CCDC_Gozar_Name"]), villages,F)
#to print the province, district and the gozar names that are not in geo app
for(i in 1:nrow(diffSpelling)){
  row = unique(socialData[socialData$CDC_CCDC_Gozar_Name == diffSpelling[i,1], c("Province", "District","CDC_CCDC_Gozar_Name")])
  print(row)
}
#fixing inconsistent gozar names
socialData[socialData$CDC_CCDC_Gozar_Name == "Haji Shah Mohammad","CDC_CCDC_Gozar_Name"] = "Haji Shamohamd"
socialData[socialData$CDC_CCDC_Gozar_Name == "Haji shamohamd","CDC_CCDC_Gozar_Name"] = "Haji Shamohamd"
socialData[socialData$CDC_CCDC_Gozar_Name == "Sandwanoo wa shigai","CDC_CCDC_Gozar_Name"] = "Sandwanoo Wa Shigai"
socialData[socialData$CDC_CCDC_Gozar_Name == "Naw Abad e Kunjak","CDC_CCDC_Gozar_Name"] = "Naw Abad E Kunjak"
socialData[socialData$CDC_CCDC_Gozar_Name == "Lalamaidan number 1","CDC_CCDC_Gozar_Name"] = "Lalamaidan Number 1"
socialData[socialData$CDC_CCDC_Gozar_Name == "Choni Shor Ab","CDC_CCDC_Gozar_Name"] = "Chawni-E Shawrab"
socialData[socialData$CDC_CCDC_Gozar_Name == "Chogha-e Sufla","CDC_CCDC_Gozar_Name"] = "Chogha-E Sufla"
socialData[socialData$CDC_CCDC_Gozar_Name == "Aaq gozar","CDC_CCDC_Gozar_Name"] = "Aaq Gozar"
socialData[socialData$CDC_CCDC_Gozar_Name == "Pul takhta","CDC_CCDC_Gozar_Name"] = "Pul Takhta"
socialData[socialData$CDC_CCDC_Gozar_Name == "Khaja gul bid","CDC_CCDC_Gozar_Name"] = "Khaja Gul Bid"
socialData[socialData$CDC_CCDC_Gozar_Name == "Khaja qasam","CDC_CCDC_Gozar_Name"] = "Khaja Qasam"
socialData[socialData$CDC_CCDC_Gozar_Name == "Khaja sabazpush","CDC_CCDC_Gozar_Name"] = "Khaja Sabazpush"
socialData[socialData$CDC_CCDC_Gozar_Name == "Ab Bareek","CDC_CCDC_Gozar_Name"] = "Ab Baryk"
socialData[socialData$CDC_CCDC_Gozar_Name == "Ab baryk","CDC_CCDC_Gozar_Name"] = "Ab Baryk"
socialData[socialData$CDC_CCDC_Gozar_Name == "Qala qochi ulia wa sufla","CDC_CCDC_Gozar_Name"] = "Qala Qochi Ulia Wa Sufla"
socialData[socialData$CDC_CCDC_Gozar_Name == "Dowr mishi","CDC_CCDC_Gozar_Name"] = "Dowr Mishi"
socialData[socialData$CDC_CCDC_Gozar_Name == "Rabat sangi ulia","CDC_CCDC_Gozar_Name"] = "Rabat Sangi Ulia"
socialData[socialData$CDC_CCDC_Gozar_Name == "Fazal ahmd jan zoriha","CDC_CCDC_Gozar_Name"] = "Fazal Ahmd Jan Zoriha"
socialData[socialData$CDC_CCDC_Gozar_Name == "Kham musa khil","CDC_CCDC_Gozar_Name"] = "Kham Musa Khil"
socialData[socialData$CDC_CCDC_Gozar_Name == "Tagab mahich","CDC_CCDC_Gozar_Name"] = "Tagab Mahich"
socialData[socialData$CDC_CCDC_Gozar_Name == "Satkee Kali","CDC_CCDC_Gozar_Name"] = "Satkee Kalia"
socialData[socialData$CDC_CCDC_Gozar_Name == "Yatim e Bala","CDC_CCDC_Gozar_Name"] = "Yatim E Bala"

#for village_name and column
#changing data type from null to string
socialData$CDC_CCDC_Gozar_ID = as.character(socialData$CDC_CCDC_Gozar_ID)
for (i in 1:nrow(socialData)){
  socialData[i,"CDC_CCDC_Gozar_ID"] = socialData[i,"Line_Ministry_Project_Id"]
}
#### changing the datatype of the financial value column ####
socialData$CDC_CCDC_Gozar_ID = as.character(socialData$CDC_CCDC_Gozar_ID)

for (i in 1:nrow(socialData)){
  socialData[i,"CDC_CCDC_Gozar_ID"] = socialData[i,"Line_Ministry_Project_Id"]
}
socialData$Sub_Project_Financial_Value_In_Afn = as.integer(socialData$Sub_Project_Financial_Value_In_Afn)


##### to verify date formats ####
#all the date columns are correct
view(socialData[grep("date|time|start|end", names(socialData), ignore.case = T, value = T)])

socialData <- socialData %>% 
  mutate(SubmissionDate = 
           format.Date(convertToDateTime(SubmissionDate), "%d/%m/%Y %I:%M:%S %p"),
         starttime = 
           format.Date(convertToDateTime(starttime), "%d/%m/%Y %I:%M:%S %p"),
         endtime = 
           format.Date(convertToDateTime(endtime), "%d/%m/%Y %I:%M:%S %p"))


##### to compare data with Sample Sheet ####
socialColumns = c("Site_Visit_Id",
                 "Line_Ministry_Project_Id",
                 "Line_Ministry_SubProject_Id",
                 "Line_Ministry_Name",
                 "Line_Ministry_Sub_Project_Name_And_Description",
                 "Type_Of_Visit",
                 "Type_Of_Site_Visit",
                 "Province",
                 "District",
                 "CDC_CCDC_Gozar_Name")
sampleColumns = c("Temporary PMT Code", 
                  "Line Ministry Project ID",
                  "Line Ministry sub-project ID",
                  "Line Ministry", 
                  "Line Ministry sub-project name and description",
                  "TPMA Site Visit Type",
                  "If appropriate, type of site visit",
                  "Province Name [Auto-Filled]",
                  "District Name [Auto-Filled]",
                  "CDC Name [Auto-filled]")
inconRows <- checkColumnsInTabs(unique(socialData[socialColumns]), sampleData[sampleColumns])
# to extract only the column names that have problem
cols <- inconRows$Inconsistent_Column_Name %>%
  str_split(pattern = " - ") %>%
  unlist() %>% 
  append(c("Site_Visit_Id", "Line_Ministry_SubProject_Id"), .) %>%
  append("Inconsistent_Column_Name") %>% 
  unique()
#extracting the data for those cols
inconData <- inconRows[cols]
write.xlsx(inconData, "output/inconsistent_data/EQRA_March_Social_InconsistentData.xlsx")

#######to ensure data consistency for each tab ####
#*** there are no other tabs in this dataset
#### to compare the TPMA codes with the social data ####
#to compare the TPMA codes with the infra Data
infraData <-  read_excel("output/cleaned_data/EQRA_Infrastructure_CLEANED_DataSet_200408.xlsx", sheet="eqra_3_1")
##all site visit IDs of social is in infra
checkData(unique(socialData["Site_Visit_Id"]), infraData["Site_Visit_Id"], F)

##### Checking Duplicates ##### 
#to ensure data consistency for each column
#for surveyor name
checkDuplicates(socialData, c("Surveyor_Name", "Surveyor_Id", "Surveyor_Gender"), F)

#for id
checkDuplicates(socialData, c("Site_Visit_Id", "Line_Ministry_SubProject_Id", "Line_Ministry_Project_Id", "Type_Of_Site_Visit", "Type_Of_Visit"), F)

#for minitry project ID
checkDuplicates(socialData, c("Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id"), F)

checkDuplicates(socialData, c("Line_Ministry_Project_Id","Province", "District", "CDC_CCDC_Gozar_Name", "CDC_CCDC_Gozar_ID", "Line_Ministry_Name"), T)

#for subproject ID
##the vector below contains some columns that are not in the dataset
vec = c("Line_Ministry_SubProject_Id", "Line_Ministry_Sub_Project_Name_And_Description", 
        "Sub_Project_Financial_Value_In_Afn", "School_Id", 
        "Name_of_Contractor_Facilitating_Partner")
checkDuplicates(socialData, vec, show=F)

# #for contractor facilitating partner
checkDuplicates(socialData, c("Name_of_Contractor_Facilitating_Partner", "Contractor_License_number_Facilitating_Partner_Registration_Number"), show=F)

##### Creating Log ####
col_vec <- c("Line_Ministry_SubProject_Id", "Line_Ministry_Name", "Line_Ministry_Sub_Project_Name_And_Description", "Type_Of_Visit", 
             "Type_Of_Site_Visit", "Surveyor_Name", "Surveyor_Id", "Surveyor_Gender", "Province", "District", "CDC_CCDC_Gozar_Name", "CDC_CCDC_Gozar_ID",
             "SubmissionDate", "starttime","endtime", "Name_of_Contractor_Facilitating_Partner")
log <- create_log(raw_data, socialData, col_vec, "instanceID")

##### Creating Log ####
col_vec <- c("Line_Ministry_SubProject_Id", "Line_Ministry_Name", "Line_Ministry_Sub_Project_Name_And_Description", "Type_Of_Visit", 
             "Type_Of_Site_Visit", "Surveyor_Name", "Surveyor_Id", "Surveyor_Gender", "Province", "District", "CDC_CCDC_Gozar_Name", "CDC_CCDC_Gozar_ID",
             "SubmissionDate", "starttime","endtime", "Name_of_Contractor_Facilitating_Partner")
log <- create_log(raw_data, socialData, col_vec, "instanceID")

##### Exporting Datasets ##### 
#main data 
write_xlsx(socialData, "output/cleaned_data/EQRA_Social_Final_DataSet_200408.xlsx")
#Additional useful data 
listOfAdditionalData = list("EQRA_Social_DataSet"= log)
write.xlsx(listOfAdditionalData, file = "output/cleaning_log_for_March_social.xlsx")


