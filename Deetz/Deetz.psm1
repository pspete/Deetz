#region Loader
<#
.SYNOPSIS

.DESCRIPTION

.EXAMPLE

.INPUTS

.OUTPUTS
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DotSourceModule', Justification = 'Used within the ForEach-Object script block')]
[CmdletBinding()]
param(

	[bool]$DotSourceModule = $false

)

#Get function files
Get-ChildItem $PSScriptRoot\ -Recurse -Include '*.ps1' -Exclude '*.ps1xml' |

	ForEach-Object {

		if ($DotSourceModule) {
			. $_.FullName
		} else {
			$ExecutionContext.InvokeCommand.InvokeScript(
				$false,
				(
					[scriptblock]::Create(
						[io.file]::ReadAllText(
							$_.FullName,
							[Text.Encoding]::UTF8
						)
					)
				),
				$null,
				$null
			)

		}

	}
#endregion Loader

# Script scope session object holding directory query state for the current discovery run
$Script:DeetzSession = [ordered]@{
	Credential = $null
	Cache      = @{}
} | Add-CustomType -Type Deetz.Session

New-Variable -Name DeetzSession -Value $Script:DeetzSession -Scope Script -Force
