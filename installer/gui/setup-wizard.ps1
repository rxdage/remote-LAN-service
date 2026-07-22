# remote-LAN-service — Windows GUI setup wizard (WPF). Tier A client.
# Packaged into setup.exe by scripts/build-windows-exe.ps1 (ps2exe -requireAdmin -noConsole).
# Flow: Welcome/Tier -> Connection -> Review -> Install/Done. Self-contained (one script → one exe).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
try { Add-Type -Namespace Native -Name Dwm -MemberDefinition '[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(System.IntPtr h, int a, ref int v, int s);' -ErrorAction Stop } catch {}

# ---- the actual work (tier A): point RustDesk at the self-hosted server ----
function Set-RustDeskOptions([string]$Path, $Options) {
  $enc = New-Object Text.UTF8Encoding($false)
  if (-not (Test-Path $Path)) {
    $dir = Split-Path -Parent $Path; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $sb = "[options]`n"; foreach ($k in $Options.Keys) { $sb += "$k = '$($Options[$k])'`n" }
    [IO.File]::WriteAllText($Path, $sb, $enc); return
  }
  $lines = [System.Collections.Generic.List[string]]::new()
  ([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8) -split "`r?`n") | ForEach-Object { $lines.Add($_) }
  $optIdx = -1
  for ($i=0;$i -lt $lines.Count;$i++){ if ($lines[$i].Trim() -eq '[options]'){ $optIdx=$i; break } }
  if ($optIdx -lt 0){ $lines.Add('[options]'); $optIdx=$lines.Count-1 }
  $end = $lines.Count
  for ($i=$optIdx+1;$i -lt $lines.Count;$i++){ if ($lines[$i].Trim() -match '^\[.+\]$'){ $end=$i; break } }
  foreach ($k in $Options.Keys){
    $line = "$k = '$($Options[$k])'"; $found=$false
    for ($i=$optIdx+1;$i -lt $end;$i++){ if ($lines[$i] -match ("^\s*"+[regex]::Escape($k)+"\s*=")){ $lines[$i]=$line; $found=$true; break } }
    if (-not $found){ $lines.Insert($end,$line); $end++ }
  }
  [IO.File]::WriteAllText($Path, ($lines -join "`n"), $enc)
}

function Invoke-Install($serverIp, $key, $log) {
  $log.Invoke("查找 RustDesk ...")
  $rdExe = 'C:\Program Files\RustDesk\rustdesk.exe'
  if (-not (Test-Path $rdExe)) { throw "未检测到 RustDesk($rdExe)。请先安装 RustDesk 客户端再重试。" }
  $want = [ordered]@{ 'custom-rendezvous-server' = $serverIp; 'relay-server' = $serverIp }
  if ($key) { $want['key'] = $key }

  $svc = Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
  if ($svc -and $svc.Status -eq 'Running') { $log.Invoke("暂停 RustDesk 服务以写配置 ..."); Stop-Service 'RustDesk' -Force }

  $paths = @( (Join-Path $env:APPDATA 'RustDesk\config\RustDesk2.toml') )
  $svcToml = 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml'
  if (Test-Path (Split-Path -Parent $svcToml)) { $paths += $svcToml }
  foreach ($p in $paths) { Set-RustDeskOptions -Path $p -Options $want; $log.Invoke("已写: $p") }

  if ($svc) { Start-Service 'RustDesk'; $log.Invoke("已重启 RustDesk 服务。") }
  $log.Invoke("完成:RustDesk 已指向 $serverIp。打开 RustDesk 看本机 ID,按对端 ID 连即可。")
}

# ---- UI ---------------------------------------------------------------------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="remote-LAN-service 安装向导" Height="560" Width="720"
        WindowStartupLocation="CenterScreen" Background="#191B21" FontFamily="Segoe UI" ResizeMode="CanMinimize">
  <Window.Resources>
    <Style x:Key="P" TargetType="Button">
      <Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="#5B76F7"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="FontSize" Value="14"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Height" Value="40"/><Setter Property="Width" Value="120"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" CornerRadius="9" Background="{TemplateBinding Background}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#6D86FF"/></Trigger>
        <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="G" TargetType="Button" BasedOn="{StaticResource P}"><Setter Property="Background" Value="#2A2D37"/><Setter Property="Foreground" Value="#E8E8EC"/></Style>
    <Style TargetType="TextBox"><Setter Property="Background" Value="#23262F"/><Setter Property="Foreground" Value="#EEEEF1"/><Setter Property="BorderBrush" Value="#3A3D47"/><Setter Property="Padding" Value="9,7"/><Setter Property="FontSize" Value="14"/><Setter Property="CaretBrush" Value="White"/></Style>
    <Style x:Key="H" TargetType="TextBlock"><Setter Property="Foreground" Value="#F2F2F5"/><Setter Property="FontSize" Value="21"/><Setter Property="FontWeight" Value="SemiBold"/></Style>
    <Style x:Key="Lbl" TargetType="TextBlock"><Setter Property="Foreground" Value="#B6B7BD"/><Setter Property="FontSize" Value="13"/><Setter Property="Margin" Value="0,14,0,5"/></Style>
    <Style x:Key="Sub" TargetType="TextBlock"><Setter Property="Foreground" Value="#82848C"/><Setter Property="FontSize" Value="12.5"/><Setter Property="TextWrapping" Value="Wrap"/></Style>
  </Window.Resources>
  <Grid Margin="26">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <StackPanel Grid.Row="0">
      <TextBlock x:Name="StepTitle" Style="{StaticResource H}" Text="欢迎"/>
      <TextBlock x:Name="StepHint" Style="{StaticResource Sub}" Margin="0,4,0,0" Text=""/>
      <Border Height="1" Background="#2C2F39" Margin="0,16,0,0"/>
    </StackPanel>

    <Grid Grid.Row="1" Margin="0,18,0,0">
      <!-- Page 1: welcome + tier -->
      <StackPanel x:Name="Page1">
        <TextBlock Style="{StaticResource Sub}" Text="这个向导会把你这台 Windows 机器接入你自建的远程接入服务。先选一个档位:"/>
        <StackPanel Margin="0,16,0,0">
          <RadioButton x:Name="TierA" GroupName="tier" IsChecked="True" Foreground="#EEEEF1" FontSize="15">
            <StackPanel><TextBlock Text="A 极简 —— 自建 RustDesk,按 ID 连" Foreground="#EEEEF1" FontSize="15" FontWeight="SemiBold"/>
            <TextBlock Style="{StaticResource Sub}" Text="只需服务器 IP + Key。最省事,适合先跑起来。"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="TierB" GroupName="tier" IsEnabled="False" Foreground="#7E808A" FontSize="15" Margin="0,12,0,0">
            <StackPanel><TextBlock Text="B 多线 —— 加 WireGuard/ZeroTier 直连内网(即将支持)" Foreground="#7E808A" FontSize="15"/></StackPanel>
          </RadioButton>
          <RadioButton x:Name="TierC" GroupName="tier" IsEnabled="False" Foreground="#7E808A" FontSize="15" Margin="0,10,0,0">
            <TextBlock Text="C 双服 —— 第二台服务器备份(即将支持)" Foreground="#7E808A" FontSize="15"/>
          </RadioButton>
        </StackPanel>
      </StackPanel>

      <!-- Page 2: connection -->
      <StackPanel x:Name="Page2" Visibility="Collapsed">
        <TextBlock Style="{StaticResource Lbl}" Text="RustDesk 服务器公网 IP"/>
        <TextBox x:Name="TbIp"/>
        <TextBlock Style="{StaticResource Lbl}" Text="服务器 Key(Linux 上: cat /var/lib/rustdesk-server/id_ed25519.pub)"/>
        <TextBox x:Name="TbKey"/>
        <TextBlock Style="{StaticResource Sub}" Margin="0,16,0,0" Text="填好后点下一步。Key 可留空先连(但强烈建议填,防止连到冒充的服务器)。"/>
      </StackPanel>

      <!-- Page 3: review -->
      <StackPanel x:Name="Page3" Visibility="Collapsed">
        <TextBlock Style="{StaticResource Sub}" Text="即将执行(仅改本机 RustDesk 配置,可逆):"/>
        <Border Background="#23262F" CornerRadius="9" Padding="16" Margin="0,14,0,0">
          <TextBlock x:Name="ReviewText" Foreground="#EEEEF1" FontSize="13.5" TextWrapping="Wrap"/>
        </Border>
        <TextBlock Style="{StaticResource Sub}" Margin="0,14,0,0" Text="需要管理员权限(改 RustDesk 服务配置)。点『安装』开始。"/>
      </StackPanel>

      <!-- Page 4: progress/done -->
      <StackPanel x:Name="Page4" Visibility="Collapsed">
        <Border Background="#111318" CornerRadius="9" Padding="14" Height="300">
          <ScrollViewer x:Name="LogScroll" VerticalScrollBarVisibility="Auto">
            <TextBlock x:Name="LogText" Foreground="#B6F0C6" FontFamily="Consolas" FontSize="12.5" TextWrapping="Wrap"/>
          </ScrollViewer>
        </Border>
      </StackPanel>
    </Grid>

    <DockPanel Grid.Row="2" Margin="0,18,0,0" LastChildFill="False">
      <TextBlock x:Name="StatusBar" DockPanel.Dock="Left" Foreground="#7E808A" FontSize="12" VerticalAlignment="Center"/>
      <Button x:Name="BtnNext" DockPanel.Dock="Right" Content="下一步" Style="{StaticResource P}"/>
      <Button x:Name="BtnBack" DockPanel.Dock="Right" Content="上一步" Style="{StaticResource G}" Margin="0,0,10,0"/>
    </DockPanel>
  </Grid>
</Window>
'@

$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$ctl = @{}
'StepTitle StepHint Page1 Page2 Page3 Page4 TbIp TbKey ReviewText LogText LogScroll StatusBar BtnBack BtnNext' -split ' ' | ForEach-Object { $ctl[$_] = $win.FindName($_) }

$script:step = 1
$script:done = $false
$pages = @('欢迎','连接信息','确认','安装')
$hints = @('选择档位','填写自建服务器的地址与 Key','核对将要执行的操作','')

function Show-Step {
  foreach ($n in 1..4){ $ctl["Page$n"].Visibility = 'Collapsed' }
  $ctl["Page$script:step"].Visibility = 'Visible'
  $ctl.StepTitle.Text = $pages[$script:step-1]
  $ctl.StepHint.Text  = $hints[$script:step-1]
  $ctl.BtnBack.IsEnabled = ($script:step -gt 1 -and $script:step -lt 4)
  switch ($script:step) {
    3 { $ctl.BtnNext.Content = '安装' }
    4 { $ctl.BtnNext.Content = '完成'; $ctl.BtnBack.IsEnabled = $false }
    default { $ctl.BtnNext.Content = '下一步' }
  }
}

function Add-Log($m){ $ctl.LogText.Dispatcher.Invoke([Action]{ $ctl.LogText.Text += "$m`n"; $ctl.LogScroll.ScrollToEnd() }) }

$ctl.BtnBack.Add_Click({ if ($script:step -gt 1){ $script:step--; Show-Step } })

$ctl.BtnNext.Add_Click({
  switch ($script:step) {
    1 { $script:step = 2; Show-Step }
    2 {
      if ([string]::IsNullOrWhiteSpace($ctl.TbIp.Text)) { $ctl.StatusBar.Text = '请先填服务器 IP'; return }
      $ctl.ReviewText.Text = "档位: A(按 ID 连)`n服务器: $($ctl.TbIp.Text)`nKey: $(if($ctl.TbKey.Text){'已填'}else{'(空)'})`n`n动作: 把 RustDesk 的 custom-rendezvous-server / relay-server / key 指向该服务器(键级合并,保留你已有的其它设置),重启 RustDesk 服务。"
      $ctl.StatusBar.Text = ''; $script:step = 3; Show-Step
    }
    3 {
      $script:step = 4; Show-Step; $ctl.BtnNext.IsEnabled = $false; $ctl.StatusBar.Text = '安装中 ...'
      $ip = $ctl.TbIp.Text.Trim(); $key = $ctl.TbKey.Text.Trim()
      $logCb = [Action[string]]{ param($m) Add-Log $m }
      # run on a background thread so UI stays alive
      $ps = [PowerShell]::Create()
      $ps.Runspace.SessionStateProxy.SetVariable('ip',$ip)
      $ps.Runspace.SessionStateProxy.SetVariable('key',$key)
      $ps.Runspace.SessionStateProxy.SetVariable('logCb',$logCb)
      $ps.Runspace.SessionStateProxy.SetVariable('fn', ${function:Invoke-Install})
      $ps.Runspace.SessionStateProxy.SetVariable('sofn', ${function:Set-RustDeskOptions})
      [void]$ps.AddScript({
        Set-Item function:Set-RustDeskOptions $sofn
        Set-Item function:Invoke-Install $fn
        try { Invoke-Install $ip $key $logCb; 'OK' } catch { $logCb.Invoke("错误: $($_.Exception.Message)"); 'ERR' }
      })
      $h = $ps.BeginInvoke()
      $t = New-Object System.Windows.Threading.DispatcherTimer
      $t.Interval = [TimeSpan]::FromMilliseconds(200)
      $t.Add_Tick({
        if (-not $h.IsCompleted) { return }
        $t.Stop(); $r = $ps.EndInvoke($h); $ps.Dispose()
        $script:done = $true; $ctl.BtnNext.IsEnabled = $true
        $ctl.StatusBar.Text = if ("$r" -match 'OK') { '安装成功' } else { '安装失败(见日志)' }
      })
      $t.Start()
    }
    4 { $win.Close() }
  }
})

$win.Add_Loaded({ try { $hh=(New-Object System.Windows.Interop.WindowInteropHelper($win)).Handle; $one=1; [void][Native.Dwm]::DwmSetWindowAttribute($hh,20,[ref]$one,4) } catch {}; Show-Step })
[void]$win.ShowDialog()
