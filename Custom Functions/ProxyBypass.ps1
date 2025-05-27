$envChoice = [System.Management.Automation.Host.ChoiceDescription[]](@(
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Staging", "Staging environment")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Prod", "Production environment"))
))
$actionChoice = [System.Management.Automation.Host.ChoiceDescription[]](@(
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Foo", "foo")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Bar", "bar"))
))
$environment = $Host.Ui.PromptForChoice("Environment", "Choose the target environment", $envChoice, 0)
$action = $Host.Ui.PromptForChoice("Action", "Select action to perform", $actionChoice, 0)

$dateFormat = "yyyy-MM-dd HH:mm:ss"
$schedule = [String]::Empty
$schedTime = [DateTime]::MinValue
[System.Globalization.CultureInfo]$provider = [System.Globalization.CultureInfo]::InvariantCulture
while (-not [DateTime]::TryParseExact($schedule, $dateFormat, $provider, [System.Globalization.DateTimeStyles]::None, [ref]$schedTime)) {
    Write-Output ("Schedule or leave blank to schedule now ({0}):" -f $dateFormat.ToLower())
    $schedule = Read-Host
    if ([String]::IsNullOrEmpty($schedule)) {
        $schedule = [DateTime]::Now.ToString($dateFormat)
    }
}

Write-Output "Note (leave blank to skip):"
$note = Read-Host

$confirmChoice = [System.Management.Automation.Host.ChoiceDescription[]](@(
    (New-Object System.Management.Automation.Host.ChoiceDescription("&Yes","Confirm")),
    (New-Object System.Management.Automation.Host.ChoiceDescription("&No","Cancel"))
))
$answer = $Host.Ui.PromptForChoice((@"
Plan of action:
  >> Sending action to: {0}
  >> Scheduling a action of: {1}
  >> Schedule date: {2:yyyy-MM-dd HH:mm:ss}
  >> Notes: {3}
"@ -f $envChoice[$environment].Label.Replace("&",""),$actionChoice[$action].Label.Replace("&",""),$schedTime,$note),"Ok to proceed?",$confirmChoice,0)

Switch ($answer){
    0 {"Should proceed"; break}
    1 {"Cancelled"; break}
}