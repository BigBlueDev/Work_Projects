[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
$mainForm = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.TabControl]$tabControl = $null
[System.Windows.Forms.TabPage]$tabConnection = $null
[System.Windows.Forms.TabPage]$tabScripts = $null
[System.Windows.Forms.TabPage]$tabExecution = $null
[System.Windows.Forms.TabPage]$tabLogs = $null
[System.Windows.Forms.GroupBox]$grpSource = $null
[System.Windows.Forms.Label]$lblSourceServer = $null
[System.Windows.Forms.TextBox]$txtSourceServer = $null
[System.Windows.Forms.Label]$lblSourceUsername = $null
[System.Windows.Forms.TextBox]$txtSourceUsername = $null
[System.Windows.Forms.Label]$lblSourcePassword = $null
[System.Windows.Forms.TextBox]$txtSourcePassword = $null
[System.Windows.Forms.Button]$btnTestSourceConnection = $null
[System.Windows.Forms.GroupBox]$grpTarget = $null
[System.Windows.Forms.Label]$lblTargetServer = $null
[System.Windows.Forms.TextBox]$txtTargetServer = $null
[System.Windows.Forms.Label]$lblTargetUsername = $null
[System.Windows.Forms.TextBox]$txtTargetUsername = $null
[System.Windows.Forms.Label]$lblTargetPassword = $null
[System.Windows.Forms.TextBox]$txtTargetPassword = $null
[System.Windows.Forms.Button]$btnTestTargetConnection = $null
[System.Windows.Forms.CheckBox]$chkUseCurrentCredentials = $null
[System.Windows.Forms.Button]$btnSaveConnection = $null
[System.Windows.Forms.Button]$btnLoadConnection = $null
[System.Windows.Forms.GroupBox]$grpScriptsList = $null
[System.Windows.Forms.ListView]$lvScripts = $null
[System.Windows.Forms.Button]$btnAddScript = $null
[System.Windows.Forms.Button]$btnRemoveScript = $null
[System.Windows.Forms.Button]$btnMoveUp = $null
[System.Windows.Forms.Button]$btnMoveDown = $null
[System.Windows.Forms.GroupBox]$grpScriptDetails = $null
[System.Windows.Forms.Label]$lblScriptPath = $null
[System.Windows.Forms.TextBox]$txtScriptPath = $null
[System.Windows.Forms.Button]$btnBrowse = $null
[System.Windows.Forms.Label]$lblScriptDescription = $null
[System.Windows.Forms.TextBox]$txtScriptDescription = $null
[System.Windows.Forms.CheckBox]$chkScriptEnabled = $null
[System.Windows.Forms.GroupBox]$grpParameters = $null
[System.Windows.Forms.ListView]$lvParameters = $null
[System.Windows.Forms.Button]$btnAddParam = $null
[System.Windows.Forms.Button]$btnEditParam = $null
[System.Windows.Forms.Button]$btnRemoveParam = $null
[System.Windows.Forms.Button]$btnDetectParams = $null
[System.Windows.Forms.Button]$btnSaveScriptDetails = $null
[System.Windows.Forms.GroupBox]$grpExecutionSettings = $null
[System.Windows.Forms.CheckBox]$chkStopOnError = $null
[System.Windows.Forms.CheckBox]$chkSkipConfirmation = $null
[System.Windows.Forms.Label]$lblTimeout = $null
[System.Windows.Forms.NumericUpDown]$numTimeout = $null
[System.Windows.Forms.Label]$lblMaxJobs = $null
[System.Windows.Forms.NumericUpDown]$numMaxJobs = $null
[System.Windows.Forms.GroupBox]$grpExecutionControls = $null
[System.Windows.Forms.Button]$btnRunAll = $null
[System.Windows.Forms.Button]$btnRunSelected = $null
[System.Windows.Forms.Button]$btnStopExecution = $null
[System.Windows.Forms.GroupBox]$grpProgress = $null
[System.Windows.Forms.Label]$lblOverallProgress = $null
[System.Windows.Forms.ProgressBar]$progressOverall = $null
[System.Windows.Forms.Label]$lblCurrentProgress = $null
[System.Windows.Forms.ProgressBar]$progressCurrentScript = $null
[System.Windows.Forms.GroupBox]$grpOutput = $null
[System.Windows.Forms.TextBox]$txtExecutionOutput = $null
[System.Windows.Forms.GroupBox]$grpLogs = $null
[System.Windows.Forms.TextBox]$logTextBox = $null
[System.Windows.Forms.Button]$btnRefreshLogs = $null
[System.Windows.Forms.Button]$btnClearLogs = $null
[System.Windows.Forms.Button]$btnExportLogs = $null
[System.Windows.Forms.StatusStrip]$statusStrip = $null
[System.Windows.Forms.ToolStripStatusLabel]$statusStripLabel = $null
[System.Windows.Forms.Panel]$pnlBottom = $null
[System.Windows.Forms.Button]$btnSaveAll = $null
[System.Windows.Forms.Button]$btnExit = $null
[System.Windows.Forms.OpenFileDialog]$openFileDialog1 = $null
[System.Windows.Forms.Button]$btnHelp = $null
function InitializeComponent
{
$tabControl = (New-Object -TypeName System.Windows.Forms.TabControl)
$tabConnection = (New-Object -TypeName System.Windows.Forms.TabPage)
$grpSource = (New-Object -TypeName System.Windows.Forms.GroupBox)
$lblSourceServer = (New-Object -TypeName System.Windows.Forms.Label)
$txtSourceServer = (New-Object -TypeName System.Windows.Forms.TextBox)
$lblSourceUsername = (New-Object -TypeName System.Windows.Forms.Label)
$txtSourceUsername = (New-Object -TypeName System.Windows.Forms.TextBox)
$lblSourcePassword = (New-Object -TypeName System.Windows.Forms.Label)
$txtSourcePassword = (New-Object -TypeName System.Windows.Forms.TextBox)
$btnTestSourceConnection = (New-Object -TypeName System.Windows.Forms.Button)
$grpTarget = (New-Object -TypeName System.Windows.Forms.GroupBox)
$lblTargetServer = (New-Object -TypeName System.Windows.Forms.Label)
$txtTargetServer = (New-Object -TypeName System.Windows.Forms.TextBox)
$lblTargetUsername = (New-Object -TypeName System.Windows.Forms.Label)
$txtTargetUsername = (New-Object -TypeName System.Windows.Forms.TextBox)
$lblTargetPassword = (New-Object -TypeName System.Windows.Forms.Label)
$txtTargetPassword = (New-Object -TypeName System.Windows.Forms.TextBox)
$btnTestTargetConnection = (New-Object -TypeName System.Windows.Forms.Button)
$chkUseCurrentCredentials = (New-Object -TypeName System.Windows.Forms.CheckBox)
$btnSaveConnection = (New-Object -TypeName System.Windows.Forms.Button)
$btnLoadConnection = (New-Object -TypeName System.Windows.Forms.Button)
$tabScripts = (New-Object -TypeName System.Windows.Forms.TabPage)
$grpScriptsList = (New-Object -TypeName System.Windows.Forms.GroupBox)
$lvScripts = (New-Object -TypeName System.Windows.Forms.ListView)
$btnAddScript = (New-Object -TypeName System.Windows.Forms.Button)
$btnRemoveScript = (New-Object -TypeName System.Windows.Forms.Button)
$btnMoveUp = (New-Object -TypeName System.Windows.Forms.Button)
$btnMoveDown = (New-Object -TypeName System.Windows.Forms.Button)
$grpScriptDetails = (New-Object -TypeName System.Windows.Forms.GroupBox)
$lblScriptPath = (New-Object -TypeName System.Windows.Forms.Label)
$txtScriptPath = (New-Object -TypeName System.Windows.Forms.TextBox)
$btnBrowse = (New-Object -TypeName System.Windows.Forms.Button)
$lblScriptDescription = (New-Object -TypeName System.Windows.Forms.Label)
$txtScriptDescription = (New-Object -TypeName System.Windows.Forms.TextBox)
$chkScriptEnabled = (New-Object -TypeName System.Windows.Forms.CheckBox)
$grpParameters = (New-Object -TypeName System.Windows.Forms.GroupBox)
$lvParameters = (New-Object -TypeName System.Windows.Forms.ListView)
$btnAddParam = (New-Object -TypeName System.Windows.Forms.Button)
$btnEditParam = (New-Object -TypeName System.Windows.Forms.Button)
$btnRemoveParam = (New-Object -TypeName System.Windows.Forms.Button)
$btnDetectParams = (New-Object -TypeName System.Windows.Forms.Button)
$btnSaveScriptDetails = (New-Object -TypeName System.Windows.Forms.Button)
$tabExecution = (New-Object -TypeName System.Windows.Forms.TabPage)
$grpExecutionSettings = (New-Object -TypeName System.Windows.Forms.GroupBox)
$chkStopOnError = (New-Object -TypeName System.Windows.Forms.CheckBox)
$chkSkipConfirmation = (New-Object -TypeName System.Windows.Forms.CheckBox)
$lblTimeout = (New-Object -TypeName System.Windows.Forms.Label)
$numTimeout = (New-Object -TypeName System.Windows.Forms.NumericUpDown)
$lblMaxJobs = (New-Object -TypeName System.Windows.Forms.Label)
$numMaxJobs = (New-Object -TypeName System.Windows.Forms.NumericUpDown)
$grpExecutionControls = (New-Object -TypeName System.Windows.Forms.GroupBox)
$btnRunAll = (New-Object -TypeName System.Windows.Forms.Button)
$btnRunSelected = (New-Object -TypeName System.Windows.Forms.Button)
$btnStopExecution = (New-Object -TypeName System.Windows.Forms.Button)
$grpProgress = (New-Object -TypeName System.Windows.Forms.GroupBox)
$lblOverallProgress = (New-Object -TypeName System.Windows.Forms.Label)
$progressOverall = (New-Object -TypeName System.Windows.Forms.ProgressBar)
$lblCurrentProgress = (New-Object -TypeName System.Windows.Forms.Label)
$progressCurrentScript = (New-Object -TypeName System.Windows.Forms.ProgressBar)
$grpOutput = (New-Object -TypeName System.Windows.Forms.GroupBox)
$txtExecutionOutput = (New-Object -TypeName System.Windows.Forms.TextBox)
$tabLogs = (New-Object -TypeName System.Windows.Forms.TabPage)
$grpLogs = (New-Object -TypeName System.Windows.Forms.GroupBox)
$logTextBox = (New-Object -TypeName System.Windows.Forms.TextBox)
$btnRefreshLogs = (New-Object -TypeName System.Windows.Forms.Button)
$btnClearLogs = (New-Object -TypeName System.Windows.Forms.Button)
$btnExportLogs = (New-Object -TypeName System.Windows.Forms.Button)
$statusStrip = (New-Object -TypeName System.Windows.Forms.StatusStrip)
$statusStripLabel = (New-Object -TypeName System.Windows.Forms.ToolStripStatusLabel)
$pnlBottom = (New-Object -TypeName System.Windows.Forms.Panel)
$btnSaveAll = (New-Object -TypeName System.Windows.Forms.Button)
$btnExit = (New-Object -TypeName System.Windows.Forms.Button)
$btnHelp = (New-Object -TypeName System.Windows.Forms.Button)
$openFileDialog1 = (New-Object -TypeName System.Windows.Forms.OpenFileDialog)
$tabControl.SuspendLayout()
$tabConnection.SuspendLayout()
$grpSource.SuspendLayout()
$grpTarget.SuspendLayout()
$tabScripts.SuspendLayout()
$grpScriptsList.SuspendLayout()
$grpScriptDetails.SuspendLayout()
$grpParameters.SuspendLayout()
$tabExecution.SuspendLayout()
$grpExecutionSettings.SuspendLayout()
([System.ComponentModel.ISupportInitialize]$numTimeout).BeginInit()
([System.ComponentModel.ISupportInitialize]$numMaxJobs).BeginInit()
$grpExecutionControls.SuspendLayout()
$grpProgress.SuspendLayout()
$grpOutput.SuspendLayout()
$tabLogs.SuspendLayout()
$grpLogs.SuspendLayout()
$statusStrip.SuspendLayout()
$pnlBottom.SuspendLayout()
$mainForm.SuspendLayout()
#
#tabControl
#
$tabControl.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$tabControl.Controls.Add($tabConnection)
$tabControl.Controls.Add($tabScripts)
$tabControl.Controls.Add($tabExecution)
$tabControl.Controls.Add($tabLogs)
$tabControl.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]10))
$tabControl.Name = [System.String]'tabControl'
$tabControl.SelectedIndex = [System.Int32]0
$tabControl.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]770,[System.Int32]500))
$tabControl.TabIndex = [System.Int32]0
#
#tabConnection
#
$tabConnection.Controls.Add($grpSource)
$tabConnection.Controls.Add($grpTarget)
$tabConnection.Controls.Add($chkUseCurrentCredentials)
$tabConnection.Controls.Add($btnSaveConnection)
$tabConnection.Controls.Add($btnLoadConnection)
$tabConnection.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]4,[System.Int32]22))
$tabConnection.Name = [System.String]'tabConnection'
$tabConnection.Padding = (New-Object -TypeName System.Windows.Forms.Padding -ArgumentList @([System.Int32]3))
$tabConnection.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]762,[System.Int32]474))
$tabConnection.TabIndex = [System.Int32]0
$tabConnection.Text = [System.String]'Connection'
$tabConnection.UseVisualStyleBackColor = $true
#
#grpSource
#
$grpSource.Controls.Add($lblSourceServer)
$grpSource.Controls.Add($txtSourceServer)
$grpSource.Controls.Add($lblSourceUsername)
$grpSource.Controls.Add($txtSourceUsername)
$grpSource.Controls.Add($lblSourcePassword)
$grpSource.Controls.Add($txtSourcePassword)
$grpSource.Controls.Add($btnTestSourceConnection)
$grpSource.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]10))
$grpSource.Name = [System.String]'grpSource'
$grpSource.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]350,[System.Int32]185))
$grpSource.TabIndex = [System.Int32]0
$grpSource.TabStop = $false
$grpSource.Text = [System.String]'Source vCenter'
#
#lblSourceServer
#
$lblSourceServer.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]30))
$lblSourceServer.Name = [System.String]'lblSourceServer'
$lblSourceServer.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$lblSourceServer.TabIndex = [System.Int32]0
$lblSourceServer.Text = [System.String]'Server:'
#
#txtSourceServer
#
$txtSourceServer.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]120,[System.Int32]30))
$txtSourceServer.Name = [System.String]'txtSourceServer'
$txtSourceServer.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]200,[System.Int32]20))
$txtSourceServer.TabIndex = [System.Int32]1
#
#lblSourceUsername
#
$lblSourceUsername.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]60))
$lblSourceUsername.Name = [System.String]'lblSourceUsername'
$lblSourceUsername.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$lblSourceUsername.TabIndex = [System.Int32]2
$lblSourceUsername.Text = [System.String]'Username:'
#
#txtSourceUsername
#
$txtSourceUsername.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]120,[System.Int32]60))
$txtSourceUsername.Name = [System.String]'txtSourceUsername'
$txtSourceUsername.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]200,[System.Int32]20))
$txtSourceUsername.TabIndex = [System.Int32]3
#
#lblSourcePassword
#
$lblSourcePassword.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]90))
$lblSourcePassword.Name = [System.String]'lblSourcePassword'
$lblSourcePassword.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$lblSourcePassword.TabIndex = [System.Int32]4
$lblSourcePassword.Text = [System.String]'Password:'
#
#txtSourcePassword
#
$txtSourcePassword.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]120,[System.Int32]90))
$txtSourcePassword.Name = [System.String]'txtSourcePassword'
$txtSourcePassword.PasswordChar = [System.Char]'*'
$txtSourcePassword.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]200,[System.Int32]20))
$txtSourcePassword.TabIndex = [System.Int32]5
#
#btnTestSourceConnection
#
$btnTestSourceConnection.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]13,[System.Int32]156))
$btnTestSourceConnection.Name = [System.String]'btnTestSourceConnection'
$btnTestSourceConnection.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]120,[System.Int32]23))
$btnTestSourceConnection.TabIndex = [System.Int32]6
$btnTestSourceConnection.Text = [System.String]'Test Connection'
$btnTestSourceConnection.UseVisualStyleBackColor = $true
#$btnTestSourceConnection.add_Click($btnTestSourceConnection_Click)
#
#grpTarget
#
$grpTarget.Controls.Add($lblTargetServer)
$grpTarget.Controls.Add($txtTargetServer)
$grpTarget.Controls.Add($lblTargetUsername)
$grpTarget.Controls.Add($txtTargetUsername)
$grpTarget.Controls.Add($lblTargetPassword)
$grpTarget.Controls.Add($txtTargetPassword)
$grpTarget.Controls.Add($btnTestTargetConnection)
$grpTarget.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]380,[System.Int32]10))
$grpTarget.Name = [System.String]'grpTarget'
$grpTarget.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]350,[System.Int32]185))
$grpTarget.TabIndex = [System.Int32]1
$grpTarget.TabStop = $false
$grpTarget.Text = [System.String]'Target vCenter'
#
#lblTargetServer
#
$lblTargetServer.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]30))
$lblTargetServer.Name = [System.String]'lblTargetServer'
$lblTargetServer.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$lblTargetServer.TabIndex = [System.Int32]0
$lblTargetServer.Text = [System.String]'Server:'
#
#txtTargetServer
#
$txtTargetServer.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]120,[System.Int32]30))
$txtTargetServer.Name = [System.String]'txtTargetServer'
$txtTargetServer.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]200,[System.Int32]20))
$txtTargetServer.TabIndex = [System.Int32]1
#
#lblTargetUsername
#
$lblTargetUsername.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]60))
$lblTargetUsername.Name = [System.String]'lblTargetUsername'
$lblTargetUsername.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$lblTargetUsername.TabIndex = [System.Int32]2
$lblTargetUsername.Text = [System.String]'Username:'
#
#txtTargetUsername
#
$txtTargetUsername.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]120,[System.Int32]60))
$txtTargetUsername.Name = [System.String]'txtTargetUsername'
$txtTargetUsername.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]200,[System.Int32]20))
$txtTargetUsername.TabIndex = [System.Int32]3
#
#lblTargetPassword
#
$lblTargetPassword.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]90))
$lblTargetPassword.Name = [System.String]'lblTargetPassword'
$lblTargetPassword.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$lblTargetPassword.TabIndex = [System.Int32]4
$lblTargetPassword.Text = [System.String]'Password:'
#
#txtTargetPassword
#
$txtTargetPassword.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]120,[System.Int32]90))
$txtTargetPassword.Name = [System.String]'txtTargetPassword'
$txtTargetPassword.PasswordChar = [System.Char]'*'
$txtTargetPassword.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]200,[System.Int32]20))
$txtTargetPassword.TabIndex = [System.Int32]5
#
#btnTestTargetConnection
#
$btnTestTargetConnection.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]13,[System.Int32]156))
$btnTestTargetConnection.Name = [System.String]'btnTestTargetConnection'
$btnTestTargetConnection.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]120,[System.Int32]23))
$btnTestTargetConnection.TabIndex = [System.Int32]6
$btnTestTargetConnection.Text = [System.String]'Test Connection'
$btnTestTargetConnection.UseVisualStyleBackColor = $true
#$btnTestTargetConnection.add_Click($btnTestTargetConnection_Click)
#
#chkUseCurrentCredentials
#
$chkUseCurrentCredentials.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]201))
$chkUseCurrentCredentials.Name = [System.String]'chkUseCurrentCredentials'
$chkUseCurrentCredentials.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]250,[System.Int32]20))
$chkUseCurrentCredentials.TabIndex = [System.Int32]2
$chkUseCurrentCredentials.Text = [System.String]'Use current Windows credentials'
$chkUseCurrentCredentials.UseVisualStyleBackColor = $true
#
#btnSaveConnection
#
$btnSaveConnection.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]227))
$btnSaveConnection.Name = [System.String]'btnSaveConnection'
$btnSaveConnection.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]180,[System.Int32]23))
$btnSaveConnection.TabIndex = [System.Int32]3
$btnSaveConnection.Text = [System.String]'Save Connection Settings'
$btnSaveConnection.UseVisualStyleBackColor = $true
#$btnSaveConnection.add_Click($btnSaveConnection_Click)
#
#btnLoadConnection
#
$btnLoadConnection.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]196,[System.Int32]227))
$btnLoadConnection.Name = [System.String]'btnLoadConnection'
$btnLoadConnection.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]180,[System.Int32]23))
$btnLoadConnection.TabIndex = [System.Int32]4
$btnLoadConnection.Text = [System.String]'Load Connection Settings'
$btnLoadConnection.UseVisualStyleBackColor = $true
#$btnLoadConnection.add_Click($btnLoadConnection_Click)
#
#tabScripts
#
$tabScripts.Controls.Add($grpScriptsList)
$tabScripts.Controls.Add($grpScriptDetails)
$tabScripts.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]4,[System.Int32]22))
$tabScripts.Name = [System.String]'tabScripts'
$tabScripts.Padding = (New-Object -TypeName System.Windows.Forms.Padding -ArgumentList @([System.Int32]3))
$tabScripts.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]762,[System.Int32]474))
$tabScripts.TabIndex = [System.Int32]1
$tabScripts.Text = [System.String]'Scripts'
$tabScripts.UseVisualStyleBackColor = $true
#
#grpScriptsList
#
$grpScriptsList.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$grpScriptsList.Controls.Add($lvScripts)
$grpScriptsList.Controls.Add($btnAddScript)
$grpScriptsList.Controls.Add($btnRemoveScript)
$grpScriptsList.Controls.Add($btnMoveUp)
$grpScriptsList.Controls.Add($btnMoveDown)
$grpScriptsList.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]10))
$grpScriptsList.Name = [System.String]'grpScriptsList'
$grpScriptsList.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]350,[System.Int32]450))
$grpScriptsList.TabIndex = [System.Int32]0
$grpScriptsList.TabStop = $false
$grpScriptsList.Text = [System.String]'Scripts List'
#
#lvScripts
#
$lvScripts.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$lvScripts.FullRowSelect = $true
$lvScripts.GridLines = $true
$lvScripts.HideSelection = $false
$lvScripts.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]20))
$lvScripts.Name = [System.String]'lvScripts'
$lvScripts.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]330,[System.Int32]380))
$lvScripts.TabIndex = [System.Int32]0
$lvScripts.UseCompatibleStateImageBehavior = $false
$lvScripts.View = [System.Windows.Forms.View]::Details
#
#btnAddScript
#
$btnAddScript.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnAddScript.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]410))
$btnAddScript.Name = [System.String]'btnAddScript'
$btnAddScript.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]23))
$btnAddScript.TabIndex = [System.Int32]1
$btnAddScript.Text = [System.String]'Add Script'
$btnAddScript.UseVisualStyleBackColor = $true
#$btnAddScript.add_Click($btnAddScript_Click)
#
#btnRemoveScript
#
$btnRemoveScript.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnRemoveScript.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]120,[System.Int32]410))
$btnRemoveScript.Name = [System.String]'btnRemoveScript'
$btnRemoveScript.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]23))
$btnRemoveScript.TabIndex = [System.Int32]2
$btnRemoveScript.Text = [System.String]'Remove Script'
$btnRemoveScript.UseVisualStyleBackColor = $true
#$btnRemoveScript.add_Click($btnRemoveScript_Click)
#
#btnMoveUp
#
$btnMoveUp.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnMoveUp.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]230,[System.Int32]410))
$btnMoveUp.Name = [System.String]'btnMoveUp'
$btnMoveUp.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]50,[System.Int32]23))
$btnMoveUp.TabIndex = [System.Int32]3
$btnMoveUp.Text = [System.String]'Move Up'
$btnMoveUp.UseVisualStyleBackColor = $true
#$btnMoveUp.add_Click($btnMoveUp_Click)
#
#btnMoveDown
#
$btnMoveDown.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnMoveDown.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]290,[System.Int32]410))
$btnMoveDown.Name = [System.String]'btnMoveDown'
$btnMoveDown.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]50,[System.Int32]23))
$btnMoveDown.TabIndex = [System.Int32]4
$btnMoveDown.Text = [System.String]'Move Down'
$btnMoveDown.UseVisualStyleBackColor = $true
#$btnMoveDown.add_Click($btnMoveDown_Click)
#
#grpScriptDetails
#
$grpScriptDetails.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$grpScriptDetails.Controls.Add($lblScriptPath)
$grpScriptDetails.Controls.Add($txtScriptPath)
$grpScriptDetails.Controls.Add($btnBrowse)
$grpScriptDetails.Controls.Add($lblScriptDescription)
$grpScriptDetails.Controls.Add($txtScriptDescription)
$grpScriptDetails.Controls.Add($chkScriptEnabled)
$grpScriptDetails.Controls.Add($grpParameters)
$grpScriptDetails.Controls.Add($btnSaveScriptDetails)
$grpScriptDetails.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]370,[System.Int32]10))
$grpScriptDetails.Name = [System.String]'grpScriptDetails'
$grpScriptDetails.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]380,[System.Int32]450))
$grpScriptDetails.TabIndex = [System.Int32]1
$grpScriptDetails.TabStop = $false
$grpScriptDetails.Text = [System.String]'Script Details'
#
#lblScriptPath
#
$lblScriptPath.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]30))
$lblScriptPath.Name = [System.String]'lblScriptPath'
$lblScriptPath.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]80,[System.Int32]20))
$lblScriptPath.TabIndex = [System.Int32]0
$lblScriptPath.Text = [System.String]'Script Path:'
#
#txtScriptPath
#
$txtScriptPath.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$txtScriptPath.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]100,[System.Int32]30))
$txtScriptPath.Name = [System.String]'txtScriptPath'
$txtScriptPath.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]200,[System.Int32]20))
$txtScriptPath.TabIndex = [System.Int32]1
#
#btnBrowse
#
$btnBrowse.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right)
$btnBrowse.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]310,[System.Int32]28))
$btnBrowse.Name = [System.String]'btnBrowse'
$btnBrowse.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]60,[System.Int32]23))
$btnBrowse.TabIndex = [System.Int32]2
$btnBrowse.Text = [System.String]'Browse...'
$btnBrowse.UseVisualStyleBackColor = $true
#
#lblScriptDescription
#
$lblScriptDescription.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]60))
$lblScriptDescription.Name = [System.String]'lblScriptDescription'
$lblScriptDescription.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]80,[System.Int32]20))
$lblScriptDescription.TabIndex = [System.Int32]3
$lblScriptDescription.Text = [System.String]'Description:'
#
#txtScriptDescription
#
$txtScriptDescription.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$txtScriptDescription.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]100,[System.Int32]60))
$txtScriptDescription.Name = [System.String]'txtScriptDescription'
$txtScriptDescription.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]270,[System.Int32]20))
$txtScriptDescription.TabIndex = [System.Int32]4
#
#chkScriptEnabled
#
$chkScriptEnabled.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]100,[System.Int32]90))
$chkScriptEnabled.Name = [System.String]'chkScriptEnabled'
$chkScriptEnabled.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$chkScriptEnabled.TabIndex = [System.Int32]5
$chkScriptEnabled.Text = [System.String]'Enabled'
$chkScriptEnabled.UseVisualStyleBackColor = $true
#
#grpParameters
#
$grpParameters.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$grpParameters.Controls.Add($lvParameters)
$grpParameters.Controls.Add($btnAddParam)
$grpParameters.Controls.Add($btnEditParam)
$grpParameters.Controls.Add($btnRemoveParam)
$grpParameters.Controls.Add($btnDetectParams)
$grpParameters.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]120))
$grpParameters.Name = [System.String]'grpParameters'
$grpParameters.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]360,[System.Int32]280))
$grpParameters.TabIndex = [System.Int32]6
$grpParameters.TabStop = $false
$grpParameters.Text = [System.String]'Parameters'
#
#lvParameters
#
$lvParameters.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$lvParameters.FullRowSelect = $true
$lvParameters.GridLines = $true
$lvParameters.HideSelection = $false
$lvParameters.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]20))
$lvParameters.Name = [System.String]'lvParameters'
$lvParameters.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]340,[System.Int32]210))
$lvParameters.TabIndex = [System.Int32]0
$lvParameters.UseCompatibleStateImageBehavior = $false
$lvParameters.View = [System.Windows.Forms.View]::Details
#
#btnAddParam
#
$btnAddParam.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnAddParam.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]240))
$btnAddParam.Name = [System.String]'btnAddParam'
$btnAddParam.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]60,[System.Int32]23))
$btnAddParam.TabIndex = [System.Int32]1
$btnAddParam.Text = [System.String]'Add'
$btnAddParam.UseVisualStyleBackColor = $true
#$btnAddParam.add_Click($btnAddParam_Click)
#
#btnEditParam
#
$btnEditParam.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnEditParam.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]80,[System.Int32]240))
$btnEditParam.Name = [System.String]'btnEditParam'
$btnEditParam.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]60,[System.Int32]23))
$btnEditParam.TabIndex = [System.Int32]2
$btnEditParam.Text = [System.String]'Edit'
$btnEditParam.UseVisualStyleBackColor = $true
#$btnEditParam.add_Click($btnEditParam_Click)
#
#btnRemoveParam
#
$btnRemoveParam.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnRemoveParam.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]150,[System.Int32]240))
$btnRemoveParam.Name = [System.String]'btnRemoveParam'
$btnRemoveParam.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]60,[System.Int32]23))
$btnRemoveParam.TabIndex = [System.Int32]3
$btnRemoveParam.Text = [System.String]'Remove'
$btnRemoveParam.UseVisualStyleBackColor = $true
#$btnRemoveParam.add_Click($btnRemoveParam_Click)
#
#btnDetectParams
#
$btnDetectParams.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnDetectParams.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]220,[System.Int32]240))
$btnDetectParams.Name = [System.String]'btnDetectParams'
$btnDetectParams.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]130,[System.Int32]23))
$btnDetectParams.TabIndex = [System.Int32]4
$btnDetectParams.Text = [System.String]'Detect Parameters'
$btnDetectParams.UseVisualStyleBackColor = $true
#$btnDetectParams.add_Click($btnDetectParams_Click)
#
#btnSaveScriptDetails
#
$btnSaveScriptDetails.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnSaveScriptDetails.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]410))
$btnSaveScriptDetails.Name = [System.String]'btnSaveScriptDetails'
$btnSaveScriptDetails.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]150,[System.Int32]23))
$btnSaveScriptDetails.TabIndex = [System.Int32]7
$btnSaveScriptDetails.Text = [System.String]'Save Script Details'
$btnSaveScriptDetails.UseVisualStyleBackColor = $true
#$btnSaveScriptDetails.add_Click($btnSaveScriptDetails_Click)
#
#tabExecution
#
$tabExecution.Controls.Add($grpExecutionSettings)
$tabExecution.Controls.Add($grpExecutionControls)
$tabExecution.Controls.Add($grpProgress)
$tabExecution.Controls.Add($grpOutput)
$tabExecution.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]4,[System.Int32]22))
$tabExecution.Name = [System.String]'tabExecution'
$tabExecution.Padding = (New-Object -TypeName System.Windows.Forms.Padding -ArgumentList @([System.Int32]3))
$tabExecution.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]762,[System.Int32]474))
$tabExecution.TabIndex = [System.Int32]2
$tabExecution.Text = [System.String]'Execution'
$tabExecution.UseVisualStyleBackColor = $true
#
#grpExecutionSettings
#
$grpExecutionSettings.Controls.Add($chkStopOnError)
$grpExecutionSettings.Controls.Add($chkSkipConfirmation)
$grpExecutionSettings.Controls.Add($lblTimeout)
$grpExecutionSettings.Controls.Add($numTimeout)
$grpExecutionSettings.Controls.Add($lblMaxJobs)
$grpExecutionSettings.Controls.Add($numMaxJobs)
$grpExecutionSettings.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]10))
$grpExecutionSettings.Name = [System.String]'grpExecutionSettings'
$grpExecutionSettings.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]350,[System.Int32]150))
$grpExecutionSettings.TabIndex = [System.Int32]0
$grpExecutionSettings.TabStop = $false
$grpExecutionSettings.Text = [System.String]'Execution Settings'
#
#chkStopOnError
#
$chkStopOnError.Checked = $true
$chkStopOnError.CheckState = [System.Windows.Forms.CheckState]::Checked
$chkStopOnError.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]20,[System.Int32]30))
$chkStopOnError.Name = [System.String]'chkStopOnError'
$chkStopOnError.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]150,[System.Int32]20))
$chkStopOnError.TabIndex = [System.Int32]0
$chkStopOnError.Text = [System.String]'Stop on error'
$chkStopOnError.UseVisualStyleBackColor = $true
#
#chkSkipConfirmation
#
$chkSkipConfirmation.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]20,[System.Int32]60))
$chkSkipConfirmation.Name = [System.String]'chkSkipConfirmation'
$chkSkipConfirmation.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]200,[System.Int32]20))
$chkSkipConfirmation.TabIndex = [System.Int32]1
$chkSkipConfirmation.Text = [System.String]'Skip confirmation prompts'
$chkSkipConfirmation.UseVisualStyleBackColor = $true
#
#lblTimeout
#
$lblTimeout.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]20,[System.Int32]90))
$lblTimeout.Name = [System.String]'lblTimeout'
$lblTimeout.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]150,[System.Int32]20))
$lblTimeout.TabIndex = [System.Int32]2
$lblTimeout.Text = [System.String]'Script timeout (seconds):'
#
#numTimeout
#
$numTimeout.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]180,[System.Int32]90))
$numTimeout.Maximum = [System.Int32]3600
$numTimeout.Minimum = [System.Int32]30
$numTimeout.Name = [System.String]'numTimeout'
$numTimeout.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]80,[System.Int32]20))
$numTimeout.TabIndex = [System.Int32]3
$numTimeout.Value = [System.Int32]300
#
#lblMaxJobs
#
$lblMaxJobs.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]20,[System.Int32]120))
$lblMaxJobs.Name = [System.String]'lblMaxJobs'
$lblMaxJobs.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]150,[System.Int32]20))
$lblMaxJobs.TabIndex = [System.Int32]4
$lblMaxJobs.Text = [System.String]'Max concurrent jobs:'
#
#numMaxJobs
#
$numMaxJobs.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]180,[System.Int32]120))
$numMaxJobs.Maximum = [System.Int32]10
$numMaxJobs.Minimum = [System.Int32]1
$numMaxJobs.Name = [System.String]'numMaxJobs'
$numMaxJobs.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]80,[System.Int32]20))
$numMaxJobs.TabIndex = [System.Int32]5
$numMaxJobs.Value = [System.Int32]1
#
#grpExecutionControls
#
$grpExecutionControls.Controls.Add($btnRunAll)
$grpExecutionControls.Controls.Add($btnRunSelected)
$grpExecutionControls.Controls.Add($btnStopExecution)
$grpExecutionControls.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]380,[System.Int32]10))
$grpExecutionControls.Name = [System.String]'grpExecutionControls'
$grpExecutionControls.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]350,[System.Int32]150))
$grpExecutionControls.TabIndex = [System.Int32]1
$grpExecutionControls.TabStop = $false
$grpExecutionControls.Text = [System.String]'Execution Controls'
#
#btnRunAll
#
$btnRunAll.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]20,[System.Int32]30))
$btnRunAll.Name = [System.String]'btnRunAll'
$btnRunAll.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]150,[System.Int32]30))
$btnRunAll.TabIndex = [System.Int32]0
$btnRunAll.Text = [System.String]'Run All Scripts'
$btnRunAll.UseVisualStyleBackColor = $true
#$btnRunAll.add_Click($btnRunAll_Click)
#
#btnRunSelected
#
$btnRunSelected.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]180,[System.Int32]30))
$btnRunSelected.Name = [System.String]'btnRunSelected'
$btnRunSelected.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]150,[System.Int32]30))
$btnRunSelected.TabIndex = [System.Int32]1
$btnRunSelected.Text = [System.String]'Run Selected Script'
$btnRunSelected.UseVisualStyleBackColor = $true
#$btnRunSelected.add_Click($btnRunSelected_Click)
#
#btnStopExecution
#
$btnStopExecution.Enabled = $false
$btnStopExecution.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]20,[System.Int32]70))
$btnStopExecution.Name = [System.String]'btnStopExecution'
$btnStopExecution.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]150,[System.Int32]30))
$btnStopExecution.TabIndex = [System.Int32]2
$btnStopExecution.Text = [System.String]'Stop Execution'
$btnStopExecution.UseVisualStyleBackColor = $true
#$btnStopExecution.add_Click($btnStopExecution_Click)
#
#grpProgress
#
$grpProgress.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$grpProgress.Controls.Add($lblOverallProgress)
$grpProgress.Controls.Add($progressOverall)
$grpProgress.Controls.Add($lblCurrentProgress)
$grpProgress.Controls.Add($progressCurrentScript)
$grpProgress.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]170))
$grpProgress.Name = [System.String]'grpProgress'
$grpProgress.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]720,[System.Int32]100))
$grpProgress.TabIndex = [System.Int32]2
$grpProgress.TabStop = $false
$grpProgress.Text = [System.String]'Progress'
#
#lblOverallProgress
#
$lblOverallProgress.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]20,[System.Int32]30))
$lblOverallProgress.Name = [System.String]'lblOverallProgress'
$lblOverallProgress.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$lblOverallProgress.TabIndex = [System.Int32]0
$lblOverallProgress.Text = [System.String]'Overall Progress:'
#
#progressOverall
#
$progressOverall.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$progressOverall.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]130,[System.Int32]30))
$progressOverall.Name = [System.String]'progressOverall'
$progressOverall.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]570,[System.Int32]20))
$progressOverall.TabIndex = [System.Int32]1
#
#lblCurrentProgress
#
$lblCurrentProgress.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]20,[System.Int32]60))
$lblCurrentProgress.Name = [System.String]'lblCurrentProgress'
$lblCurrentProgress.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]20))
$lblCurrentProgress.TabIndex = [System.Int32]2
$lblCurrentProgress.Text = [System.String]'Current Script:'
#
#progressCurrentScript
#
$progressCurrentScript.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$progressCurrentScript.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]130,[System.Int32]60))
$progressCurrentScript.Name = [System.String]'progressCurrentScript'
$progressCurrentScript.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]570,[System.Int32]20))
$progressCurrentScript.TabIndex = [System.Int32]3
#
#grpOutput
#
$grpOutput.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$grpOutput.Controls.Add($txtExecutionOutput)
$grpOutput.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]280))
$grpOutput.Name = [System.String]'grpOutput'
$grpOutput.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]720,[System.Int32]180))
$grpOutput.TabIndex = [System.Int32]3
$grpOutput.TabStop = $false
$grpOutput.Text = [System.String]'Execution Output'
#
#txtExecutionOutput
#
$txtExecutionOutput.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$txtExecutionOutput.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]20))
$txtExecutionOutput.Multiline = $true
$txtExecutionOutput.Name = [System.String]'txtExecutionOutput'
$txtExecutionOutput.ReadOnly = $true
$txtExecutionOutput.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtExecutionOutput.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]700,[System.Int32]150))
$txtExecutionOutput.TabIndex = [System.Int32]0
#
#tabLogs
#
$tabLogs.Controls.Add($grpLogs)
$tabLogs.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]4,[System.Int32]22))
$tabLogs.Name = [System.String]'tabLogs'
$tabLogs.Padding = (New-Object -TypeName System.Windows.Forms.Padding -ArgumentList @([System.Int32]3))
$tabLogs.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]762,[System.Int32]474))
$tabLogs.TabIndex = [System.Int32]3
$tabLogs.Text = [System.String]'Logs'
$tabLogs.UseVisualStyleBackColor = $true
#
#grpLogs
#
$grpLogs.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$grpLogs.Controls.Add($logTextBox)
$grpLogs.Controls.Add($btnRefreshLogs)
$grpLogs.Controls.Add($btnClearLogs)
$grpLogs.Controls.Add($btnExportLogs)
$grpLogs.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]10))
$grpLogs.Name = [System.String]'grpLogs'
$grpLogs.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]720,[System.Int32]440))
$grpLogs.TabIndex = [System.Int32]0
$grpLogs.TabStop = $false
$grpLogs.Text = [System.String]'Application Logs'
#
#logTextBox
#
$logTextBox.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$logTextBox.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]20))
$logTextBox.Multiline = $true
$logTextBox.Name = [System.String]'logTextBox'
$logTextBox.ReadOnly = $true
$logTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$logTextBox.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]700,[System.Int32]380))
$logTextBox.TabIndex = [System.Int32]0
#
#btnRefreshLogs
#
$btnRefreshLogs.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnRefreshLogs.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]410))
$btnRefreshLogs.Name = [System.String]'btnRefreshLogs'
$btnRefreshLogs.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]23))
$btnRefreshLogs.TabIndex = [System.Int32]1
$btnRefreshLogs.Text = [System.String]'Refresh Logs'
$btnRefreshLogs.UseVisualStyleBackColor = $true
#$btnRefreshLogs.add_Click($btnRefreshLogs_Click)
#
#btnClearLogs
#
$btnClearLogs.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnClearLogs.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]120,[System.Int32]410))
$btnClearLogs.Name = [System.String]'btnClearLogs'
$btnClearLogs.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]23))
$btnClearLogs.TabIndex = [System.Int32]2
$btnClearLogs.Text = [System.String]'Clear Logs'
$btnClearLogs.UseVisualStyleBackColor = $true
#$btnClearLogs.add_Click($btnClearLogs_Click)
#
#btnExportLogs
#
$btnExportLogs.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left)
$btnExportLogs.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]230,[System.Int32]410))
$btnExportLogs.Name = [System.String]'btnExportLogs'
$btnExportLogs.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]100,[System.Int32]23))
$btnExportLogs.TabIndex = [System.Int32]3
$btnExportLogs.Text = [System.String]'Export Logs'
$btnExportLogs.UseVisualStyleBackColor = $true
#$btnExportLogs.add_Click($btnExportLogs_Click)
#
#statusStrip
#
$statusStrip.Items.AddRange([System.Windows.Forms.ToolStripItem[]]@($statusStripLabel))
$statusStrip.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]0,[System.Int32]578))
$statusStrip.Name = [System.String]'statusStrip'
$statusStrip.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]800,[System.Int32]22))
$statusStrip.TabIndex = [System.Int32]1
$statusStrip.Text = [System.String]'statusStrip'
#
#statusStripLabel
#
$statusStripLabel.Name = [System.String]'statusStripLabel'
$statusStripLabel.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]39,[System.Int32]17))
$statusStripLabel.Text = [System.String]'Ready'
#
#pnlBottom
#
$pnlBottom.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$pnlBottom.Controls.Add($btnSaveAll)
$pnlBottom.Controls.Add($btnExit)
$pnlBottom.Controls.Add($btnHelp)
$pnlBottom.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]520))
$pnlBottom.Name = [System.String]'pnlBottom'
$pnlBottom.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]770,[System.Int32]30))
$pnlBottom.TabIndex = [System.Int32]2
#
#btnSaveAll
#
$btnSaveAll.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]10,[System.Int32]0))
$btnSaveAll.Name = [System.String]'btnSaveAll'
$btnSaveAll.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]120,[System.Int32]25))
$btnSaveAll.TabIndex = [System.Int32]0
$btnSaveAll.Text = [System.String]'Save All Settings'
$btnSaveAll.UseVisualStyleBackColor = $true
#
#btnExit
#
$btnExit.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]140,[System.Int32]0))
$btnExit.Name = [System.String]'btnExit'
$btnExit.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]80,[System.Int32]25))
$btnExit.TabIndex = [System.Int32]1
$btnExit.Text = [System.String]'Exit'
$btnExit.UseVisualStyleBackColor = $true
#
#btnHelp
#
$btnHelp.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]230,[System.Int32]0))
$btnHelp.Name = [System.String]'btnHelp'
$btnHelp.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]80,[System.Int32]25))
$btnHelp.TabIndex = [System.Int32]2
$btnHelp.Text = [System.String]'Help'
$btnHelp.UseVisualStyleBackColor = $true
#
#openFileDialog1
#
$openFileDialog1.FileName = [System.String]'openFileDialog'
#
#mainForm
#
$mainForm.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]800,[System.Int32]600))
$mainForm.Controls.Add($tabControl)
$mainForm.Controls.Add($pnlBottom)
$mainForm.Controls.Add($statusStrip)
$mainForm.MinimumSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]800,[System.Int32]600))
$mainForm.Name = [System.String]'mainForm'
$mainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$mainForm.TopMost = $true
$mainForm.Text = [System.String]'vCenter Migration Workflow Manager'
$tabControl.ResumeLayout($false)
$tabConnection.ResumeLayout($false)
$grpSource.ResumeLayout($false)
$grpSource.PerformLayout()
$grpTarget.ResumeLayout($false)
$grpTarget.PerformLayout()
$tabScripts.ResumeLayout($false)
$grpScriptsList.ResumeLayout($false)
$grpScriptDetails.ResumeLayout($false)
$grpScriptDetails.PerformLayout()
$grpParameters.ResumeLayout($false)
$tabExecution.ResumeLayout($false)
$grpExecutionSettings.ResumeLayout($false)
([System.ComponentModel.ISupportInitialize]$numTimeout).EndInit()
([System.ComponentModel.ISupportInitialize]$numMaxJobs).EndInit()
$grpExecutionControls.ResumeLayout($false)
$grpProgress.ResumeLayout($false)
$grpOutput.ResumeLayout($false)
$grpOutput.PerformLayout()
$tabLogs.ResumeLayout($false)
$grpLogs.ResumeLayout($false)
$grpLogs.PerformLayout()
$statusStrip.ResumeLayout($false)
$statusStrip.PerformLayout()
$pnlBottom.ResumeLayout($false)
$mainForm.ResumeLayout($false)
$mainForm.PerformLayout()
Add-Member -InputObject $mainForm -Name tabControl -Value $tabControl -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name tabConnection -Value $tabConnection -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name tabScripts -Value $tabScripts -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name tabExecution -Value $tabExecution -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name tabLogs -Value $tabLogs -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpSource -Value $grpSource -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblSourceServer -Value $lblSourceServer -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtSourceServer -Value $txtSourceServer -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblSourceUsername -Value $lblSourceUsername -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtSourceUsername -Value $txtSourceUsername -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblSourcePassword -Value $lblSourcePassword -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtSourcePassword -Value $txtSourcePassword -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnTestSourceConnection -Value $btnTestSourceConnection -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpTarget -Value $grpTarget -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblTargetServer -Value $lblTargetServer -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtTargetServer -Value $txtTargetServer -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblTargetUsername -Value $lblTargetUsername -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtTargetUsername -Value $txtTargetUsername -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblTargetPassword -Value $lblTargetPassword -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtTargetPassword -Value $txtTargetPassword -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnTestTargetConnection -Value $btnTestTargetConnection -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name chkUseCurrentCredentials -Value $chkUseCurrentCredentials -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnSaveConnection -Value $btnSaveConnection -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnLoadConnection -Value $btnLoadConnection -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpScriptsList -Value $grpScriptsList -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lvScripts -Value $lvScripts -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnAddScript -Value $btnAddScript -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnRemoveScript -Value $btnRemoveScript -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnMoveUp -Value $btnMoveUp -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnMoveDown -Value $btnMoveDown -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpScriptDetails -Value $grpScriptDetails -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblScriptPath -Value $lblScriptPath -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtScriptPath -Value $txtScriptPath -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnBrowse -Value $btnBrowse -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblScriptDescription -Value $lblScriptDescription -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtScriptDescription -Value $txtScriptDescription -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name chkScriptEnabled -Value $chkScriptEnabled -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpParameters -Value $grpParameters -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lvParameters -Value $lvParameters -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnAddParam -Value $btnAddParam -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnEditParam -Value $btnEditParam -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnRemoveParam -Value $btnRemoveParam -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnDetectParams -Value $btnDetectParams -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnSaveScriptDetails -Value $btnSaveScriptDetails -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpExecutionSettings -Value $grpExecutionSettings -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name chkStopOnError -Value $chkStopOnError -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name chkSkipConfirmation -Value $chkSkipConfirmation -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblTimeout -Value $lblTimeout -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name numTimeout -Value $numTimeout -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblMaxJobs -Value $lblMaxJobs -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name numMaxJobs -Value $numMaxJobs -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpExecutionControls -Value $grpExecutionControls -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnRunAll -Value $btnRunAll -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnRunSelected -Value $btnRunSelected -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnStopExecution -Value $btnStopExecution -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpProgress -Value $grpProgress -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblOverallProgress -Value $lblOverallProgress -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name progressOverall -Value $progressOverall -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name lblCurrentProgress -Value $lblCurrentProgress -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name progressCurrentScript -Value $progressCurrentScript -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpOutput -Value $grpOutput -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name txtExecutionOutput -Value $txtExecutionOutput -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name grpLogs -Value $grpLogs -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name logTextBox -Value $logTextBox -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnRefreshLogs -Value $btnRefreshLogs -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnClearLogs -Value $btnClearLogs -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnExportLogs -Value $btnExportLogs -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name statusStrip -Value $statusStrip -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name statusStripLabel -Value $statusStripLabel -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name pnlBottom -Value $pnlBottom -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnSaveAll -Value $btnSaveAll -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnExit -Value $btnExit -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name openFileDialog1 -Value $openFileDialog1 -MemberType NoteProperty
Add-Member -InputObject $mainForm -Name btnHelp -Value $btnHelp -MemberType NoteProperty
}
. InitializeComponent


# ADD THE FIX CODE HERE - AFTER the InitializeComponent call
$AI_Gen_Workflow_Wrapper = $mainForm
$Global:AI_Gen_Workflow_Wrapper = $mainForm
$Global:MainForm = $mainForm

# Debug output
Write-Host "Designer: Form created successfully as 'mainForm'" -ForegroundColor Green
Write-Host "Designer: Form also available as 'AI_Gen_Workflow_Wrapper'" -ForegroundColor Green
Write-Host "Designer: Form type is $($mainForm.GetType().Name)" -ForegroundColor Cyan
Write-Host "Designer: Form text is '$($mainForm.Text)'" -ForegroundColor Gray