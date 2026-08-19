#!/usr/bin/env node
/**
 * Stop Hook：检查源码变更是否伴随文档更新。
 *
 * 触发条件：Stop 事件（agent 准备停下时）
 * 行为：通过 git 检测本次是否有 .dart 源码变更但缺少对应的文档更新，
 *       若缺失则阻止 agent 停下，提醒更新文档。
 * 设计要点：
 *   - stop_hook_active 为 true 时直接放行，避免无限循环
 *   - 仅检查未提交的变更（git diff + git diff --cached）
 *   - 文档文件包括：README.md、PROTOCOL.md、注释变更无法自动检测
 */

import { execFileSync } from 'child_process';
import { readFileSync, appendFileSync } from 'fs';
import { sep, join, dirname } from 'path';

// --- 读取 stdin JSON ---
let input;
try {
  input = JSON.parse(readFileSync(0, 'utf-8'));
} catch {
  process.exit(0);
}

const logFile = join(process.cwd(), '.qoder', 'hooks', 'stop-hook.log');
const log = (msg) => {
  try {
    appendFileSync(logFile, `[${new Date().toISOString()}] ${msg}\n`);
  } catch { /* ignore */ }
};

log('--- hook invoked ---');
log(`stdin: ${JSON.stringify(input).slice(0, 200)}`);

// --- 防止无限循环：如果已经被 Stop Hook 阻止过一次，直接放行 ---
if (input?.stop_hook_active) {
  log('pass - stop_hook_active (loop prevention)');
  process.exit(0);
}

const cwd = input?.cwd || process.cwd();

// --- 获取未提交的变更文件列表（staged + unstaged） ---
function getModifiedFiles() {
  try {
    const staged = execFileSync('git', ['diff', '--cached', '--name-only', '--diff-filter=ACMR'], {
      cwd, encoding: 'utf-8', timeout: 10_000, stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();

    const unstaged = execFileSync('git', ['diff', '--name-only', '--diff-filter=ACMR'], {
      cwd, encoding: 'utf-8', timeout: 10_000, stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();

    const all = new Set();
    for (const f of staged.split('\n')) { if (f) all.add(f); }
    for (const f of unstaged.split('\n')) { if (f) all.add(f); }
    return [...all];
  } catch {
    // git 不可用或无仓库，直接放行
    return [];
  }
}

const modifiedFiles = getModifiedFiles();
log(`modifiedFiles: ${modifiedFiles.length} files`);
if (modifiedFiles.length > 0) log(`  - ${modifiedFiles.slice(0, 10).join(', ')}${modifiedFiles.length > 10 ? '...' : ''}`);
if (modifiedFiles.length === 0) {
  log('pass - no modifications');
  process.exit(0);
}

// --- 分类文件 ---
const isSourceFile = (f) => {
  const normalized = f.replace(/\//g, sep);
  // lib/ 下的 .dart 文件视为源码
  return normalized.endsWith('.dart') && normalized.includes(`${sep}lib${sep}`);
};

const isDocFile = (f) => {
  const name = f.replace(/\\/g, '/').split('/').pop();
  return name === 'README.md' || name === 'PROTOCOL.md';
};

const changedSourceFiles = modifiedFiles.filter(isSourceFile);
const changedDocFiles = modifiedFiles.filter(isDocFile);

// 没有源码变更，放行
if (changedSourceFiles.length === 0) {
  log('pass - no source file changes');
  process.exit(0);
}

log(`source files: ${changedSourceFiles.length} (${changedSourceFiles.slice(0, 5).join(', ')})`);
log(`doc files: ${changedDocFiles.length} (${changedDocFiles.join(', ')})`);

// 有源码变更，也有文档变更，放行
if (changedDocFiles.length > 0) {
  log('pass - has both source and doc changes');
  process.exit(0);
}

// --- 有源码变更但无文档更新，阻止停下 ---
const sourceList = changedSourceFiles.slice(0, 8).join('\n  - ');
const more = changedSourceFiles.length > 8 ? `\n  - ... 共 ${changedSourceFiles.length} 个文件` : '';

const reason = `检测到以下源码文件已修改，但未更新对应的文档：\n  - ${sourceList}${more}\n\n请先读取 .qoder/docs/documentation-format.md 了解文档格式规范，然后更新：\n  1. 被修改文件的 /// 文档注释（文件头、类、方法）\n  2. 所属模块的 README.md（文件清单、调用关系、修改指引）\n  3. 若修改了 ColdExport/ColdImport 模型，同步更新 PROTOCOL.md`;

log(`BLOCK - source changed but no doc update: ${sourceList}`);

console.log(JSON.stringify({
  decision: 'block',
  reason,
}));

process.exit(2);
