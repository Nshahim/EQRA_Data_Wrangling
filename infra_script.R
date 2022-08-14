rm(list=ls())
#all done and log generated
############# install necessary packages #############
#install.packages("summarytools")
if(!require("tidyverse")) install.packages("tidyverse")
if(!require("fs")) install.packages("fs")
if(!require("readxl")) install.packages("readxl")
if(!require("writexl")) install.packages("writexl")
if(!require("dplyr")) install.packages("dplyr")
if(!require("xlsx")) install.packages("xlsx")
if(!require("openxlsx")) install.packages("openxlsx")
# Summarytools documentation: https://cran.r-project.org/web/packages/summarytools/vignettes/Introduction.html

############# load libraries #############
library(readxl)
library(writexl)
library(dplyr)
library(summarytools)
library(tidyverse)
library(tibble)
library(fs)
library(xlsx)
library(openxlsx)

############# Loading Datasets #############
source("functions/EQRA_functions.R")

stdColumns <- c(
  "Surveyor_Name",
  "Surveyor_Id",
  "Surveyor_Gender",
  "Site_Visit_Id",
  "Province",
  "District",
  "Village_Cdc_Name",
  "Line_Ministry_Name",
  "Line_Ministry_Project_Id",
  'Line_Ministry_SubProject_Id',
  'Line_Ministry_sub_project_name',
  'Line_Ministry_Sub_Project_Name_And_Description',
  'Sub_Project_Financial_Value_In_Afn',
  'School_Id',
  'CDC_CCDC_Gozar_Name',
  'CDC_CCDC_Gozar_ID',
  'Name_of_Contractor_Facilitating_Partner',
  'Type_Of_Site_Visit',
  'Type_Of_Visit',
  'If_not_a_first_Site_Visit_state_Original_Site_Visit_ID',
  'SubSubproject_status_based_on_MIS_database'
)
infraData <-  read_excel("input/raw_data/EQRA_Infrastructure_Final_DataSet_200408.xlsx", sheet="eqra_3_1")
#row 70 is all null
infraData = infraData[1:69,]
#for employee data
direc <- "input/emp_data/DVEs and SMEs list_July 2020.xlsx"
empData <- read_excel(direc, sheet = "July payment tracker_DVE-SME")
#to paste together the name and the lastname
empN <- empData %>% 
  unite("fullName",'First Name':'Last Name', sep=" ") %>% 
  select(fullName)

direc <- "input/emp_data/Terminated contracts_ART TPMA.xls"
terminatedEmp <- read_excel(direc)

############# Functions for checking data columns #############
#to display columns that does not exist
checkColumns(stdColumns, infraData)
#columns that exist
columnExist(stdColumns, infraData)

############# Fixing inconsistencies #############
names(infraData)[names(infraData) == "province"] = "Province"
names(infraData)[names(infraData) == "district"] = "District"
names(infraData)[names(infraData) == "school_id"] = "School_Id"
names(infraData)[names(infraData) == "ministry_subproject_id"] = "Line_Ministry_SubProject_Id"
names(infraData)[names(infraData) == "ministry_sub_project_name"] = "Line_Ministry_sub_project_name"
names(infraData)[names(infraData) == "cdcccdcgozar_name"] = "CDC_CCDC_Gozar_Name"
names(infraData)[names(infraData) == "tpma_monitor_name"] = "Surveyor_Name"
names(infraData)[names(infraData) == "msi_project_id"] = "Site_Visit_Id"
names(infraData)[names(infraData) == "financial_status_of_the_subproject_"] = "Sub_Project_Financial_Value_In_Afn"
names(infraData)[names(infraData) == "project"] = "Line_Ministry_Name"

############# adding new columns with null values #############
infraData = infraData %>%
  add_column(Surveyor_Id = NA, .after="Surveyor_Name")
infraData = infraData %>%
  add_column(Surveyor_Gender = NA, .after="Surveyor_Id")
infraData = infraData %>%
  add_column(Village_Cdc_Name = NA, .after="District")
infraData = infraData %>%
  add_column(Line_Ministry_Project_Id = NA, .after="Line_Ministry_Name")
infraData = infraData %>%
  add_column(Line_Ministry_Sub_Project_Name_And_Description = NA, .after="Line_Ministry_sub_project_name")
infraData = infraData %>%
  add_column(CDC_CCDC_Gozar_ID = NA, .after="CDC_CCDC_Gozar_Name")
infraData = infraData %>%
  add_column(Name_of_Contractor_Facilitating_Partner = NA, .after="CDC_CCDC_Gozar_ID")
infraData = infraData %>%
  add_column(Type_Of_Site_Visit = NA, .after="Name_of_Contractor_Facilitating_Partner")
infraData = infraData %>%
  add_column(Type_Of_Visit = NA, .after="Type_Of_Site_Visit")
infraData = infraData %>%
  add_column(If_not_a_first_Site_Visit_state_Original_Site_Visit_ID = NA, .after="Type_Of_Visit")
infraData = infraData %>%
  add_column(SubSubproject_status_based_on_MIS_database = NA, .after="If_not_a_first_Site_Visit_state_Original_Site_Visit_ID")

#to print the index of newly added columns 
# for(i in 1:length(stdColumns)){
#   cat(stdColumns[i], grep(stdColumns[i], names(infraData)), "\n")
# }
raw_data <- infraData
############# to fill null values #############
#for Line Ministry Project ID / Name / Description
sampleData = read_excel("input/cleaned_data/201124 ARTF TPMA Sample Revised-LA_AMR_FT_101220.xlsx", sheet = "Sample Data Entry")
#changing data type from null to string
infraData$Line_Ministry_Project_Id = as.character(infraData$Line_Ministry_Project_Id)
infraData$Line_Ministry_Sub_Project_Name_And_Description = as.character(infraData$Line_Ministry_Sub_Project_Name_And_Description)
infraData$Type_Of_Visit = as.character(infraData$Type_Of_Visit)
infraData$Type_Of_Site_Visit = as.character(infraData$Type_Of_Site_Visit)
infraData$Name_of_Contractor_Facilitating_Partner = as.character(infraData$Name_of_Contractor_Facilitating_Partner)

#for Line_Ministry_Project_Id
for (i in 1:nrow(infraData)){
  #fetching Line_Ministry_Subproject_Id
  subProjectId = infraData[i,"Line_Ministry_SubProject_Id"]
  #splitting each character
  firstRow = toString(subProjectId[1,1])
  firstRow = strsplit(firstRow, "")[[1]]
  #to count the number of dashes
  count = 0;
  id = ""
  for(j in firstRow){
    if(j == "-"){
      count=count+1
    }
    #only take the characters before the third dash
    if(count < 3){
      id = paste(id,toString(j), sep = "")
    }
  }
  infraData[i, "Line_Ministry_Project_Id"] = id
}

#for Line_Ministry_Name
#fill the Project id of the 67 and 68 rows in the sample dataset first
for (i in 1:nrow(infraData)){
  id = toString(infraData[i, "Line_Ministry_Project_Id"])
  siteVisitId = toString(infraData[i, "Site_Visit_Id"])
  
  #row 67 does not have any corresponding data in the sample dataset
  if(i == 67){
    next
  } else {
    infraData[i,"Line_Ministry_Name"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry"]
    infraData[i,"Line_Ministry_Sub_Project_Name_And_Description"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"Line Ministry sub-project name and description"]
    infraData[i,"Type_Of_Visit"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"TPMA Site Visit Type"]
    infraData[i,"Line_Ministry_SubProject_Id"] <- sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry sub-project ID"]
    infraData[i,"Type_Of_Site_Visit"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"If appropriate, type of site visit"]
    infraData[i,"Name_of_Contractor_Facilitating_Partner"] = sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId,"If appropriate, name of contractor"]
    # print(paste(i, "- ", sampleData[sampleData$`Line Ministry Project ID` == id & sampleData$`Temporary PMT Code` == siteVisitId, "Line Ministry"]))
  }
}

#completing Surveyor's ID from the employee data 
#changing data type from null to string
infraData$Surveyor_Id = as.character(infraData$Surveyor_Id)
infraData$Surveyor_Gender <- "Male"
surveyor = infraData[,"Surveyor_Name"]
missingEmp = list()
found = F
count = 0
#to match employees from infraData with employee data
for(i in 1:nrow(surveyor)){
  surN = toString(surveyor[i,1])
  found = F
  for(j in 1:nrow(empN)){
    empName = toString(empN[j,1])
    if( surN == empName){
      infraData[infraData$Surveyor_Name == surN,"Surveyor_Id"] = empData[j,"ATR ID #"]
      count = count+1
      found = T
    } 
  }
  if(!found){
    for(k in 1:nrow(terminatedEmp)){
      empName = toString(terminatedEmp[k,2])
      if( surN == empName){
        infraData[infraData$Surveyor_Name == surN,"Surveyor_Id"] = terminatedEmp[k,"ATR ID NO"]
        count = count+1
        found = T
      }
    }
    if(!found){
      missingEmp = rbind(missingEmp, surN)
    }
  }
}
print(count)

############# For Data Cleanign Guidelines #############
##unifying the inconsistencies in province, district and CDC/village using GeoApp
geoApp = read_excel("input/cleaned_data/Geographies Information.xlsx", sheet = "District")
standardP = unique(geoApp[,"Province"])
standardDis = unique(geoApp[,"District"])
##### for Provinces ##### 
#changing data type from null to string
diffSpelling = checkData(unique(infraData["Province"]), standardP, F)
#manually fixing inconsistent province name
infraData[infraData$Province == "BADGHIS", "Province"] = "Badghis"

##### For districts ##### 
diffSpelling = checkData(unique(infraData["District"]), standardDis, F)
#to print the province, district and the gozar names that are not in geo app
for(i in 1:nrow(diffSpelling)){
  row = unique(infraData[infraData$District == diffSpelling[i,1], c("Province", "District")])
  print(row)
}

#manually fixing spellings
infraData[infraData$District == "Zinda Jan","District"] = "Zendajan"
infraData[infraData$District == "Karukh","District"] = "Karrukh"
infraData[infraData$District == "Panjwayi","District"] = "Panjwayee"
infraData[infraData$District == "Nirkh","District"] = "Nerkh"
infraData[infraData$District == "Khwaja Umari","District"] = "Khwaja Omari"
infraData[infraData$District == "Qalay-I- Zal","District"] = "Qala-E-Zal"
infraData[infraData$District == "Chahar Dara","District"] = "Char Darah"
infraData[infraData$District == "Aliabad","District"] = "Ali Abad"
infraData[infraData$District == "Khanabad","District"] = "Khan Abad"
infraData[infraData$District == "Archi","District"] = "Dashti-E-Archi"
infraData[infraData$District == "Qaramqol","District"] = "Qaram Qul"
infraData[infraData$District == "Murghab","District"] = "Bala Murghab"
infraData[infraData$District == "Guzara","District"] = "Nizam-E-Shahid (Guzara)"
infraData[infraData$District == "Kushk","District"] = "Kushk-E-Kuhna"
infraData[infraData$District == "Maywand","District"] = "Maiwand"
infraData[infraData$District == "Shinkay","District"] = "Shinkai"
infraData[infraData$District == "Khost(Matun)","District"] = "Khost"
infraData[infraData$District == "Jaji Maydan","District"] = "Jaji Maidan"
#searched based on cdc gozar name
infraData[infraData$District == "Dand","District"] = "Kandahar"
infraData[infraData$District == "Nawa-i-Barak Zayi","District"] = "Nawa-E-Barikzayi"


##### for cdc_gozar_name ##### 
geoAppVillage = read_excel("input/cleaned_data/Geographies Information.xlsx", sheet = "Village_CDC")
#subsetting villages using the Districts that are present in the dataset
villages <- geoAppVillage %>%
  filter(District %in% infraData$District) %>% 
  select(Village)

#to find the inconsistent gozar names
diffSpelling = checkData(unique(infraData["CDC_CCDC_Gozar_Name"]), villages, F)
#to print the province, district and the gozar names that are not in geo app
for(i in 1:nrow(diffSpelling)){
  row = unique(infraData[infraData$CDC_CCDC_Gozar_Name == diffSpelling[i,1], c("Province", "District","CDC_CCDC_Gozar_Name")])
  print(row)
}
#fixing inconsistent gozar names
infraData[infraData$CDC_CCDC_Gozar_Name == "Haji Shah Mohammad","CDC_CCDC_Gozar_Name"] = "Haji Shamohamd"
infraData[infraData$CDC_CCDC_Gozar_Name == "Kargar Khana Keshktan","CDC_CCDC_Gozar_Name"] = "Kargar Khana Keshiktan"
infraData[infraData$CDC_CCDC_Gozar_Name == "Chilghor","CDC_CCDC_Gozar_Name"] = "Chilghor Hajji Kabuli"
infraData[infraData$CDC_CCDC_Gozar_Name == "Pass Baswal Maroof Khil","CDC_CCDC_Gozar_Name"] = "Pass Baswal Maroof Khail"
infraData[infraData$CDC_CCDC_Gozar_Name == "Sandwanoo wa shigai","CDC_CCDC_Gozar_Name"] = "Sandwanoo Wa Shigai"
infraData[infraData$CDC_CCDC_Gozar_Name == "Lala Maidan Number 1","CDC_CCDC_Gozar_Name"] = "Lalamaidan Number 1"
infraData[infraData$CDC_CCDC_Gozar_Name == "Choni Shorab","CDC_CCDC_Gozar_Name"] = "Chawni-E Shawrab"
infraData[infraData$CDC_CCDC_Gozar_Name == "Chogha-e-Sufla","CDC_CCDC_Gozar_Name"] = "Chogha-E Sufla"
infraData[infraData$CDC_CCDC_Gozar_Name == "Imam Ali Tajik","CDC_CCDC_Gozar_Name"] = "Emam Ali Tajik"
infraData[infraData$CDC_CCDC_Gozar_Name == "Arabab Rahim Jan wa Arab ha","CDC_CCDC_Gozar_Name"] = "Arbab Rahim Jan Wa Arab Ha"
infraData[infraData$CDC_CCDC_Gozar_Name == "Sofia wa Kosa ha","CDC_CCDC_Gozar_Name"] = "Sofai Ha Wa Kosa Ha"
infraData[infraData$CDC_CCDC_Gozar_Name == "Padeh Laghari","CDC_CCDC_Gozar_Name"] = "Padah Laghary"
infraData[infraData$CDC_CCDC_Gozar_Name == "Sarah Dara Gandab","CDC_CCDC_Gozar_Name"] = "Sar Darah Ganda Ab"
infraData[infraData$CDC_CCDC_Gozar_Name == "Taht Dara Gandab","CDC_CCDC_Gozar_Name"] = "Taht Dara Ganda Ab"
infraData[infraData$CDC_CCDC_Gozar_Name == "Salam By Arbab Sardar","CDC_CCDC_Gozar_Name"] = "Samad By Arbab Sardar"
infraData[infraData$CDC_CCDC_Gozar_Name == "Bahra Khana","CDC_CCDC_Gozar_Name"] = "Barah Khanah"
infraData[infraData$CDC_CCDC_Gozar_Name == "Kham Ehsaq Zai","CDC_CCDC_Gozar_Name"] = "Kham Ab Eshaq Zai"
infraData[infraData$CDC_CCDC_Gozar_Name == "Pas Ab Joi Khawaja","CDC_CCDC_Gozar_Name"] = "Pas Ab Joi Khawja"
infraData[infraData$CDC_CCDC_Gozar_Name == "Muhammad Zai Muhammad Omar","CDC_CCDC_Gozar_Name"] = "Muhammad Zai Muhammad Omer Khan"
infraData[infraData$CDC_CCDC_Gozar_Name == "Khaja Sabzpush","CDC_CCDC_Gozar_Name"] = "Khaja Sabazpush"
infraData[infraData$CDC_CCDC_Gozar_Name == "Kham Musa Khel","CDC_CCDC_Gozar_Name"] = "Kham Musa Khil"
infraData[infraData$CDC_CCDC_Gozar_Name == "Hotel New Kalai","CDC_CCDC_Gozar_Name"] = "Hotal New Kalai"
infraData[infraData$CDC_CCDC_Gozar_Name == "Lwar Nawabad","CDC_CCDC_Gozar_Name"] = "Lwar Naw Abad"
infraData[infraData$CDC_CCDC_Gozar_Name == "Inzar Paila Village","CDC_CCDC_Gozar_Name"] = "Inzar Paila"
infraData[infraData$CDC_CCDC_Gozar_Name == "Yatim Bala","CDC_CCDC_Gozar_Name"] = "Yatim E Bala"
infraData[infraData$CDC_CCDC_Gozar_Name == "Asadullah Hazar Asp","CDC_CCDC_Gozar_Name"] = "Assadullah Hazar Asp"


##### for village_name and column ##### 
#changing data type from null to string
infraData$Village_Cdc_Name = as.character(infraData$Village_Cdc_Name)
infraData$CDC_CCDC_Gozar_ID = as.character(infraData$CDC_CCDC_Gozar_ID)
for (i in 1:nrow(infraData)){
  infraData[i,"Village_Cdc_Name"] = infraData[i,"CDC_CCDC_Gozar_Name"]
  infraData[i,"CDC_CCDC_Gozar_ID"] = infraData[i,"Line_Ministry_Project_Id"]
}
#changing the datatype of the financial value column
infraData$Sub_Project_Financial_Value_In_Afn = as.integer(infraData$Sub_Project_Financial_Value_In_Afn)


##### Fixing Dates ##### ####
# #to verify date formats
View(infraData[grep("date|time|start|end", names(infraData), ignore.case = T, value = T)])

##### to compare data with Sample Sheet ####
infraColumns = c("Site_Visit_Id",
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
inconRows = checkColumnsInTabs(unique(infraData[infraColumns]), sampleData[sampleColumns])
# to extract only the column names that have problem
cols <- inconRows$Inconsistent_Column_Name %>%
  str_split(pattern = " - ") %>%
  unlist() %>% 
  append(c("Site_Visit_Id", "Line_Ministry_SubProject_Id"), .) %>%
  append("Inconsistent_Column_Name") %>% 
  unique()
#extracting the data for those cols
inconData <- inconRows[cols]
write.xlsx(inconData, "output/inconsistent_data/EQRA_March_Infra_InconsistentData.xlsx")

#######to ensure data consistency for each tab #####
#there are no TPMA code in other tabs of this dataset

##### Checking Duplicates ##### 
#to compare the TPMA codes with the social data
##leave it when both data are cleaned and finalized

#for surveyor name
checkDuplicates(infraData, c("Surveyor_Name", "Surveyor_Id", "Surveyor_Gender"), F)

#for id
checkDuplicates(infraData, c("Site_Visit_Id", "Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id", "Type_Of_Site_Visit", "Type_Of_Visit"), F)

#for minitry project ID
checkDuplicates(infraData, c("Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id"), F)

checkDuplicates(infraData, c("Line_Ministry_Project_Id","Province", "District", "Village_Cdc_Name", "CDC_CCDC_Gozar_Name", "CDC_CCDC_Gozar_ID", "Line_Ministry_Name"), F)

#for subproject ID
#** "Type_Of_Implementing_Partner" doesnt exist in this dataset
vec = c("Line_Ministry_SubProject_Id", "Line_Ministry_Sub_Project_Name_And_Description", "Sub_Project_Financial_Value_In_Afn", "School_Id", "Name_of_Contractor_Facilitating_Partner", "Contractor_License_number_Facilitating_Partner_Registration_Number")
checkDuplicates(infraData, vec, show<-F)

#for contractor facilitating partner
checkDuplicates(infraData, c("Name_of_Contractor_Facilitating_Partner", "Contractor_License_number_Facilitating_Partner_Registration_Number"), show<-F)

##### Creating Log ####
col_vec <- c("Line_Ministry_Project_Id", "Line_Ministry_SubProject_Id", "Line_Ministry_Name", "Line_Ministry_Sub_Project_Name_And_Description", "Type_Of_Visit", 
             "Type_Of_Site_Visit", "Surveyor_Name", "Surveyor_Id", "Surveyor_Gender", "Province", "District", "CDC_CCDC_Gozar_Name", "Village_Cdc_Name", "CDC_CCDC_Gozar_ID",
             "created_at", "updated_at","system_created_at")
log <- create_log(raw_data, infraData, col_vec, "fulcrum_id")


##### Exporting Datasets *fix the names before exporting##### 
#main data
listOfDatasets = list("eqra_3_1"=infraData)
write.xlsx(listOfDatasets, file = "output/cleaned_data/EQRA_Infrastructure_CLEANED_DataSet_200408.xlsx")

#Additional useful data 
listOfDatasets = list("eqra_3_1" = log)
write.xlsx(listOfDatasets, file = "output/cleaning_log_for_March_infra.xlsx")
