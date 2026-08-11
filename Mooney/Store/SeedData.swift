import Foundation

private func al(_ id: String, _ amt: Double) -> Allocation { Allocation(bucketId: id, amount: amt) }

let seedBills: [Bill] = [
    Bill(id: "car_payment", name: "Car Payment", amount: 250, isActive: true, order: 0),
    Bill(id: "phone_bill", name: "Phone Bill", amount: 25, isActive: true, order: 1),
]

let seedIncomeSources: [IncomeSource] = [
    IncomeSource(id: "doordash", name: "DoorDash"),
    IncomeSource(id: "cfa", name: "CFA"),
    IncomeSource(id: "plasma", name: "Plasma"),
]

let seedBuckets: [Bucket] = [
    Bucket(id:"savings",     name:"Savings",     colorHex:"#AF52DE", isActive:true,  archived:false, goal:nil,   isSpending:false, order:0, isGeneral:true),
    Bucket(id:"checking",    name:"Checking",    colorHex:"#007AFF", isActive:true,  archived:false, goal:nil,   isSpending:true,  order:1),
    Bucket(id:"tithing",     name:"Tithing",     colorHex:"#34C759", isActive:true,  archived:false, goal:nil,   isSpending:true,  order:2),
    Bucket(id:"bts",         name:"BTS",         colorHex:"#FF2D55", isActive:true,  archived:false, goal:nil,   isSpending:false, order:3),
    Bucket(id:"vacation",    name:"Vacation",    colorHex:"#FF9500", isActive:true,  archived:false, goal:nil,   isSpending:false, order:4),
    Bucket(id:"christmas",   name:"Christmas",   colorHex:"#FFCC00", isActive:true,  archived:false, goal:nil,   isSpending:false, order:5),
    Bucket(id:"car",         name:"Car",         colorHex:"#5856D6", isActive:true,  archived:false, goal:2000,  isSpending:false, order:6),
    Bucket(id:"lego",        name:"Lego",        colorHex:"#A2845E", isActive:true,  archived:false, goal:nil,   isSpending:false, order:7),
    Bucket(id:"schwab",      name:"Charles Schwab", colorHex:"#00C7BE", isActive:true,  archived:false, goal:nil, isSpending:false, order:8),
    Bucket(id:"cd",          name:"Certificate of Deposit", colorHex:"#30B0C7", isActive:true, archived:false, goal:nil, isSpending:false, order:9),
    Bucket(id:"nickolas",    name:"Nickolas",    colorHex:"#8E8E93", isActive:false, archived:false, goal:nil,   isSpending:false, order:10),
    Bucket(id:"splurges",    name:"Splurges",    colorHex:"#32ADE6", isActive:false, archived:false, goal:nil,   isSpending:false, order:11),
    Bucket(id:"debt_makeup", name:"Debt Makeup", colorHex:"#8E8E93", isActive:false, archived:false, goal:nil,   isSpending:false, order:12),
    Bucket(id:"disney",      name:"Disney",      colorHex:"#32ADE6", isActive:false, archived:true,  goal:nil,   isSpending:false, order:20),
]

let seedRecurringTransfers: [RecurringTransfer] = [
    RecurringTransfer(id: "xfer_checking", name: "Checking", bucketId: "checking", amount: 100, frequency: .weekly, startDate: todayISO(), lastRunDate: nil, isActive: true),
    RecurringTransfer(id: "xfer_schwab",   name: "Charles Schwab", bucketId: "schwab", amount: 20, frequency: .weekly, startDate: todayISO(), lastRunDate: nil, isActive: true),
    RecurringTransfer(id: "xfer_cd",       name: "Certificate of Deposit", bucketId: "cd", amount: 25, frequency: .weekly, startDate: todayISO(), lastRunDate: nil, isActive: true),
]

let seedIncomes: [Income] = [
    Income(id:"p_20250626", date:"2025-06-26", amount:477.10,  note:"",                  allocations:[al("savings",100),  al("checking",327.11), al("bts",50)]),
    Income(id:"p_20250710", date:"2025-07-10", amount:265.17,  note:"",                  allocations:[al("savings",30),   al("checking",135.17), al("disney",50),    al("bts",50)]),
    Income(id:"p_20250723", date:"2025-07-23", amount:472.25,  note:"",                  allocations:[al("savings",40),   al("checking",332.25), al("disney",50),    al("bts",50)]),
    Income(id:"p_20250807", date:"2025-08-07", amount:504.17,  note:"",                  allocations:[al("savings",50),   al("checking",394.17), al("disney",30),    al("bts",30)]),
    Income(id:"p_20250821", date:"2025-08-21", amount:384.62,  note:"",                  allocations:[al("savings",50),   al("checking",274.62), al("disney",30),    al("bts",30)]),
    Income(id:"p_20250904", date:"2025-09-04", amount:480.26,  note:"",                  allocations:[al("savings",80),   al("checking",300.26), al("disney",50),    al("bts",50)]),
    Income(id:"p_20250918", date:"2025-09-18", amount:626.40,  note:"",                  allocations:[al("savings",80),   al("checking",384.40), al("disney",50),    al("bts",50)]),
    Income(id:"p_20251002", date:"2025-10-02", amount:644.65,  note:"",                  allocations:[al("savings",80),   al("tithing",64),  al("checking",400.65), al("disney",50), al("bts",50)]),
    Income(id:"p_20251016", date:"2025-10-16", amount:677.56,  note:"",                  allocations:[al("savings",80),   al("checking",430.56), al("disney",50),    al("bts",50)]),
    Income(id:"p_20251030", date:"2025-10-30", amount:577.14,  note:"",                  allocations:[al("savings",100),  al("tithing",57),  al("checking",270.14), al("disney",50), al("bts",50), al("christmas",50)]),
    Income(id:"p_20251113", date:"2025-11-13", amount:797.91,  note:"",                  allocations:[al("savings",200),  al("tithing",79),  al("checking",348.91), al("disney",50), al("bts",50), al("christmas",70)]),
    Income(id:"p_20251128", date:"2025-11-28", amount:803.16,  note:"Disney fund closed",allocations:[al("savings",100),  al("tithing",80),  al("checking",473.16), al("bts",50), al("vacation",50), al("christmas",50)]),
    Income(id:"p_20251211", date:"2025-12-11", amount:502.30,  note:"Christmas used",    allocations:[al("savings",100),  al("tithing",50),  al("checking",222.30), al("bts",20), al("vacation",20), al("christmas",50)]),
    Income(id:"p_20251225", date:"2025-12-25", amount:710.78,  note:"",                  allocations:[al("savings",100),  al("tithing",70),  al("checking",390.78), al("bts",50), al("vacation",50), al("christmas",50)]),
    Income(id:"p_20260108", date:"2026-01-08", amount:712.33,  note:"",                  allocations:[al("savings",100),  al("tithing",70),  al("checking",192.33), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Income(id:"p_20260123", date:"2026-01-23", amount:703.67,  note:"",                  allocations:[al("savings",100),  al("checking",203.67), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Income(id:"p_20260205", date:"2026-02-05", amount:877.49,  note:"",                  allocations:[al("savings",100),  al("checking",327.49), al("bts",100),al("vacation",50), al("christmas",50), al("car",250)]),
    Income(id:"p_20260221", date:"2026-02-21", amount:649.25,  note:"",                  allocations:[al("savings",100),  al("checking",149.25), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Income(id:"p_20260305", date:"2026-03-05", amount:863.49,  note:"",                  allocations:[al("savings",100),  al("checking",363.49), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Income(id:"p_20260319", date:"2026-03-19", amount:778.01,  note:"",                  allocations:[al("savings",100),  al("checking",278.01), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Income(id:"p_20260402", date:"2026-04-02", amount:618.50,  note:"",                  allocations:[al("savings",100),  al("checking",118.50), al("bts",50), al("vacation",50), al("christmas",50), al("car",250)]),
    Income(id:"p_20260416", date:"2026-04-16", amount:842.14,  note:"Car goal reached",  allocations:[al("savings",100),  al("checking",322.14), al("bts",50), al("vacation",50), al("christmas",50), al("car",250), al("lego",20)]),
    Income(id:"p_20260430", date:"2026-04-30", amount:843.37,  note:"",                  allocations:[al("savings",150),  al("checking",493.37), al("bts",50), al("vacation",50), al("christmas",50), al("lego",50)]),
]

let seedTransactions: [AppTransaction] = [
    AppTransaction(id:"t_open_sav",   bucketId:"savings",   amount: 2012.15, date:"2025-06-25", note:"Opening balance",           type:"opening"),
    AppTransaction(id:"t_dis1",       bucketId:"disney",    amount:  -27.00, date:"2025-08-07", note:"Ghirardelli's",             type:"spend"),
    AppTransaction(id:"t_dis2",       bucketId:"disney",    amount:  -27.00, date:"2025-09-04", note:"Sunglasses",                type:"spend"),
    AppTransaction(id:"t_dis3",       bucketId:"disney",    amount:  -23.00, date:"2025-09-18", note:"Beignets",                  type:"spend"),
    AppTransaction(id:"t_dis4",       bucketId:"disney",    amount:  -55.00, date:"2025-10-02", note:"Sweats",                    type:"spend"),
    AppTransaction(id:"t_dis5",       bucketId:"disney",    amount:  -32.00, date:"2025-10-16", note:"Necklaces",                 type:"spend"),
    AppTransaction(id:"t_dis6",       bucketId:"disney",    amount:  -40.00, date:"2025-10-30", note:"Hat",                      type:"spend"),
    AppTransaction(id:"t_dis7",       bucketId:"disney",    amount:  -65.00, date:"2025-11-13", note:"Sweatshirt",               type:"spend"),
    AppTransaction(id:"t_dis_xfer",   bucketId:"disney",    amount: -191.00, date:"2025-11-19", note:"Transferred to Christmas", type:"transfer"),
    AppTransaction(id:"t_xmas_dis",   bucketId:"christmas", amount:  191.00, date:"2025-11-19", note:"From Disney fund",         type:"transfer"),
    AppTransaction(id:"t_coins",      bucketId:"checking",  amount:   85.02, date:"2025-11-19", note:"Coins cashed in",          type:"adjustment"),
    AppTransaction(id:"t_xmas_used",  bucketId:"christmas", amount: -411.00, date:"2025-12-11", note:"Christmas 2025 — used",    type:"spend"),
    AppTransaction(id:"t_slcc",       bucketId:"savings",   amount:-1990.50, date:"2026-01-15", note:"SLCC Spring Semester tuition", type:"spend"),
    AppTransaction(id:"t_bts_tix",    bucketId:"bts",       amount: -410.00, date:"2026-04-05", note:"Concert tickets",          type:"spend"),
    AppTransaction(id:"t_bts_skort",  bucketId:"bts",       amount:  -50.00, date:"2026-04-10", note:"Skort",                    type:"spend"),
    AppTransaction(id:"t_bts_outfit", bucketId:"bts",       amount:  -45.00, date:"2026-04-12", note:"Concert outfit",           type:"spend"),
    AppTransaction(id:"t_vac1",       bucketId:"vacation",  amount:  -65.00, date:"2026-03-30", note:"Nick St. George trip",     type:"spend"),
    AppTransaction(id:"t_vac2",       bucketId:"vacation",  amount:   -8.00, date:"2026-03-30", note:"Swig",                     type:"spend"),
    AppTransaction(id:"t_vac3",       bucketId:"vacation",  amount:  -21.00, date:"2026-03-30", note:"Sally's Piercings",        type:"spend"),
    AppTransaction(id:"t_vac4",       bucketId:"vacation",  amount:  -20.00, date:"2026-03-30", note:"McDonald's",               type:"spend"),
    AppTransaction(id:"t_vac5",       bucketId:"vacation",  amount:  -20.00, date:"2026-03-30", note:"Las Vegas souvenirs",      type:"spend"),
    AppTransaction(id:"t_vac6",       bucketId:"vacation",  amount:  -70.00, date:"2026-04-05", note:"Lego Toothless",           type:"spend"),
]
