import { execFile } from 'node:child_process'
import { chmod, lstat, mkdir } from 'node:fs/promises'
import { dirname, resolve, win32 } from 'node:path'

export type LanSocialProtectedPathKind = 'directory' | 'file'

export type LanSocialPathProtection = {
  kind: LanSocialProtectedPathKind
  currentUserOnly: boolean
  posixMode: number | null
  windowsAclRuleCount: number | null
  windowsInheritanceProtected: boolean | null
  windowsRuleIsInherited: boolean | null
}

const protectedWindowsDirectories = new Set<string>()

// Windows PowerShellの.NET ACL APIだけを使う。親processのPSModulePathがpwsh 7用でも
// 動くようGet/Set-Acl等のcmdletへ依存せず、targetもenvironmentで安全に渡す。
const WINDOWS_ACL_SCRIPT = String.raw`
$ErrorActionPreference = 'Stop'
$target = [Environment]::GetEnvironmentVariable('DEKISUGI_LAN_ACL_TARGET', 'Process')
$kind = [Environment]::GetEnvironmentVariable('DEKISUGI_LAN_ACL_KIND', 'Process')
$action = [Environment]::GetEnvironmentVariable('DEKISUGI_LAN_ACL_ACTION', 'Process')

if ([String]::IsNullOrWhiteSpace($target)) { throw 'ACL target is missing' }
if ($kind -ne 'directory' -and $kind -ne 'file') { throw 'ACL kind is invalid' }
if ($action -ne 'protect' -and $action -ne 'inspect') { throw 'ACL action is invalid' }

if ($kind -eq 'directory') {
  $item = [IO.DirectoryInfo]::new($target)
} else {
  $item = [IO.FileInfo]::new($target)
}
if (-not $item.Exists) { throw 'ACL target is missing or has the wrong kind' }
if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
  throw 'ACL target must not be a reparse point'
}

$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
if ($null -eq $currentSid) { throw 'Current Windows SID is unavailable' }

if ($action -eq 'protect') {
  if ($kind -eq 'directory') {
    $security = [Security.AccessControl.DirectorySecurity]::new()
    $inheritance = (
      [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
      [Security.AccessControl.InheritanceFlags]::ObjectInherit
    )
  } else {
    $security = [Security.AccessControl.FileSecurity]::new()
    $inheritance = [Security.AccessControl.InheritanceFlags]::None
  }
  $security.SetOwner($currentSid)
  $security.SetAccessRuleProtection($true, $false)
  $rule = [Security.AccessControl.FileSystemAccessRule]::new(
    $currentSid,
    [Security.AccessControl.FileSystemRights]::FullControl,
    $inheritance,
    [Security.AccessControl.PropagationFlags]::None,
    [Security.AccessControl.AccessControlType]::Allow
  )
  [void]$security.AddAccessRule($rule)
  $item.SetAccessControl($security)
}

$actual = $item.GetAccessControl()
$ownerSid = $actual.GetOwner([Security.Principal.SecurityIdentifier])
$rules = @($actual.GetAccessRules(
  $true,
  $true,
  [Security.Principal.SecurityIdentifier]
))
$directoryInheritance = (
  [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
  [Security.AccessControl.InheritanceFlags]::ObjectInherit
)
$expectedInheritance = if ($kind -eq 'directory') {
  $directoryInheritance
} else {
  [Security.AccessControl.InheritanceFlags]::None
}
$currentUserOnly = $ownerSid.Value -eq $currentSid.Value -and $rules.Count -eq 1
if ($currentUserOnly) {
  $onlyRule = $rules[0]
  $inheritanceMatches = $onlyRule.InheritanceFlags -eq $expectedInheritance
  if ($kind -eq 'file') {
    # Windowsは親directoryからfileへ継承したACEにもCI/OIを保持する場合がある。
    # SID・権限・propagationを厳格に保ち、既知の2表現だけを許可する。
    $inheritanceMatches = (
      $inheritanceMatches -or
      $onlyRule.InheritanceFlags -eq $directoryInheritance
    )
  }
  $currentUserOnly = (
    $onlyRule.IdentityReference.Value -eq $currentSid.Value -and
    $onlyRule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
    $onlyRule.FileSystemRights -eq [Security.AccessControl.FileSystemRights]::FullControl -and
    $inheritanceMatches -and
    $onlyRule.PropagationFlags -eq [Security.AccessControl.PropagationFlags]::None
  )
}

$ruleIsInheritedJson = 'null'
if ($rules.Count -eq 1) {
  $ruleIsInheritedJson = $rules[0].IsInherited.ToString().ToLowerInvariant()
}
$output = (
  '{"kind":"' + $kind + '",' +
  '"currentUserOnly":' + $currentUserOnly.ToString().ToLowerInvariant() + ',' +
  '"inheritanceProtected":' +
    $actual.AreAccessRulesProtected.ToString().ToLowerInvariant() + ',' +
  '"ruleCount":' + $rules.Count.ToString() + ',' +
  '"ruleIsInherited":' + $ruleIsInheritedJson +
  '}'
)
[Console]::Out.Write($output)
`

const WINDOWS_ACL_ENCODED = Buffer
  .from(WINDOWS_ACL_SCRIPT, 'utf16le')
  .toString('base64')

/**
 * LAN coordinatorの保存directoryを現在のOS userだけが読める状態にする。
 * Windowsでは継承を切り、current SIDのFullControl ACE 1件だけを残す。
 */
export async function protectLanSocialDirectory(path: string): Promise<void> {
  await mkdir(path, { recursive: true, mode: 0o700 })
  await assertPathKind(path, 'directory')
  if (process.platform === 'win32') {
    const protection = await windowsProtection(path, 'directory', 'protect')
    assertWindowsExplicitProtection(protection)
    protectedWindowsDirectories.add(windowsPathKey(path))
    return
  }
  await chmod(path, 0o700)
  assertPrivateProtection(await inspectLanSocialPathProtection(path, 'directory'))
}

/** 既存のcert/key/stateをcurrent user専用へ矯正してから読む。 */
export async function protectLanSocialFile(path: string): Promise<void> {
  await assertPathKind(path, 'file')
  if (process.platform === 'win32') {
    const protection = await windowsProtection(path, 'file', 'protect')
    assertWindowsExplicitProtection(protection)
    return
  }
  await chmod(path, 0o600)
  assertPrivateProtection(await inspectLanSocialPathProtection(path, 'file'))
}

/**
 * 保護済みdirectory内で0600相当として新規作成した一時fileをrenameした後の処理。
 * Windowsは親のcurrent-user-only ACEだけを継承するため、requestごとにPowerShellを
 * 起動しない。呼出順を誤った場合はfail-closedにする。
 */
export async function finalizeLanSocialAtomicFile(path: string): Promise<void> {
  await assertPathKind(path, 'file')
  if (process.platform === 'win32') {
    if (!protectedWindowsDirectories.has(windowsPathKey(dirname(path)))) {
      throw new Error('Windows ACLで保護する前にLAN保存fileを作成しました')
    }
    return
  }
  await chmod(path, 0o600)
  assertPrivateProtection(await inspectLanSocialPathProtection(path, 'file'))
}

/** testだけでなくstartup診断にも使える、mutationを伴わないpermission確認。 */
export async function inspectLanSocialPathProtection(
  path: string,
  kind: LanSocialProtectedPathKind,
): Promise<LanSocialPathProtection> {
  const info = await assertPathKind(path, kind)
  if (process.platform === 'win32') {
    return windowsProtection(path, kind, 'inspect')
  }
  const expectedMode = kind === 'directory' ? 0o700 : 0o600
  const currentUid = typeof process.geteuid === 'function' ? process.geteuid() : undefined
  const mode = info.mode & 0o777
  return {
    kind,
    currentUserOnly: mode === expectedMode &&
      (currentUid === undefined || info.uid === currentUid),
    posixMode: mode,
    windowsAclRuleCount: null,
    windowsInheritanceProtected: null,
    windowsRuleIsInherited: null,
  }
}

async function assertPathKind(
  path: string,
  kind: LanSocialProtectedPathKind,
) {
  const info = await lstat(path)
  const correctKind = kind === 'directory' ? info.isDirectory() : info.isFile()
  if (!correctKind || info.isSymbolicLink()) {
    throw new Error(`LAN保存先が通常の${kind}ではありません`)
  }
  return info
}

function assertPrivateProtection(protection: LanSocialPathProtection): void {
  if (!protection.currentUserOnly) {
    throw new Error(`LAN保存${protection.kind}をcurrent user専用にできませんでした`)
  }
}

function assertWindowsExplicitProtection(protection: LanSocialPathProtection): void {
  if (!protection.currentUserOnly ||
      protection.windowsInheritanceProtected !== true ||
      protection.windowsAclRuleCount !== 1 ||
      protection.windowsRuleIsInherited !== false) {
    throw new Error(`LAN保存${protection.kind}のWindows ACLを限定できませんでした`)
  }
}

function windowsPathKey(path: string): string {
  return resolve(path).toLowerCase()
}

function windowsSystemRoot(): string {
  const entry = Object.entries(process.env).find(
    ([key]) => key.toLowerCase() === 'systemroot',
  )
  const root = entry?.[1]
  if (!root || !/^[A-Za-z]:[\\/]/u.test(root)) {
    throw new Error('Windows SystemRootの絶対pathを解決できません')
  }
  return win32.normalize(root)
}

async function windowsProtection(
  path: string,
  kind: LanSocialProtectedPathKind,
  action: 'inspect' | 'protect',
): Promise<LanSocialPathProtection> {
  // PATHへ依存させない。SEA smokeがPATH=''でもWindows標準PowerShellを直接起動する。
  const executable = win32.join(
    windowsSystemRoot(),
    'System32',
    'WindowsPowerShell',
    'v1.0',
    'powershell.exe',
  )
  const stdout = await executePowerShell(executable, path, kind, action)
  let value: unknown
  try {
    value = JSON.parse(stdout.replace(/^\uFEFF/u, '').trim())
  } catch {
    throw new Error('Windows ACL検証結果を解釈できません')
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Windows ACL検証結果が不正です')
  }
  const record = value as Record<string, unknown>
  if (record.kind !== kind || typeof record.currentUserOnly !== 'boolean' ||
      typeof record.inheritanceProtected !== 'boolean' ||
      typeof record.ruleCount !== 'number' || !Number.isInteger(record.ruleCount) ||
      !(typeof record.ruleIsInherited === 'boolean' || record.ruleIsInherited === null)) {
    throw new Error('Windows ACL検証結果のfieldが不正です')
  }
  return {
    kind,
    currentUserOnly: record.currentUserOnly,
    posixMode: null,
    windowsAclRuleCount: record.ruleCount,
    windowsInheritanceProtected: record.inheritanceProtected,
    windowsRuleIsInherited: record.ruleIsInherited,
  }
}

async function executePowerShell(
  executable: string,
  path: string,
  kind: LanSocialProtectedPathKind,
  action: 'inspect' | 'protect',
): Promise<string> {
  return new Promise((resolveOutput, rejectOutput) => {
    execFile(
      executable,
      [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy', 'Bypass',
        '-EncodedCommand', WINDOWS_ACL_ENCODED,
      ],
      {
        encoding: 'utf8',
        env: {
          ...process.env,
          // ACL scriptはmodule非依存。この値を空にしてpwsh 7用pathの継承も遮断する。
          PSModulePath: '',
          DEKISUGI_LAN_ACL_TARGET: path,
          DEKISUGI_LAN_ACL_KIND: kind,
          DEKISUGI_LAN_ACL_ACTION: action,
        },
        maxBuffer: 64 * 1024,
        timeout: 30_000,
        windowsHide: true,
      },
      (error, stdout, stderr) => {
        if (error) {
          const detail = stderr.trim() || error.message
          rejectOutput(new Error(
            `Windows ACL ${action}が失敗しました: ${detail.slice(0, 1_000)}`,
          ))
          return
        }
        resolveOutput(stdout)
      },
    )
  })
}
