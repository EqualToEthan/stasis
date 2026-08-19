#!/usr/bin/env node
/**
 * Post-edit 验证 Hook：编辑 .dart 文件后自动运行 flutter analyze。
 *
 * 触发条件：PostToolUse 事件，matcher 为 Write|Edit|MultiEdit
 * 行为：检测编辑的文件是否为 .dart，定位所属 Flutter 子项目，
 *       异步运行 flutter analyze 并将结果写入日志。
 * 设计要点：
 *   - async 模式运行，不阻塞 agent 工作流
 *   - 锁文件机制防止并发/重复运行（60 秒冷却期）
 *   - 日志输出到 .qoder/hooks/analyze.log
 */

import { execFileSync } from 'child_process';
import { readFileSync, writeFileSync, existsSync, unlinkSync, statSync } from 'fs';
import { join, dirname, resolve, sep } from 'path';

// --- 配置 ---
const COOLDOWN_MS = 60_000; // 60 秒冷却期，防止频繁触发
const ANALYZE_TIMEOUT_MS = 90_000; // flutter analyze 超时时间

// --- 读取 stdin JSON ---
let input;
try {
  input = JSON.parse(readFileSync(0, 'utf-8'));
} catch {
  process.exit(0);
}

const filePath =
  input?.tool_input?.file_path ||
  process.env.QODER_TOOL_INPUT_FILE_PATH;

if (!filePath) process.exit(0);

// --- 仅处理 .dart 文件 ---
const normalizedPath = filePath.replace(/\//g, sep);
if (!normalizedPath.toLowerCase().endsWith('.dart')) process.exit(0);

// --- 定位 Flutter 子项目根目录（含 pubspec.yaml 的最近祖先） ---
function findFlutterRoot(startDir) {
  let dir = startDir;
  while (true) {
    if (existsSync(join(dir, 'pubspec.yaml'))) return dir;
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

const fileDir = dirname(resolve(normalizedPath));
const projectRoot = findFlutterRoot(fileDir);
if (!projectRoot) process.exit(0);

// --- 锁文件机制：防止并发和冷却期内重复运行 ---
const lockDir = join(process.cwd(), '.qoder', 'hooks');
const lockFile = join(lockDir, '.analyze.lock');
const logFile = join(lockDir, 'analyze.log');

if (existsSync(lockFile)) {
  try {
    const lockStat = statSync(lockFile);
    const elapsed = Date.now() - lockStat.mtimeMs;
    if (elapsed < COOLDOWN_MS) {
      // 冷却期内，跳过
      process.exit(0);
    }
    // 超时清理旧锁
    unlinkSync(lockFile);
  } catch {
    // 锁文件异常，清理后继续
    try { unlinkSync(lockFile); } catch { /* ignore */ }
  }
}

// 创建锁文件
try {
  writeFileSync(lockFile, String(Date.now()));
} catch {
  process.exit(0);
}

// --- 运行 flutter analyze ---
const projectName = projectRoot.split(sep).pop();
const timestamp = new Date().toISOString();

try {
  // 使用 execFileSync 避免 shell 注入（flutter 命令是固定字符串）
  // Windows 上 flutter 是 .bat 文件，需要 shell: true 来解析
  const isWindows = process.platform === 'win32';
  const result = execFileSync(
    isWindows ? 'flutter.bat' : 'flutter',
    ['analyze'],
    {
      cwd: projectRoot,
      encoding: 'utf-8',
      timeout: ANALYZE_TIMEOUT_MS,
      stdio: ['pipe', 'pipe', 'pipe'],
      ...(isWindows ? { shell: true } : {}),
    },
  );

  const logEntry = `[${timestamp}] ${projectName}: PASS\n${result}\n`;
  writeFileSync(logFile, logEntry, { flag: 'a' });

  // 输出反馈给 agent
  const feedback = `flutter analyze (${projectName}): No issues found.`;
  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PostToolUse',
      feedback,
    },
  }));
} catch (error) {
  const stderr = error.stderr?.toString() || '';
  const stdout = error.stdout?.toString() || '';
  const output = stdout || stderr || error.message;

  const logEntry = `[${timestamp}] ${projectName}: ISSUES\n${output}\n`;
  writeFileSync(logFile, logEntry, { flag: 'a' });

  // 有问题时也输出反馈，提醒 agent 修复
  const shortOutput = output.split('\n').slice(0, 10).join('\n');
  const feedback = `flutter analyze (${projectName}) found issues:\n${shortOutput}`;
  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PostToolUse',
      feedback,
    },
  }));
} finally {
  // 清理锁文件
  try { unlinkSync(lockFile); } catch { /* ignore */ }
}

process.exit(0);
