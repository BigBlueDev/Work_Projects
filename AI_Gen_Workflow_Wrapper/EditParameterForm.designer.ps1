#EditParameterForm.designer.ps1

[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')

$EditParameterForm = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.ComboBox]$cboType = $null
[System.Windows.Forms.Label]$lblName = $null
[System.Windows.Forms.Label]$lblValue = $null
[System.Windows.Forms.TextBox]$txtValue = $null
[System.Windows.Forms.GroupBox]$grpSpecialOptions = $null
[System.Windows.Forms.Button]$btnOK = $null
[System.Windows.Forms.Button]$btnCancel = $null
[System.Windows.Forms.Label]$lblType = $null
[System.Windows.Forms.TextBox]$txtName = $null

function InitializeComponent {
    $cboType = (New-Object -TypeName System.Windows.Forms.ComboBox)
    $lblName = (New-Object -TypeName System.Windows.Forms.Label)
    $lblValue = (New-Object -TypeName System.Windows.Forms.Label)
    $txtValue = (New-Object -TypeName System.Windows.Forms.TextBox)
    $txtName = (New-Object -TypeName System.Windows.Forms.TextBox)
    $grpSpecialOptions = (New-Object -TypeName System.Windows.Forms.GroupBox)
    $btnOK = (New-Object -TypeName System.Windows.Forms.Button)
    $btnCancel = (New-Object -TypeName System.Windows.Forms.Button)
    $lblType = (New-Object -TypeName System.Windows.Forms.Label)

    $EditParameterForm.SuspendLayout()

    #region Control Properties

    # cboType
    $cboType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cboType.FormattingEnabled = $true
    $cboType.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]83, [System.Int32]169))
    $cboType.Name = [System.String]'cboType'
    $cboType.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]121, [System.Int32]21))
    $cboType.TabIndex = [System.Int32]0
    

    # lblName
    $lblName.AutoSize = $true
    $lblName.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12, [System.Int32]20))
    $lblName.Name = [System.String]'lblName'
    $lblName.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]38, [System.Int32]13))
    $lblName.TabIndex = [System.Int32]1
    $lblName.Text = [System.String]'Name:'

    # lblValue
    $lblValue.AutoSize = $true
    $lblValue.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]26, [System.Int32]122))
    $lblValue.Name = [System.String]'lblValue'
    $lblValue.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]37, [System.Int32]13))
    $lblValue.TabIndex = [System.Int32]2
    $lblValue.Text = [System.String]'Value:'

    # txtValue
    $txtValue.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]83, [System.Int32]119))
    $txtValue.Name = [System.String]'txtValue'
    $txtValue.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100, [System.Int32]20))
    $txtValue.TabIndex = [System.Int32]3

    # txtName
    $txtName.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]100, [System.Int32]18))
    $txtName.Name = [System.String]'txtName'
    $txtName.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]280, [System.Int32]20))
    $txtName.TabIndex = [System.Int32]4

    # grpSpecialOptions
    $grpSpecialOptions.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29, [System.Int32]205))
    $grpSpecialOptions.Name = [System.String]'grpSpecialOptions'
    $grpSpecialOptions.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]330, [System.Int32]152))
    $grpSpecialOptions.TabIndex = [System.Int32]5
    $grpSpecialOptions.TabStop = $false
    $grpSpecialOptions.Text = [System.String]'Special Options'

    # btnOK
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnOK.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]388, [System.Int32]223))
    $btnOK.Name = [System.String]'btnOK'
    $btnOK.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]77, [System.Int32]33))
    $btnOK.TabIndex = [System.Int32]6
    $btnOK.Text = [System.String]'&OK'
    $btnOK.UseVisualStyleBackColor = $true

    # btnCancel
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $btnCancel.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]388, [System.Int32]308))
    $btnCancel.Name = [System.String]'btnCancel'
    $btnCancel.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]75, [System.Int32]23))
    $btnCancel.TabIndex = [System.Int32]7
    $btnCancel.Text = [System.String]'&Cancel'
    $btnCancel.UseVisualStyleBackColor = $true

    # lblType
    $lblType.AutoSize = $true
    $lblType.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29, [System.Int32]169))
    $lblType.Name = [System.String]'lblType'
    $lblType.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]34, [System.Int32]13))
    $lblType.TabIndex = [System.Int32]8
    $lblType.Text = [System.String]'Type:'

    #endregion Control Properties

    #region Form Properties

    # EditParameterForm
    $EditParameterForm.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]477, [System.Int32]369))
    $EditParameterForm.Controls.Add($lblType)
    $EditParameterForm.Controls.Add($btnCancel)
    $EditParameterForm.Controls.Add($btnOK)
    $EditParameterForm.Controls.Add($grpSpecialOptions)
    $EditParameterForm.Controls.Add($txtName)
    $EditParameterForm.Controls.Add($txtValue)
    $EditParameterForm.Controls.Add($lblValue)
    $EditParameterForm.Controls.Add($lblName)
    $EditParameterForm.Controls.Add($cboType)
    $EditParameterForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $EditParameterForm.Name = [System.String]'EditParameterForm'
    $EditParameterForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $EditParameterForm.Text = [System.String]'Edit Parameter'
    $EditParameterForm.TopMost = $true

    #endregion Form Properties

    $EditParameterForm.ResumeLayout($false)
    $EditParameterForm.PerformLayout()

    # Add event handlers (defined in EditParameterForm.ps1)
    $cboType.add_SelectedIndexChanged($cboType_SelectedIndexChanged)
    $txtValue.add_TextChanged($txtValue_TextChanged)
    $txtName.add_TextChanged($txtName_TextChanged)
    $grpSpecialOptions.add_Enter($grpSpecialOptions_Enter)
    $btnOK.add_Click($btnOK_Click)
    $btnCancel.add_Click($btnCancel_Click)
    $EditParameterForm.add_Load($EditParameterForm_Load)

    # Add the controls as properties to the form
    Add-Member -InputObject $EditParameterForm -Name cboType -Value $cboType -MemberType NoteProperty
    Add-Member -InputObject $EditParameterForm -Name lblName -Value $lblName -MemberType NoteProperty
    Add-Member -InputObject $EditParameterForm -Name lblValue -Value $lblValue -MemberType NoteProperty
    Add-Member -InputObject $EditParameterForm -Name txtValue -Value $txtValue -MemberType NoteProperty
    Add-Member -InputObject $EditParameterForm -Name grpSpecialOptions -Value $grpSpecialOptions -MemberType NoteProperty
    Add-Member -InputObject $EditParameterForm -Name btnOK -Value $btnOK -MemberType NoteProperty
    Add-Member -InputObject $EditParameterForm -Name btnCancel -Value $btnCancel -MemberType NoteProperty
    Add-Member -InputObject $EditParameterForm -Name lblType -Value $lblType -MemberType NoteProperty
    Add-Member -InputObject $EditParameterForm -Name txtName -Value $txtName -MemberType NoteProperty
}
. InitializeComponent