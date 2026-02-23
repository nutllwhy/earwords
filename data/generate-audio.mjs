// 例句音频生成脚本 - 使用 Azure TTS 或系统 TTS
// 运行: node generate-audio.mjs

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

// 配置
const CONFIG = {
  // 使用系统 TTS (macOS say 命令) 或 Azure TTS
  useSystemTTS: true,
  
  // Azure TTS 配置 (如果使用)
  azure: {
    key: process.env.AZURE_TTS_KEY || '',
    region: process.env.AZURE_TTS_REGION || 'eastasia',
    voice: 'en-US-JennyNeural' // 或 en-US-GuyNeural
  },
  
  // 输出目录
  audioDir: './audio-examples',
  
  // 同时处理的并发数
  concurrency: 5,
  
  // 请求间隔 (ms)
  delayMs: 500
};

// 确保音频目录存在
if (!fs.existsSync(CONFIG.audioDir)) {
  fs.mkdirSync(CONFIG.audioDir, { recursive: true });
}

// 加载词库
const vocabFile = fs.existsSync('./ielts-vocabulary-with-phonetics.json') 
  ? './ielts-vocabulary-with-phonetics.json'
  : './ielts-words-simple.json';
  
const vocabData = JSON.parse(fs.readFileSync(vocabFile, 'utf-8'));

// 加载进度
const PROGRESS_FILE = './audio-progress.json';
let progress = { completed: 0, failed: [], generated: [] };
if (fs.existsSync(PROGRESS_FILE)) {
  progress = JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf-8'));
  console.log(`🔄 恢复进度: 已完成 ${progress.completed}/${vocabData.length}`);
}

// 使用 macOS 系统 TTS (say 命令)
async function generateWithSystemTTS(text, wordId) {
  const outputPath = path.join(CONFIG.audioDir, `${wordId}.mp3`);
  
  try {
    // 使用 say 命令生成音频，然后转换为 mp3
    const aiffPath = outputPath.replace('.mp3', '.aiff');
    
    // 清理文本中的特殊字符
    const cleanText = text.replace(/["\\]/g, '');
    
    execSync(`say -v "Samantha" -o "${aiffPath}" "${cleanText}"`, {
      timeout: 10000
    });
    
    // 转换为 mp3 (需要 lame，如果没有则保留 aiff)
    try {
      execSync(`lame -m m "${aiffPath}" "${outputPath}" --silent`, { timeout: 10000 });
      fs.unlinkSync(aiffPath);
    } catch (e) {
      // lame 不可用，保留 aiff 格式
      return { success: true, path: aiffPath, format: 'aiff' };
    }
    
    return { success: true, path: outputPath, format: 'mp3' };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// 使用 Azure TTS
async function generateWithAzureTTS(text, wordId) {
  // 这里可以实现 Azure TTS API 调用
  // 暂时返回未实现
  return { success: false, error: 'Azure TTS not implemented yet' };
}

// 生成单个音频
async function generateAudio(wordItem, index) {
  const wordId = wordItem.id;
  const word = wordItem.word;
  const example = wordItem.example;
  
  // 跳过已生成的
  if (progress.generated.includes(wordId)) {
    return { skipped: true };
  }
  
  // 跳过无例句的
  if (!example || example === '-') {
    progress.generated.push(wordId);
    progress.completed++;
    return { skipped: true, reason: 'no_example' };
  }
  
  console.log(`[${index + 1}/${vocabData.length}] ${word}`);
  console.log(`  📝 ${example.substring(0, 60)}...`);
  
  // 构建朗读文本: 单词 + 例句
  const textToRead = `${word}. ${example}`;
  
  let result;
  if (CONFIG.useSystemTTS) {
    result = await generateWithSystemTTS(textToRead, wordId);
  } else {
    result = await generateWithAzureTTS(textToRead, wordId);
  }
  
  if (result.success) {
    progress.generated.push(wordId);
    progress.completed++;
    console.log(`  ✅ ${result.format} ${result.path}`);
  } else {
    progress.failed.push({ wordId, word, error: result.error });
    console.log(`  ❌ ${result.error}`);
  }
  
  // 每10个保存一次
  if ((index + 1) % 10 === 0) {
    fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
    console.log(`💾 进度已保存`);
  }
  
  return result;
}

// 批处理函数
async function processBatch(startIdx, batchSize) {
  const batch = vocabData.slice(startIdx, startIdx + batchSize);
  const promises = batch.map((item, idx) => 
    generateAudio(item, startIdx + idx).then(result => {
      if (idx < batch.length - 1) {
        return new Promise(resolve => setTimeout(() => resolve(result), CONFIG.delayMs));
      }
      return result;
    })
  );
  return Promise.all(promises);
}

// 主函数
async function main() {
  console.log('🚀 开始生成例句音频...');
  console.log(`📊 总计: ${vocabData.length} 个单词`);
  console.log(`🔧 使用: ${CONFIG.useSystemTTS ? '系统 TTS (macOS say)' : 'Azure TTS'}`);
  console.log(`📁 输出目录: ${CONFIG.audioDir}`);
  console.log('');
  
  // 从上次中断处继续
  const startIndex = progress.completed;
  
  // 按批次处理
  for (let i = startIndex; i < vocabData.length; i += CONFIG.concurrency) {
    await processBatch(i, CONFIG.concurrency);
  }
  
  // 最终保存
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
  
  console.log('\n✅ 完成！');
  console.log(`成功: ${progress.completed}`);
  console.log(`失败: ${progress.failed.length}`);
  console.log(`\n音频文件位于: ${CONFIG.audioDir}/`);
  
  // 生成音频索引文件
  const audioIndex = vocabData
    .filter(item => progress.generated.includes(item.id))
    .map(item => ({
      id: item.id,
      word: item.word,
      audioFile: `${item.id}.mp3`
    }));
  
  fs.writeFileSync('./audio-index.json', JSON.stringify(audioIndex, null, 2));
  console.log(`📑 音频索引已生成: audio-index.json`);
}

// 处理中断
process.on('SIGINT', () => {
  console.log('\n\n⚠️ 中断保存中...');
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
  console.log('进度已保存');
  process.exit(0);
});

main().catch(console.error);
