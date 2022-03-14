[CmdletBinding()]
Param(

    [string]$ExcelPath,
    [string]$InventoryPath

)
Function New-ExcelObject {
    [CmdletBinding()]
    Param(
        [Switch]$Visible
    )

    $ExcelObject = New-Object -ComObject Excel.Application
    $ExcelObject.Visible = $Visible
    $ExcelObject
}
Function new-ExcelWorkbook {
    Param(
        $ExcelObject,
        $WorkbookName
    )
    
}
Function Add-ExcelSheet {
    [CmdletBinding()]
    Param(
        $ExcelObject,
        $SheetName,
        $Titles
    )

}

$ExcelObject = New-ExcelObject -Visible 

Read-Host