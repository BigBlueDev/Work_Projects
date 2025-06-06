﻿# EditParam.ps1

$EditParameterForm_Load = {
    try {
        Write-Log "EditParameterForm_Load: Starting" -Level "DEBUG"
        
        # Access the passed parameters from the script scope
        $paramName = $script:Parameter.Name
        $paramValue = $script:Parameter.Value
        $paramType = $script:Parameter.Type
        
        Write-Log "EditParameterForm_Load: Parameter Name: $paramName, Value: $paramValue, Type: $paramType" -Level "DEBUG"
        
        # Set the initial values in the form's controls
        $this.txtName.Text = $paramName
        $this.txtName.ReadOnly = $true
        $this.txtValue.Text = $paramValue
        
        # Set up the combo box
        if (-not $this.cboType.Items.Contains($paramType)) {
            $this.cboType.Items.Add($paramType)
        }
        $this.cboType.SelectedItem = $paramType
        
        # Update special options
        Write-Log "Calling Update-SpecialOptions from Load event" -Level "DEBUG"
        Update-SpecialOptions -config $script:Config
        
        Write-Log "EditParameterForm_Load: Completed" -Level "DEBUG"
    }
    catch {
        Write-Log "Error in EditParameterForm_Load: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    }
}



$btnOK_Click = {
    try {
        Write-Log "btnOK_Click: Starting" -Level "DEBUG"
        
        # Get the form reference correctly
        $form = $this.FindForm()
        if (-not $form) {
            Write-Log "Form reference not found" -Level "ERROR"
            return
        }
        
        # Get the updated values from the form's controls
        $updatedValue = $form.Controls['txtValue'].Text
        $updatedType = $form.Controls['cboType'].SelectedItem
        
        Write-Log "btnOK_Click: Updated Value: $updatedValue, Type: $updatedType" -Level "DEBUG"
        
        # Create the updated parameter
        $updatedParameter = [PSCustomObject]@{
            Name = $script:Parameter.Name
            Value = $updatedValue
            Type = $updatedType
            Description = $script:Parameter.Description
        }
        
        # Store the updated parameter in the form's Tag property
        $form.Tag = $updatedParameter
        
        Write-Log "Updated parameter stored in form Tag" -Level "DEBUG"
        
        # Set the DialogResult and close the form
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
        
        Write-Log "btnOK_Click: Completed" -Level "DEBUG"
    }
    catch {
        Write-Log "Error in btnOK_Click: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error in btnOK_Click: $($_.Exception.Message)", 
            "Error", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

$btnCancel_Click = {
    try {
        Write-Log "btnCancel_Click: Starting" -Level "DEBUG"
        
        # Get the form reference correctly
        $form = $this.FindForm()
        
        # Set the DialogResult to Cancel
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        
        # Close the form correctly
        $form.Close()
        
        Write-Log "btnCancel_Click: Completed" -Level "DEBUG"
    }
    catch {
        Write-Log "Error in btnCancel_Click: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    }
}

$cboType_SelectedIndexChanged = {
    try {
        Write-Log "cboType_SelectedIndexChanged: Starting" -Level "DEBUG"
        
        if ($script:Config -is [hashtable]) {
            Update-SpecialOptions -config $script:Config
        } else {
            Write-Log "Config is not a hashtable in SelectedIndexChanged" -Level "ERROR"
        }
        
        Write-Log "cboType_SelectedIndexChanged: Completed" -Level "DEBUG"
    }
    catch {
        Write-Log "Error in cboType_SelectedIndexChanged: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    }
}

# Event handler for the txtValue TextChanged
$txtValue_TextChanged = {
    try {
        Write-Log "txtValue_TextChanged: Starting" -Level "DEBUG"
        # Add validation logic here if needed
        Write-Log "txtValue_TextChanged: Completed" -Level "DEBUG"
    }
    catch {
        Write-Log "Error in txtValue_TextChanged: $($_.Exception.Message)" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Error in txtValue_TextChanged: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Special options section
function Update-SpecialOptions {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$config
    )
    
    try {
        Write-Log "Update-SpecialOptions: Starting" -Level "DEBUG"
        
        # Get form reference correctly
        $form = $this.FindForm()
        Write-Log "Form reference obtained: $($null -ne $form)" -Level "DEBUG"

        # Get the controls
        $grpSpecialOptions = $form.Controls['grpSpecialOptions']
        $txtValue = $form.Controls['txtValue']
        $cboType = $form.Controls['cboType']
        
        Write-Log "Controls found - GroupBox: $($null -ne $grpSpecialOptions), TextBox: $($null -ne $txtValue), ComboBox: $($null -ne $cboType)" -Level "DEBUG"
        
        # Verify controls exist
        if (-not $grpSpecialOptions -or -not $txtValue -or -not $cboType) {
            Write-Log "Required controls are missing" -Level "ERROR"
            return
        }

        # Access the parameter name and type
        $paramName = $script:Parameter.Name
        $currentType = $cboType.SelectedItem
        
        Write-Log "Parameter Info - Name: $paramName, Type: $currentType" -Level "DEBUG"

        # Clear existing controls
        $grpSpecialOptions.Controls.Clear()
        Write-Log "Cleared existing controls from GroupBox" -Level "DEBUG"

        $yPos = 25
        $optionSpacing = 35
        $hasSpecialOptions = $false

        # Special handling for vCenter server names or any string parameters that might use vCenter names
        if ($currentType -eq "String" -and 
            ($paramName -eq "vCenter" -or 
             $paramName -like "*vCenterServer*" -or 
             $paramName -like "*Server*" -or 
             $paramName -like "*vCenter*")) {

            Write-Log "Adding vCenter server options" -Level "DEBUG"

            # Add section label
            $lblServerSection = New-Object System.Windows.Forms.Label
            $lblServerSection.Location = New-Object System.Drawing.Point(10, $yPos)
            $lblServerSection.Size = New-Object System.Drawing.Size(380, 20)
            $lblServerSection.Text = "vCenter Server Options:"
            $lblServerSection.Font = New-Object System.Drawing.Font($lblServerSection.Font, [System.Drawing.FontStyle]::Bold)
            $grpSpecialOptions.Controls.Add($lblServerSection)
            Write-Log "Added section label" -Level "DEBUG"
            
            $yPos += 25

            # Source vCenter Server option
            $rbSourceServer = New-Object System.Windows.Forms.RadioButton
            $rbSourceServer.Location = New-Object System.Drawing.Point(20, $yPos)
            $rbSourceServer.Size = New-Object System.Drawing.Size(180, 24)
            $rbSourceServer.Text = "Use Source vCenter"
            $rbSourceServer.Checked = ($txtValue.Text -eq "SourcevCenter")
            $rbSourceServer.Add_Click({
                $form = $this.FindForm()
                $form.Controls['txtValue'].Text = "SourcevCenter"
            })
            $grpSpecialOptions.Controls.Add($rbSourceServer)
            Write-Log "Added Source vCenter radio button" -Level "DEBUG"

            # Target vCenter Server option
            $rbTargetServer = New-Object System.Windows.Forms.RadioButton
            $rbTargetServer.Location = New-Object System.Drawing.Point(210, $yPos)
            $rbTargetServer.Size = New-Object System.Drawing.Size(180, 24)
            $rbTargetServer.Text = "Use Target vCenter"
            $rbTargetServer.Checked = ($txtValue.Text -eq "TargetvCenter")
            $rbTargetServer.Add_Click({
                $form = $this.FindForm()
                $form.Controls['txtValue'].Text = "TargetvCenter"
            })
            $grpSpecialOptions.Controls.Add($rbTargetServer)
            Write-Log "Added Target vCenter radio button" -Level "DEBUG"

            $yPos += $optionSpacing
            $hasSpecialOptions = $true
        }

        # Special handling for credentials
        if ($currentType -eq "PSCredential") {
            Write-Log "Adding credential options" -Level "DEBUG"

            $rbSourceCred = New-Object System.Windows.Forms.RadioButton
            $rbSourceCred.Location = New-Object System.Drawing.Point(20, $yPos)
            $rbSourceCred.Size = New-Object System.Drawing.Size(180, 24)
            $rbSourceCred.Text = "Use Source Credentials"
            $rbSourceCred.Checked = ($txtValue.Text -eq "SourceCredential")
            $rbSourceCred.Add_Click({
                $form = $this.FindForm()
                $form.Controls['txtValue'].Text = "SourceCredential"
            })
            $grpSpecialOptions.Controls.Add($rbSourceCred)

            $rbTargetCred = New-Object System.Windows.Forms.RadioButton
            $rbTargetCred.Location = New-Object System.Drawing.Point(210, $yPos)
            $rbTargetCred.Size = New-Object System.Drawing.Size(180, 24)
            $rbTargetCred.Text = "Use Target Credentials"
            $rbTargetCred.Checked = ($txtValue.Text -eq "TargetCredential")
            $rbTargetCred.Add_Click({
                $form = $this.FindForm()
                $form.Controls['txtValue'].Text = "TargetCredential"
            })
            $grpSpecialOptions.Controls.Add($rbTargetCred)

            $yPos += $optionSpacing
            $hasSpecialOptions = $true
            Write-Log "Added credential options" -Level "DEBUG"
        }

        # Update group box visibility and size
        if ($hasSpecialOptions) {
            $grpSpecialOptions.Height = [Math]::Max($yPos + 15, 100)
            $grpSpecialOptions.Visible = $true
            Write-Log "Special options box visible, height set to: $($grpSpecialOptions.Height)" -Level "DEBUG"
        } else {
            $grpSpecialOptions.Visible = $false
            Write-Log "No special options added, group box hidden" -Level "DEBUG"
        }

        # Force refresh
        $grpSpecialOptions.Refresh()
        $form.Refresh()

        Write-Log "Update-SpecialOptions: Completed successfully" -Level "DEBUG"
    }
    catch {
        Write-Log "Error in Update-SpecialOptions: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    }
}



# Unused event handlers
$txtName_TextChanged = {}
$grpSpecialOptions_Enter = {}



