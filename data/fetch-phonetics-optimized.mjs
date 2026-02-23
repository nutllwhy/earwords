// 音标获取脚本 - 优化版
// 特点: 更快的请求间隔 + 自动恢复 + 批量处理

import fs from 'fs';

const VOCAB_FILE = './ielts-words-simple.json';
const PROGRESS_FILE = './phonetics-progress.json';
const OUTPUT_FILE = './ielts-vocabulary-with-phonetics.json';
const BATCH_SIZE = 50;  // 每批处理50个单词
const DELAY_MS = 300;   // 减少到300ms间隔
const SAVE_INTERVAL = 20; // 每20个保存一次

// 加载词库
const vocabData = JSON.parse(fs.readFileSync(VOCAB_FILE, 'utf-8'));

// 加载进度
let progress = { 
  completed: 0, 
  failed: [], 
  phoneticsMap: {}
};

let startFromIndex = 0;

if (fs.existsSync(PROGRESS_FILE)) {
  const saved = JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf-8'));
  progress = { ...progress, ...saved };
  // 计算应该从哪个位置开始
  startFromIndex = Object.keys(progress.phoneticsMap).length;
  console.log(`🔄 恢复进度: 已完成 ${progress.completed}/${vocabData.length} (从第${startFromIndex}个继续)`);
}

// 从 dictionaryapi.dev 获取音标
async function fetchPhonetic(word) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000); // 5秒超时
    
    const response = await fetch(
      `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`,
      { signal: controller.signal }
    );
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      if (response.status === 404) return { success: false, error: 'not_found' };
      throw new Error(`HTTP ${response.status}`);
    }
    
    const data = await response.json();
    
    // 提取音标
    let phonetic = '';
    let audioUrl = '';
    
    for (const entry of data) {
      for (const ph of entry.phonetics || []) {
        if (ph.text) {
          phonetic = ph.text;
          if (ph.audio?.includes('-us')) {
            audioUrl = ph.audio;
            break;
          }
        }
      }
      if (phonetic && audioUrl) break;
    }
    
    // 如果没有美式音频，找任何音频
    if (!audioUrl) {
      for (const entry of data) {
        for (const ph of entry.phonetics || []) {
          if (ph.audio) {
            audioUrl = ph.audio;
            break;
          }
        }
        if (audioUrl) break;
      }
    }
    
    return { success: true, phonetic: phonetic || '', audioUrl };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// 处理一批单词
async function processBatch(startIdx, batchSize) {
  const endIdx = Math.min(startIdx + batchSize, vocabData.length);
  const batch = vocabData.slice(startIdx, endIdx);
  
  console.log(`\n📦 处理批次: ${startIdx + 1}-${endIdx} / ${vocabData.length}`);
  
  for (let i = 0; i < batch.length; i++) {
    const wordItem = batch[i];
    const globalIdx = startIdx + i;
    const word = wordItem.word;
    
    // 跳过已处理
    if (progress.phoneticsMap[word]) continue;
    
    process.stdout.write(`[${globalIdx + 1}/${vocabData.length}] ${word} `);
    
    const result = await fetchPhonetic(word);
    
    if (result.success) {
      progress.phoneticsMap[word] = {
        phonetic: result.phonetic,
        audioUrl: result.audioUrl
      };
      progress.completed++;
      
      if (result.phonetic) {
        console.log(`✅ ${result.phonetic.substring(0, 20)}${result.audioUrl ? ' 🎵' : ''}`);
      } else {
        console.log(`⚠️ 无音标`);
      }
    } else {
      progress.failed.push({ word, error: result.error, index: globalIdx });
      console.log(`❌ ${result.error}`);
    }
    
    // 定期保存
    if ((globalIdx + 1) % SAVE_INTERVAL === 0) {
      fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
      console.log(`💾 进度保存 (${progress.completed}/${vocabData.length})`);
    }
    
    // 延迟，避免限流
    if (i < batch.length - 1) {
      await new Promise(r => setTimeout(r, DELAY_MS));
    }
  }
  
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
}

// 主函数
async function main() {
  console.log('🚀 EarWords 音标获取 - 优化版');
  console.log(`📊 总计: ${vocabData.length} 单词`);
  console.log(`⚡ 批大小: ${BATCH_SIZE}, 间隔: ${DELAY_MS}ms`);
  console.log(`⏱️  预计时间: ${Math.ceil((vocabData.length - progress.lastIndex) * DELAY_MS / 60000)} 分钟\n`);
  
  // 从上次位置开始，按批次处理
  for (let idx = startFromIndex; idx < vocabData.length; idx += BATCH_SIZE) {
    await processBatch(idx, BATCH_SIZE);
    
    // 批次间短暂休息，让系统回收资源
    if (idx + BATCH_SIZE < vocabData.length) {
      console.log('⏸️  批次完成，暂停2秒...\n');
      await new Promise(r => setTimeout(r, 2000));
    }
  }
  
  // 最终保存
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
  
  // 生成输出文件
  const vocabularyWithPhonetics = vocabData.map(item => ({
    ...item,
    phonetic: progress.phoneticsMap[item.word]?.phonetic || '',
    audioUrl: progress.phoneticsMap[item.word]?.audioUrl || ''
  }));
  
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(vocabularyWithPhonetics, null, 2));
  
  console.log('\n✅ 完成！');
  console.log(`成功: ${progress.completed}/${vocabData.length} (${Math.round(progress.completed/vocabData.length*100)}%)`);
  console.log(`失败: ${progress.failed.length}`);
  console.log(`输出: ${OUTPUT_FILE}`);
}

// 自动恢复机制 - 如果中断会定期自动重启
async function runWithRecovery() {
  let attempts = 0;
  const maxAttempts = 100; // 最多尝试100次
  
  while (progress.completed < vocabData.length && attempts < maxAttempts) {
    attempts++;
    try {
      await main();
      break; // 成功完成
    } catch (error) {
      console.error(`\n❌ 错误: ${error.message}`);
      console.log(`🔄 尝试恢复 (${attempts}/${maxAttempts})...`);
      
      // 保存进度
      fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
      
      // 等待5秒后恢复
      await new Promise(r => setTimeout(r, 5000));
    }
  }
  
  if (attempts >= maxAttempts) {
    console.log('\n⚠️ 达到最大尝试次数，请检查网络或API状态');
  }
}

// 处理中断信号
process.on('SIGINT', () => {
  console.log('\n\n⚠️ 接收到中断信号，保存进度...');
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
  console.log('进度已保存，可以安全退出');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n\n⚠️ 接收到终止信号，保存进度...');
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
  process.exit(0);
});

// 启动
runWithRecovery().catch(console.error);
