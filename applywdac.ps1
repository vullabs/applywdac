<#
   .SYNOPSIS
   Applies a WDAC XML policy file to a Windows system

   .DESCRIPTION
   This script will apply a WDAC XML policy file to a Windows system.
   Support is provided for both Multiple Policy Format files
   as well as legacy single-policy files.

   .PARAMETER xmlpolicy
   Specifies the WDAC XML Policy file

   .PARAMETER enforce
   Flag to specify that the policy is to be enforced, rather than audited.

   .EXAMPLE
   PS> .\applywdac.ps1 -xmlpolicy driverblocklist.xml -enforce
   Apply the WDAC policy contained in driverblocklist.xml in enforcing mode

   .EXAMPLE
   PS> .\applywdac.ps1 -xmlpolicy driverblocklist.xml
   Apply the WDAC policy contained in driverblocklist.xml in audit-only mode

#>

Param([string]$xmlpolicy, [switch]$enforce)

if($xmlpolicy -eq "") {
   Get-Help $MyInvocation.MyCommand.Definition
   return
}

$xmlpolicy = (Resolve-Path "$XmlPolicy")

[xml]$Xml = Get-Content "$xmlpolicy"
If( $xml.SiPolicy.PolicyTypeID ) {
 Write-Host "Legacy XML format detected"
 If ([System.Environment]::OSVersion.Version.Build -eq 14393) {
     # Windows 1607 doesn't understand the MaximumFileVersion attribute.  Remove it.
     $xml.SiPolicy.Filerules.ChildNodes | ForEach-Object -MemberName RemoveAttribute("MaximumFileVersion")
       $xml.Save((Resolve-Path "$xmlpolicy"))
 }
 If ([System.Environment]::OSVersion.Version.Build -le 18362.900) {
   # Install on system that doesn't support multi-policy
       if ($enforce){
       Set-RuleOption -FilePath "$xmlpolicy" -Option 3 -Delete
       }
       else{
           Write-warning "This policy is being deployed in audit mode. Rules will not be enforced!"
       }
   ConvertFrom-CIPolicy -xmlFilePath "$xmlpolicy" -BinaryFilePath ".\SiPolicy.p7b"
   $PolicyBinary = ".\SIPolicy.p7b"
   $DestinationBinary = $env:windir+"\System32\CodeIntegrity\SiPolicy.p7b"
   Copy-Item  -Path $PolicyBinary -Destination $DestinationBinary -Force
   Invoke-CimMethod -Namespace root\Microsoft\Windows\CI -ClassName PS_UpdateAndCompareCIPolicy -MethodName Update -Arguments @{FilePath = $DestinationBinary}
 }
 else {
   # Install on system that does support multi-policy
   [xml]$Xml = Get-Content $xmlpolicy
   $policytypeid = $xml.SiPolicy.PolicyTypeID
       if ($enforce){
       Set-RuleOption -FilePath "$xmlpolicy" -Option 3 -Delete
       }
       else{
           Write-warning "This policy is being deployed in audit mode. Rules will not be enforced!"
       }
   ConvertFrom-CIPolicy -xmlFilePath "$xmlpolicy" -BinaryFilePath ".\$policytypeid.cip"
   $PolicyBinary = ".\$policytypeid.cip"
   $DestinationFolder = $env:windir+"\System32\CodeIntegrity\CIPolicies\Active\"
   Copy-Item -Path $PolicyBinary -Destination $DestinationFolder -Force
 }
} ElseIf ( $xml.SiPolicy.PolicyID ) {
 Write-Host "Multiple Policy Format XML detected"
 If ([System.Environment]::OSVersion.Version.Build -le 18362.900) {
       Write-Error "This version of Windows does not support Multiple Policy Format XML files"
 }
 else {
   # Install on system that does support multi-policy
   [xml]$Xml = Get-Content $xmlpolicy
   $policytypeid = $xml.SiPolicy.PolicyID
       if ($enforce) {
       Set-RuleOption -FilePath "$xmlpolicy" -Option 3 -Delete
       }
       else{
           Write-warning "This policy is being deployed in audit mode. Rules will not be enforced!"
       }
   ConvertFrom-CIPolicy -xmlFilePath "$xmlpolicy" -BinaryFilePath ".\$policytypeid.cip"
   $PolicyBinary = ".\$policytypeid.cip"
   $DestinationFolder = $env:windir+"\System32\CodeIntegrity\CIPolicies\Active\"
   Copy-Item -Path $PolicyBinary -Destination $DestinationFolder -Force
 }
} Else {
 Write-Error "Cannot determine XML format."
}