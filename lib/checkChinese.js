const child = require('child_process')

const target = process.argv[2] || '.'
console.log(`grep -r ${target}`)
const all = child.execSync(`grep -r '' ${target}`).toString().split('\n').map(l => l.trim()).filter(l => l.length)
const chinese = all.filter(l => /[\u4E00-\u9FFF\u3400-\u4dbf\uf900-\ufaff\u3040-\u309f\uac00-\ud7af]+/.test(l))
console.log(`<<<<<<<< check lines includes chinese in ${target} >>>>>>>>`)
console.log(chinese)
