
### Import data libraries

library(RODBC)
library(dplyr)
library(methods)
library(lubridate)
library(stringr)
library(tidyr)
library(xlsx)

### Read in data that in csv format
On_Call_Segments<-read.csv('h:/On Call Segments.csv')

options(stringsAsFactors=FALSE, xlsx.datetime.format="d MMM yyyy")

options(
  
  RDS.path="S:/RDS",
  JSON.path="S:/Active_Reports/JSON"
)

### create read in json file function

tableFromErsiJSON <- function (file, text, use.aliases=FALSE) {
  if (missing(file) && !missing(text)) {
    d <- jsonlite::fromJSON(text)
  } else {
    if (!grepl("\\.JSON$", file, ignore.case=TRUE)) file <- paste(file, "JSON", sep=".")
    wd <- getwd()
    setwd(getOption("JSON.path"))
    if (!file.exists(file)) stop(sprintf("cannot open file '%s': No such file or directory", file))
    d <- jsonlite::fromJSON(file)			
    setwd(wd)
  }		
  fields <- d$fields
  d <- d$features$attributes		
  if (use.aliases) colnames(d) <- fields$alias		
  for (i in which(fields$type == "esriFieldTypeDate")) d[, i] <- as.Date(as.POSIXct(d[, i] / 1000, origin="1970-01-01"))		
  d
}

###USE tableFromErsiJSON function to read in data that in JSON file
MH_INSP<-tableFromErsiJSON("SEWERCAP.MH_INSP")

########CITYWORKDATABASE
dbhandle <- odbcDriverConnect("driver={SQL Server};server=sql1601p\\####;database=#####;trusted_connection=true")
                                                               
PROJECT <-sqlQuery(dbhandle, "SELECT a.WORKORDERID,b.ENTITYUID FACILITYID, a.DESCRIPTION, a.PROJECTNAME, a.ACTUALFINISHDATE, a.STATUS  FROM AZTECA.WORKORDER A
 LEFT JOIN AZTECA.WORKORDERENTITY B
ON A.WORKORDERID = B.WORKORDERID
WHERE a.PROJECTNAME LIKE '%FY21%'")
close <- odbcClose(dbhandle)                                                                                                   
                                                                                                  
##### Merge data from multiple data soure                                                                                                   
D20<-MH_INSP%>%left_join(PROJECT,by='FACILITYID')


### Reset excel Report format
wb<-createWorkbook(type="xlsx")

TITLE_STYLE <- CellStyle(wb)+ Font(wb,  heightInPoints=16, color="blue", isBold=TRUE, underline=1)
SUB_TITLE_STYLE <- CellStyle(wb) + 
  Font(wb,  heightInPoints=14,
       isItalic=TRUE, isBold=FALSE)

TABLE_ROWNAMES_STYLE <- CellStyle(wb) + Font(wb, isBold=TRUE)
TABLE_COLNAMES_STYLE <- CellStyle(wb) + Font(wb, isBold=TRUE) +
  Alignment(wrapText=TRUE, horizontal="ALIGN_CENTER") +
  Border(color="black", position=c("TOP", "BOTTOM"), 
         pen=c("BORDER_THIN", "BORDER_THICK")) 

sheet <- createSheet(wb, sheetName = "MH REPORT")

xlsx.addTitle<-function(sheet, rowIndex, title, titleStyle){
  rows <-createRow(sheet,rowIndex=rowIndex)
  sheetTitle <-createCell(rows, colIndex=1)
  setCellValue(sheetTitle[[1,1]], title)
  setCellStyle(sheetTitle[[1,1]], titleStyle)
}

xlsx.addTitle(sheet, rowIndex=1, title="MH REPORT",
              titleStyle = TITLE_STYLE)

xlsx.addTitle(sheet, rowIndex=2, 
              title="Data Source: MH_INSP Layer and Citywork Database.",
              titleStyle = SUB_TITLE_STYLE)

addDataFrame(D20, sheet, startRow=3, startColumn=1, 
             colnamesStyle = TABLE_COLNAMES_STYLE,
             rownamesStyle = TABLE_ROWNAMES_STYLE)

setColumnWidth(sheet, colIndex=c(1:ncol(D20)), colWidth=15)

#### Export data into the beautified excel format
saveWorkbook(wb, "S:/DPW/Shared/Reports/Utilities/Manhole_Inspections/MHREPORT_0412.xlsx")                                                          
