import json,datetime,uuid,calendar,plistlib
from pathlib import Path
root=Path(__file__).resolve().parents[4]
base=root/'native/Fixtures/store/large_10k/input/financial_store_v2.json'
d=json.loads(base.read_bytes().split(b'\n',1)[1])
uid=lambda: str(uuid.uuid4())
iso=lambda y,m,day: f'{y:04}-{m:02}-{day:02}T12:00:00.000'
tx=[]
for i in range(12):
 m=11+i; y=2025+(m-1)//12; m=(m-1)%12+1
 current=(y,m)==(2026,10)
 expenses=[('Housing','Monthly rent',1250,1),('Groceries','Weekly groceries',126,2),('Eating Out','Dinner with friends',54,3),('Transportation','Monthly transit pass',85,3),('Entertainment','Movie night',28,4),('Health','Gym membership',45,4),('Groceries','Farmers market',48,5)]
 if not current: expenses += [('Groceries','Weekly groceries',145+i*3,12),('Eating Out','Weekend brunch',78,15),('General','Home essentials',92,17),('Groceries','Weekly groceries',162,22),('Eating Out','Lunch with friends',65,24),('Travel','Weekend away',260,26)]
 rows=[('income','Salary','Payday',5200+i*35,1)] + [('expense',c,desc,float(a)*(1 if current else 0.95+i*0.015),day) for c,desc,a,day in expenses]
 for typ,c,desc,a,day in rows:
  stamp=iso(y,m,day);tx.append(dict(id=uid(),type=typ,description=desc,amount=round(a,2),category=c,date=stamp,recurringTemplateId=None,tagIds=[],createdAt=stamp,updatedAt=stamp))
d['transactions']=tx
d['appSettings']=dict(baseCurrencyCode='USD',localeOverride='en_US',appLockEnabled=False,autoLockTimeoutSeconds=300,hideBalances=False)
d['categoryBudgetLimits']={'Groceries':600.0,'Eating Out':300.0,'Transportation':150.0,'Entertainment':100.0}
d['categorizationRules']=[];d['transactionTags']=[]
d['savingsGoals']=[dict(id=uid(),name=name,targetAmount=target,currentAmount=current,targetDate=date,createdAt='2026-06-01T12:00:00.000',completedAt=None) for name,target,current,date in [('Emergency fund',10000.0,7250.0,'2027-06-01T12:00:00.000'),('Japan adventure',4000.0,2400.0,'2027-04-01T12:00:00.000'),('New laptop',1800.0,1350.0,'2027-02-01T12:00:00.000')]]
d['recurringTransactions']=[dict(id=uid(),type=typ,description=name,amount=amount,category=cat,pattern='monthly',startDate='2026-06-01T12:00:00.000',nextOccurrence='2026-11-01T12:00:00.000',dayOfMonth=1,dayOfWeek=None,isActive=True) for typ,name,amount,cat in [('income','Monthly salary',5585.0,'Salary'),('expense','Rent',1250.0,'Housing'),('expense','Gym membership',45.0,'Health')]]
d['netWorthEntries']=[]
for name,typ,start,step in [('Checking','asset',3100,95),('Savings','asset',7200,450),('Investments','asset',16800,810),('Student loan','liability',9200,-230)]:
 snapshots=[]
 for i in range(10):
  day=5 if i==9 else calendar.monthrange(2026,i+1)[1]
  snapshots.append(dict(recordedAt=iso(2026,i+1,day),amount=float(start+i*step)))
 d['netWorthEntries'].append(dict(id=uid(),name=name,type=typ,createdAt='2026-01-01T12:00:00.000',snapshots=snapshots))
d['selectedNetWorthMonth']='2026-10-01T00:00:00.000'
payload=json.dumps(d,separators=(',',':'),ensure_ascii=False).encode();h=0xcbf29ce484222325
for b in payload:h=((h^b)*0x100000001b3)&0xffffffffffffffff
signed=h-(1<<64) if h>=1<<63 else h
cs=('-'+format(-signed,'x') if signed<0 else format(signed,'x')).rjust(16,'0')
header=dict(format='budgie-financial-store',schemaVersion=2,revision=201,payloadLength=len(payload),payloadChecksum=cs,writtenAt='2026-10-05T12:00:00.000')
data=json.dumps(header,separators=(',',':')).encode()+b'\n'+payload
out=root/'native/Marketing/AppStore-4.0/source/demo-store';out.mkdir(parents=True,exist_ok=True)
for name in ['financial_store_v2.json','financial_store_v2.backup.json']:(out/name).write_bytes(data)
Path('/tmp/budgie-demo-preferences.plist').write_bytes(plistlib.dumps({'flutter.themeMode':'dark','flutter.onboarding_completed':True}))
print(len(tx),'fictional transactions; demo files created')
