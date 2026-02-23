// 词库转换脚本 - 将my-ielts词库转换为EarWords App格式
// 运行: node convert-vocabulary.mjs

import fs from 'fs';
import path from 'path';

// 读取原始词库
const rawData = fs.readFileSync('./vocabulary_raw.js', 'utf-8');

// 提取JSON部分（移除export default和注释）
let jsonStr = rawData
  .replace(/\/\*\*[\s\S]*?\*\//, '')  // 移除块注释
  .replace('export default vocabulary', '')  // 移除export语句
  .trim();

// 找到第一个 '{' 到最后一个 '}' 之间的内容
const startIdx = jsonStr.indexOf('{');
const endIdx = jsonStr.lastIndexOf('}');

if (startIdx === -1 || endIdx === -1 || startIdx >= endIdx) {
  console.error('无法找到有效的JSON对象');
  process.exit(1);
}

jsonStr = jsonStr.substring(startIdx, endIdx + 1);

// 解析词库
let vocabulary;
try {
  vocabulary = JSON.parse(jsonStr);
} catch (e) {
  console.error('解析词库失败:', e.message);
  console.error('错误位置附近:', jsonStr.substring(Math.max(0, e.position - 50), e.position + 50));
  process.exit(1);
}

// 转换为扁平化的单词列表
const words = [];
let totalCount = 0;
const chapters = [];

for (const [chapterKey, chapterData] of Object.entries(vocabulary)) {
  const chapterWords = [];
  
  // 遍历该章节的所有单词组
  for (const group of chapterData.words) {
    for (const wordItem of group) {
      const word = {
        id: wordItem.id,
        word: Array.isArray(wordItem.word) ? wordItem.word[0] : wordItem.word,
        pos: wordItem.pos || '',
        meaning: wordItem.meaning || '',
        example: wordItem.example || '',
        extra: wordItem.extra || '',
        chapter: chapterData.label,
        chapterKey: chapterKey,
        // 音标字段（后续可以添加）
        phonetic: '',
        // 难度等级（基于章节顺序）
        difficulty: parseInt(chapterKey.split('_')[0]) || 1,
        // 学习状态
        status: 'new', // new, learning, mastered
        // 记忆曲线数据
        reviewCount: 0,
        nextReviewDate: null,
        easeFactor: 2.5,
        interval: 0
      };
      
      words.push(word);
      chapterWords.push(word);
      totalCount++;
    }
  }
  
  chapters.push({
    key: chapterKey,
    label: chapterData.label,
    wordCount: chapterWords.length,
    audio: chapterData.audio
  });
  
  console.log(`✅ ${chapterData.label}: ${chapterWords.length}词`);
}

// 生成转换后的词库文件
const output = {
  meta: {
    name: '雅思词汇真经',
    source: 'my-ielts (刘洪波)',
    license: 'MIT',
    version: '1.0.0',
    totalWords: totalCount,
    chapters: chapters.length,
    generatedAt: new Date().toISOString()
  },
  chapters: chapters,
  words: words
};

// 保存完整词库
fs.writeFileSync(
  './ielts-vocabulary.json',
  JSON.stringify(output, null, 2),
  'utf-8'
);

// 保存纯单词列表（用于App打包）
const simpleWords = words.map(w => ({
  id: w.id,
  word: w.word,
  pos: w.pos,
  meaning: w.meaning,
  example: w.example,
  extra: w.extra,
  phonetic: w.phonetic,
  chapter: w.chapter,
  difficulty: w.difficulty
}));

fs.writeFileSync(
  './ielts-words-simple.json',
  JSON.stringify(simpleWords, null, 2),
  'utf-8'
);

// 生成章节摘要
const summary = chapters.map(c => `${c.label}: ${c.wordCount}词`).join('\n');
fs.writeFileSync(
  './vocabulary-summary.txt',
  `雅思词汇真经 - 章节分布\n========================\n\n${summary}\n\n总计: ${totalCount}词\n`,
  'utf-8'
);

console.log('\n📊 转换完成！');
console.log(`总计: ${totalCount}个单词`);
console.log(`章节数: ${chapters.length}`);
console.log('\n生成文件:');
console.log('  - ielts-vocabulary.json (完整词库)');
console.log('  - ielts-words-simple.json (简化版)');
console.log('  - vocabulary-summary.txt (章节摘要)');

// 输出章节统计
console.log('\n📚 章节分布:');
chapters.forEach((c, i) => {
  console.log(`  ${i + 1}. ${c.label}: ${c.wordCount}词`);
});

// 输出样本数据
console.log('\n📝 样本单词:');
console.log(JSON.stringify(words[0], null, 2));
