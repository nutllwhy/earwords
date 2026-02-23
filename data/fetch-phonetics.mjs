// 音标获取脚本 - 使用 dictionaryapi.dev 免费API
// 运行: node fetch-phonetics.mjs

import fs from 'fs';

// 读取简化版词库
const vocabData = JSON.parse(fs.readFileSync('./ielts-words-simple.json', 'utf-8'));

// 加载已保存的进度（如果有）
const PROGRESS_FILE = './phonetics-progress.json';
const OUTPUT_FILE = './ielts-vocabulary-with-phonetics.json';

let progress = { completed: 0, failed: [], phoneticsMap: {} };
if (fs.existsSync(PROGRESS_FILE)) {
  progress = JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf-8'));
  console.log(`🔄 恢复进度: 已完成 ${progress.completed}/${vocabData.length}`);
}

// 请求限制：每分钟 100 请求（保守设置）
const DELAY_MS = 600; // 每次请求间隔 600ms

// 从 dictionaryapi.dev 获取音标
async function fetchPhonetic(word) {
  try {
    const response = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`);
    
    if (!response.ok) {
      if (response.status === 404) {
        return { success: false, error: 'not_found' };
      }
      throw new Error(`HTTP ${response.status}`);
    }
    
    const data = await response.json();
    
    // 提取音标 - 优先美式，其次英式
    let phonetic = '';
    let audioUrl = '';
    
    for (const entry of data) {
      for (const ph of entry.phonetics || []) {
        if (ph.text) {
          phonetic = ph.text;
          if (ph.audio && ph.audio.includes('-us')) {
            audioUrl = ph.audio;
            break; // 优先美式
          }
        }
      }
      if (phonetic && audioUrl) break;
    }
    
    // 如果没有美式音频，找任何有音频的
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

// 处理单个单词
async function processWord(wordItem, index) {
  const word = wordItem.word;
  
  // 检查是否已处理
  if (progress.phoneticsMap[word]) {
    return;
  }
  
  console.log(`[${index + 1}/${vocabData.length}] ${word}`);
  
  const result = await fetchPhonetic(word);
  
  if (result.success) {
    progress.phoneticsMap[word] = {
      phonetic: result.phonetic,
      audioUrl: result.audioUrl
    };
    progress.completed++;
    
    if (result.phonetic) {
      console.log(`  ✅ ${result.phonetic} ${result.audioUrl ? '🎵' : ''}`);
    } else {
      console.log(`  ⚠️ 无音标数据`);
    }
  } else {
    progress.failed.push({ word, error: result.error });
    console.log(`  ❌ ${result.error}`);
  }
  
  // 每10个单词保存一次进度
  if ((index + 1) % 10 === 0) {
    fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
    console.log(`💾 进度已保存 (${progress.completed} 完成, ${progress.failed.length} 失败)`);
  }
}

// 主函数
async function main() {
  console.log('🚀 开始获取音标数据...');
  console.log(`📊 总计: ${vocabData.length} 个单词`);
  console.log(`⏱️  预计时间: ${Math.ceil(vocabData.length * DELAY_MS / 60000)} 分钟`);
  console.log('');
  
  // 从上次中断的地方继续
  const startIndex = Object.keys(progress.phoneticsMap).length;
  
  for (let i = startIndex; i < vocabData.length; i++) {
    await processWord(vocabData[i], i);
    
    // 延迟避免限流
    if (i < vocabData.length - 1) {
      await new Promise(resolve => setTimeout(resolve, DELAY_MS));
    }
  }
  
  // 最终保存
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
  
  // 生成带音标的词库
  const vocabularyWithPhonetics = vocabData.map(item => ({
    ...item,
    phonetic: progress.phoneticsMap[item.word]?.phonetic || '',
    audioUrl: progress.phoneticsMap[item.word]?.audioUrl || ''
  }));
  
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(vocabularyWithPhonetics, null, 2));
  
  console.log('\n✅ 完成！');
  console.log(`成功: ${progress.completed}`);
  console.log(`失败: ${progress.failed.length}`);
  console.log(`\n输出文件: ${OUTPUT_FILE}`);
  
  // 显示部分失败案例
  if (progress.failed.length > 0) {
    console.log('\n部分未找到音标的单词:');
    progress.failed.slice(0, 10).forEach(f => console.log(`  - ${f.word}: ${f.error}`));
  }
}

// 处理异常中断
process.on('SIGINT', () => {
  console.log('\n\n⚠️ 中断保存中...');
  fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));
  console.log('进度已保存，下次运行将自动恢复');
  process.exit(0);
});

main().catch(console.error);
