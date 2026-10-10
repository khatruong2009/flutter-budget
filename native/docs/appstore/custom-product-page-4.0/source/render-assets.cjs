// Render real app captures in the existing Paper / Midnight campaign layout.
const fs = require('fs');
const path = require('path');
const { chromium } = require('/Users/khatruong/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root = path.resolve(__dirname, '..');
const resource = path.resolve(__dirname, '../../../../Budgie/Resources');
const data = (p, mime = 'image/png') => `data:${mime};base64,${fs.readFileSync(p).toString('base64')}`;
const regular = data(path.join(resource, 'Fonts/Gabarito-Regular.ttf'), 'font/ttf');
const bold = data(path.join(resource, 'Fonts/Gabarito-ExtraBold.ttf'), 'font/ttf');
const mono = data(path.join(resource, 'Fonts/SplineSansMono-Medium.ttf'), 'font/ttf');
const shots = [
  ['01-home', 'ALL-NEW BUDGIE 4.0', 'Your money,<br>made clearer.', 'Rebuilt from scratch as a<br>fast, native iPhone app.', true],
  ['02-voice', 'VOICE ENTRY', 'Just say what<br>you spent.', 'Tap the mic and Budgie<br>fills in the expense for you.', false],
  ['03-safe-to-spend', 'SAFE TO SPEND', 'Know what you<br>can spend today.', 'One daily number that sets<br>aside bills, budgets and goals.', true],
  ['04-net-worth', 'NET WORTH', 'Watch your<br>net worth grow.', 'Track every account and debt, month by month.', false],
  ['05-spending', 'BUDGETS', 'See where it<br>all goes.', 'Category budgets that tell<br>you the moment you go over.', true],
  ['06-goals', 'SAVINGS GOALS', 'Save for what<br>matters.', 'Know exactly what to set aside<br>each month to stay on track.', false],
  ['07-insights', 'CASH FLOW & INSIGHTS', 'Stay ahead<br>of your month.', 'Trends and nudges, calculated<br>privately on your iPhone.', true],
  ['08-private', 'PRIVATE BY DESIGN', 'No account.<br>No bank login.', 'Your budget lives on your<br>iPhone, not on our servers.', false],
];
const css = `@font-face{font-family:G;src:url('${regular}')}@font-face{font-family:G;src:url('${bold}');font-weight:800}@font-face{font-family:M;src:url('${mono}')}*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden}body{font-family:G;background:#07090D;color:#EEF1F5}.light{background:#F3EFE6;color:#1A1A17}.copy{position:absolute;left:108px;right:90px;top:190px}.label{font-family:M;font-size:38px;letter-spacing:6px;color:#5EE6B0}.light .label{color:#1D6646}h1{font-size:120px;line-height:1.04;letter-spacing:-5px;font-weight:800;margin:50px 0 45px}p{font-size:50px;line-height:1.35;color:#AEB5C0;margin:0}.light p{color:#5C584F}.halo{position:absolute;left:-150px;top:1400px;width:1620px;height:1620px;background:radial-gradient(circle,#5EE6B029,transparent 65%)}.phone{position:absolute;left:196px;top:856px;width:936px;padding:24px;border-radius:160px;background:linear-gradient(140deg,#58606b,#15181f 35%,#3a414c 70%,#0c0e12);box-shadow:0 36px 100px #0007,inset 0 0 0 3px #737a8555}.light .phone{background:#1A1A17;box-shadow:0 36px 90px #0004}.display{position:relative;overflow:hidden;border-radius:136px}.display>img{display:block;width:100%}.island{position:absolute;top:1.55%;left:36%;width:28%;height:3.3%;background:#000;border-radius:80px}`;
(async () => {
  const browser = await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--disable-gpu']});
  for (const [name,label,title,subtitle,light] of shots) {
    const markup = `<!doctype html><html><meta charset="utf-8"><style>${css}</style><body class="${light?'light':''}"><div class="halo"></div><div class="copy"><div class="label">${label}</div><h1>${title}</h1><p>${subtitle}</p></div><div class="phone"><div class="display"><img src="${data(path.join(root,'raw',name+'.png'))}"><div class="island"></div></div></div></body></html>`;
    fs.writeFileSync(path.join(__dirname,name+'.html'),markup);
    const page = await browser.newPage({viewport:{width:1320,height:2868},deviceScaleFactor:1});
    await page.setContent(markup); await page.evaluate(() => document.fonts.ready);
    await page.screenshot({path:path.join(root,name+'.png'),omitBackground:false}); await page.close();
    console.log(name);
  }
  const page = await browser.newPage({viewport:{width:1320,height:1434},deviceScaleFactor:1});
  await page.setContent(`<html><style>body{margin:0;background:#07090D;display:grid;grid-template-columns:repeat(4,1fr)}img{width:330px;height:717px}</style>${shots.map(([n])=>`<img src="${data(path.join(root,n+'.png'))}">`).join('')}</html>`);
  await page.screenshot({path:path.join(root,'overview.jpg'),type:'jpeg',quality:95}); await browser.close();
})().catch(e => {console.error(e);process.exit(1)});
